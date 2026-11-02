import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/widgets/account_statement/statement_item_model.dart';

/// Resultado del intento de compartir estado de cuenta por canales externos
enum StatementShareResult { launched, copiedToClipboard, failed }

/// Servicio para construir resúmenes de texto y compartir estados de cuenta
class AccountStatementShareService {
  const AccountStatementShareService._();

  /// Construye el texto enriquecido para compartir por mensajería
  static String buildStatementShareText({
    required String titularName,
    required bool isSupplier,
    required String currencySymbol,
    required double currentBalance,
    required double totalCharged,
    required double totalPaid,
    required List<StatementItem> items,
  }) {
    final buffer = StringBuffer();
    final role = isSupplier ? 'PROVEEDOR' : 'CLIENTE';
    buffer.writeln('📋 *ESTADO DE CUENTA ($role)*');
    buffer.writeln('👤 *Titular:* $titularName');
    buffer.writeln(
      '📅 *Fecha:* ${DateFormat('dd/MM/yyyy HH:mm', 'es').format(DateTime.now())}',
    );
    buffer.writeln('--------------------------------');
    buffer.writeln(
      '💰 *Saldo Actual:* $currencySymbol ${currentBalance.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '📈 Total Cargos: $currencySymbol ${totalCharged.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '📉 Total Abonos: $currencySymbol ${totalPaid.toStringAsFixed(2)}',
    );
    buffer.writeln('--------------------------------');
    buffer.writeln('📝 *ÚLTIMOS MOVIMIENTOS:*');

    final displayItems = items.take(15);
    for (final it in displayItems) {
      final date =
          it.date != null ? DateFormat('dd/MM/yy', 'es').format(it.date!) : '-';
      final type = it.isCharge ? 'CARGO' : 'ABONO';
      buffer.writeln(
        '• $date [$type]: $currencySymbol ${it.amount.toStringAsFixed(2)} (${it.method ?? "N/A"})',
      );
    }
    if (items.length > 15) {
      buffer.writeln('... y ${items.length - 15} movimientos más.');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('Comprobante emitido para control de créditos.');
    return buffer.toString();
  }

  /// Comparte por WhatsApp abriendo la aplicación externa o recayendo en portapapeles
  static Future<StatementShareResult> shareViaWhatsApp({
    required String text,
    String? phone,
  }) async {
    String cleanPhone = phone ?? '';
    cleanPhone = cleanPhone.replaceAll(RegExp(r'\D'), '');

    final encodedText = Uri.encodeComponent(text);
    final urlStr =
        cleanPhone.isNotEmpty
            ? 'https://wa.me/$cleanPhone?text=$encodedText'
            : 'https://wa.me/?text=$encodedText';

    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return StatementShareResult.launched;
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        return StatementShareResult.copiedToClipboard;
      }
    } catch (e, st) {
      LoggerService.w(
        'No se pudo abrir WhatsApp, copiando al portapapeles',
        tag: 'STATEMENT_SHARE_SERVICE',
        error: e,
        stackTrace: st,
      );
      await Clipboard.setData(ClipboardData(text: text));
      return StatementShareResult.copiedToClipboard;
    }
  }

  /// Comparte por Correo Electrónico (mailto:) o recae en portapapeles
  static Future<StatementShareResult> shareViaEmail({
    required String text,
    required String titularName,
    required String businessName,
  }) async {
    final subject = Uri.encodeComponent(
      'Estado de Cuenta: $titularName - $businessName',
    );
    final body = Uri.encodeComponent(text);
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return StatementShareResult.launched;
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        return StatementShareResult.copiedToClipboard;
      }
    } catch (e, st) {
      LoggerService.w(
        'No se pudo abrir cliente de correo, copiando al portapapeles',
        tag: 'STATEMENT_SHARE_SERVICE',
        error: e,
        stackTrace: st,
      );
      await Clipboard.setData(ClipboardData(text: text));
      return StatementShareResult.copiedToClipboard;
    }
  }

  /// Copia el resumen de texto al portapapeles
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
