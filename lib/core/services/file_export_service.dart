import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';

/// Resultado de una exportación de archivo.
enum FileExportOutcome {
  /// El archivo quedó guardado en disco.
  saved,

  /// El usuario cerró el diálogo nativo de guardado sin confirmar.
  cancelled,

  /// No se pudo guardar el archivo.
  failed,
}

/// Resultado tipado de [FileExportService.save].
class FileExportResult {
  final FileExportOutcome outcome;

  /// Ruta del archivo (desktop/móvil) o `null` si se canceló o falló.
  final String? location;

  /// Detalle del error cuando [outcome] es [FileExportOutcome.failed].
  final String? error;

  const FileExportResult._(this.outcome, this.location, this.error);

  const FileExportResult.saved(String? location)
    : this._(FileExportOutcome.saved, location, null);

  const FileExportResult.cancelled()
    : this._(FileExportOutcome.cancelled, null, null);

  const FileExportResult.failed(String error)
    : this._(FileExportOutcome.failed, null, error);

  bool get isSaved => outcome == FileExportOutcome.saved;
  bool get isCancelled => outcome == FileExportOutcome.cancelled;
  bool get isFailed => outcome == FileExportOutcome.failed;
}

/// Servicio unificado de guardado de archivos exportados.
///
/// ## Por qué existe
///
/// `FileSaver.instance.saveFile()` se comporta de forma opaca según la
/// plataforma, y en móvil el resultado es **invisible para el usuario**:
///
/// - **Web**: dispara la descarga del navegador (el usuario la ve).
/// - **Android**: escribe en `Android/data/<paquete>/files/`, una carpeta
///   PRIVADA de la app. No hay notificación, no aparece en Descargas y el
///   usuario no percibe absolutamente nada.
/// - **iOS**: escribe en la carpeta `Documents` de la app, que solo aparece en
///   la app Archivos si el usuario la busca a mano.
///
/// Este servicio centraliza la estrategia de guardado:
///
/// - **Web / Desktop**: `saveFile` (descarga del navegador / carpeta
///   Descargas del sistema). Sin cambios de comportamiento.
/// - **Android / iOS**: `saveAs`, que abre el diálogo nativo "Guardar como"
///   (`ACTION_CREATE_DOCUMENT` / `UIDocumentPicker`). El usuario ve el
///   diálogo, elige el destino y obtiene una confirmación visible.
///   **No requiere ningún permiso en runtime**, por eso nunca se muestra un
///   aviso de permisos: el acceso lo concede el propio selector del sistema.
/// - **Fallback**: si el diálogo nativo no está disponible (no hay explorador
///   de archivos, la Activity se cerró, etc.) en Android se recurre a
///   `saveToDownloads`, que escribe en la carpeta pública Descargas.
class FileExportService {
  const FileExportService._();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get _isMobile => _isAndroid || _isIOS;

  /// Guarda [bytes] con el nombre [fileName] y la extensión [extension].
  ///
  /// [fileName] se puede pasar con o sin extensión; se normaliza para evitar
  /// nombres duplicados tipo `reporte.csv.csv`.
  static Future<FileExportResult> save({
    required String fileName,
    required Uint8List bytes,
    required String extension,
    required MimeType mimeType,
    String? customMimeType,
    String? dialogTitle,
  }) async {
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    final name = _stripExtension(fileName, ext);

    try {
      if (!_isMobile) {
        // Web: descarga del navegador. Desktop: carpeta Descargas del SO.
        final path = await FileSaver.instance.saveFile(
          name: name,
          bytes: bytes,
          fileExtension: ext,
          mimeType: mimeType,
          customMimeType: customMimeType,
        );
        return FileExportResult.saved(path);
      }

      // Móvil: diálogo nativo "Guardar como" (SAF en Android, document
      // picker en iOS). Devuelve `null` si el usuario lo cancela.
      final path = await FileSaver.instance.saveAs(
        name: name,
        bytes: bytes,
        fileExtension: ext,
        mimeType: mimeType,
        customMimeType: customMimeType,
        dialogTitle: dialogTitle,
      );

      if (path == null) {
        return const FileExportResult.cancelled();
      }
      return FileExportResult.saved(path);
    } catch (e, st) {
      LoggerService.e(
        'No se pudo guardar el archivo "$name.$ext"',
        error: e,
        stackTrace: st,
        tag: 'FILE_EXPORT',
      );

      // Fallback en Android: carpeta pública Descargas (vía MediaStore, sin
      // permisos en Android 10+). En iOS no existe carpeta Descargas
      // compartida, por lo que se informa el error al usuario.
      if (_isAndroid) {
        try {
          final path = await FileSaver.instance.saveToDownloads(
            name: name,
            bytes: bytes,
            fileExtension: ext,
            mimeType: mimeType,
            customMimeType: customMimeType,
          );
          if (path != null) {
            return FileExportResult.saved(path);
          }
        } catch (fallbackError, fallbackSt) {
          LoggerService.e(
            'Fallback a Descargas falló para "$name.$ext"',
            error: fallbackError,
            stackTrace: fallbackSt,
            tag: 'FILE_EXPORT',
          );
        }
      }

      return FileExportResult.failed(e.toString());
    }
  }

  /// Quita la extensión del nombre si ya viene incluida.
  static String _stripExtension(String fileName, String extension) {
    final suffix = '.$extension';
    if (fileName.toLowerCase().endsWith(suffix.toLowerCase())) {
      return fileName.substring(0, fileName.length - suffix.length);
    }
    return fileName;
  }
}
