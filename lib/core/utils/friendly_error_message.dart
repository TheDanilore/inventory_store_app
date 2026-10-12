import 'package:supabase_flutter/supabase_flutter.dart';

/// Utilidad centralizada para transformar excepciones técnicas y errores
/// de base de datos (PostgreSQL, Supabase, Red) en mensajes comprensibles,
/// amables y en español para el usuario final.
class FriendlyErrorMessage {
  FriendlyErrorMessage._();

  /// Convierte cualquier [error] o cadena técnica en un mensaje legible.
  static String format(dynamic error, {String? defaultMessage}) {
    if (error == null) {
      return defaultMessage ?? 'Ha ocurrido un error inesperado.';
    }

    // 1. Si es PostgrestException directa
    if (error is PostgrestException) {
      return _formatPostgrest(
        code: error.code,
        message: error.message,
        details: error.details?.toString(),
        hint: error.hint,
      );
    }

    final raw = error.toString().trim();

    // 2. Si el string contiene la representación de PostgrestException
    if (raw.contains('PostgrestException')) {
      return _parsePostgrestString(raw);
    }

    // 3. Chequeos de constraints por texto
    if (raw.contains('unique_financial_account_name') ||
        (raw.contains('duplicate key') && raw.contains('financial_account'))) {
      return 'Ya existe una cuenta con este nombre. Por favor, elige otro nombre.';
    }

    if (raw.contains('users_email_key') ||
        (raw.contains('duplicate key') && raw.contains('email'))) {
      return 'El correo electrónico ya se encuentra registrado por otro usuario.';
    }

    if (raw.contains('users_phone_key') ||
        (raw.contains('duplicate key') && raw.contains('phone'))) {
      return 'El número de teléfono ya se encuentra registrado.';
    }

    if (raw.contains('products_sku_key') ||
        (raw.contains('duplicate key') && raw.contains('sku'))) {
      return 'Ya existe un producto registrado con este código SKU / de barras.';
    }

    if (raw.contains('suppliers_document_key') ||
        (raw.contains('duplicate key') && raw.contains('document'))) {
      return 'Ya existe un proveedor con este número de documento.';
    }

    if (raw.contains('duplicate key') || raw.contains('23505')) {
      return 'Ya existe un registro con estos datos duplicados.';
    }

    if (raw.contains('violates foreign key constraint') ||
        raw.contains('23503')) {
      return 'No se puede realizar la acción porque este registro está vinculado a otros datos.';
    }

    if (raw.contains('violates not-null constraint') || raw.contains('23502')) {
      return 'Faltan campos obligatorios requeridos por el sistema.';
    }

    // 4. Errores de red y conexión
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('ClientException') ||
        raw.contains('Network is unreachable') ||
        raw.contains('Connection refused') ||
        raw.contains('wsarecv')) {
      return 'Error de conexión. Verifica tu conexión a internet e intenta nuevamente.';
    }

    if (raw.contains('TimeoutException') || raw.contains('timed out')) {
      return 'El servidor tardó demasiado en responder. Por favor, intenta de nuevo.';
    }

    // 5. Errores de autenticación / JWT
    if (raw.contains('JWT expired') || raw.contains('token is expired')) {
      return 'Tu sesión ha expirado. Por favor, vuelve a iniciar sesión.';
    }

    if (raw.contains('Invalid login credentials')) {
      return 'Credenciales incorrectas. Verifica tu usuario y contraseña.';
    }

    // 6. Limpieza de prefijos comunes
    var cleaned =
        raw
            .replaceAll(RegExp(r'^Exception:\s*', caseSensitive: false), '')
            .replaceAll(
              RegExp(r'^ServerException:\s*', caseSensitive: false),
              '',
            )
            .replaceAll(RegExp(r'^Failure:\s*', caseSensitive: false), '')
            .trim();

    if (cleaned.isEmpty) {
      return defaultMessage ?? 'Ha ocurrido un error inesperado.';
    }

    return cleaned;
  }

  static String _formatPostgrest({
    String? code,
    required String message,
    String? details,
    String? hint,
  }) {
    final lower = '$message ${details ?? ''} ${hint ?? ''}'.toLowerCase();

    // Código 23505: Unique constraint violation
    if (code == '23505' || lower.contains('duplicate key')) {
      if (lower.contains('unique_financial_account_name') ||
          lower.contains('financial_account')) {
        return 'Ya existe una cuenta con este nombre. Por favor, elige otro nombre.';
      }
      if (lower.contains('users_email_key') || lower.contains('email')) {
        return 'El correo electrónico ya se encuentra registrado por otro usuario.';
      }
      if (lower.contains('users_phone_key') || lower.contains('phone')) {
        return 'El número de teléfono ya se encuentra registrado.';
      }
      if (lower.contains('products_sku_key') || lower.contains('sku')) {
        return 'Ya existe un producto registrado con este código SKU / de barras.';
      }
      if (lower.contains('suppliers_document_key') ||
          lower.contains('document')) {
        return 'Ya existe un proveedor con este número de documento.';
      }
      return 'Ya existe un registro con estos datos. Verifica que la información no esté duplicada.';
    }

    // Código 23503: Foreign key violation
    if (code == '23503' || lower.contains('foreign key')) {
      return 'No se puede completar la operación porque el registro está vinculado a otros datos.';
    }

    // Código 23502: Not-null violation
    if (code == '23502' || lower.contains('not-null')) {
      return 'Faltan campos obligatorios para guardar la información.';
    }

    // Códigos de reglas de negocio en base de datos (RPCs POS, créditos)
    if (code == 'P0010' || lower.contains('línea de crédito registrada')) {
      return 'El cliente no tiene línea de crédito registrada.';
    }
    if (code == 'P0011' ||
        lower.contains('línea de crédito del cliente no está activa')) {
      return 'La línea de crédito del cliente no está activa.';
    }
    if (code == 'P0012' || lower.contains('crédito insuficiente')) {
      return 'Crédito insuficiente para completar esta operación.';
    }

    // Si el mensaje es razonablemente limpio (sin código SQL interno)
    if (!message.contains('violates') &&
        !message.contains('constraint') &&
        message.length < 120) {
      return message;
    }

    return 'No se pudo completar la operación en la base de datos.';
  }

  static String _parsePostgrestString(String raw) {
    final lower = raw.toLowerCase();

    if (lower.contains('unique_financial_account_name') ||
        (lower.contains('duplicate key') && lower.contains('account'))) {
      return 'Ya existe una cuenta con este nombre. Por favor, elige otro nombre.';
    }

    if (lower.contains('23505') || lower.contains('duplicate key')) {
      if (lower.contains('email')) {
        return 'El correo electrónico ya se encuentra registrado.';
      }
      if (lower.contains('phone')) {
        return 'El número de teléfono ya se encuentra registrado.';
      }
      if (lower.contains('sku')) {
        return 'Ya existe un producto con este código SKU / de barras.';
      }
      return 'Ya existe un registro con estos datos duplicados.';
    }

    if (lower.contains('23503') || lower.contains('foreign key')) {
      return 'No se puede completar la operación porque el registro está asociado a otros datos.';
    }

    // Extraer el contenido de message: si es legible
    final match = RegExp(r'message:\s*([^,\)]+)').firstMatch(raw);
    if (match != null) {
      final msg = match.group(1)?.trim();
      if (msg != null && !msg.contains('violates') && msg.isNotEmpty) {
        return msg;
      }
    }

    return 'Error en la base de datos al procesar la solicitud.';
  }
}
