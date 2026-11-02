import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/utils/isolate_utils.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';

/// Helper desacoplado para selección, compresión binaria en Isolate y validación
/// de archivos multimedia del formulario de productos.
class ProductFormImageHelper {
  const ProductFormImageHelper._();

  static const int maxImages = 8;
  static const int maxSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
  ];

  /// Abre el selector de imágenes de galería con respaldo automático en FilePicker.
  static Future<List<XFile>> pickImages() async {
    List<XFile> archivos = [];
    try {
      final picker = ImagePicker();
      archivos = await picker.pickMultiImage();
    } catch (e, st) {
      LoggerService.w(
        'ImagePicker no disponible, intentando FilePicker de respaldo',
        tag: 'PRODUCT_FORM_IMAGE_HELPER',
        error: e,
        stackTrace: st,
      );
    }

    if (archivos.isEmpty) {
      try {
        final files = await FilePicker.pickFiles(type: FileType.image);
        if (files.isNotEmpty) {
          for (final f in files) {
            final bytes = await f.readAsBytes();
            if (bytes.isNotEmpty) {
              archivos.add(XFile(f.path ?? '', bytes: bytes, name: f.name));
            }
          }
        }
      } catch (e, st) {
        LoggerService.e(
          'Error en selección mediante FilePicker',
          tag: 'PRODUCT_FORM_IMAGE_HELPER',
          error: e,
          stackTrace: st,
        );
      }
    }

    return archivos;
  }

  /// Procesa, valida y comprime una lista de archivos para agregar a las imágenes del formulario.
  static Future<({List<FormImageItem> updatedImages, String? feedbackMessage})>
  processAndAddImageFiles(
    List<XFile> archivos,
    List<FormImageItem> currentImages,
  ) async {
    if (archivos.isEmpty) {
      return (updatedImages: currentImages, feedbackMessage: null);
    }

    final currentCount = currentImages.length;
    if (currentCount >= maxImages) {
      return (
        updatedImages: currentImages,
        feedbackMessage:
            'Límite de imágenes alcanzado ($maxImages fotos máximo).',
      );
    }

    var duplicadas = 0;
    var excedidas = 0;
    var formatoInvalido = 0;
    var pesoExcedido = 0;
    final nuevosItems = <FormImageItem>[];

    for (final archivo in archivos) {
      final nombre = normalizeFileName(archivo);
      final extension =
          nombre.contains('.') ? nombre.split('.').last.toLowerCase() : '';

      // Validación 1: Formatos válidos de imagen
      if (!allowedExtensions.contains(extension)) {
        formatoInvalido++;
        continue;
      }

      // Validación 2: Capacidad máxima
      if (currentCount + nuevosItems.length >= maxImages) {
        excedidas++;
        continue;
      }

      // Validación 3: Duplicados
      if (currentImages.any(
            (img) => !img.isExisting && img.newName == nombre,
          ) ||
          nuevosItems.any((img) => img.newName == nombre)) {
        duplicadas++;
        continue;
      }

      try {
        final bytesOriginales = await archivo.readAsBytes();

        // Validación 4: Peso máximo de 5MB y archivos vacíos
        if (bytesOriginales.isEmpty) continue;
        if (bytesOriginales.lengthInBytes > maxSizeBytes) {
          pesoExcedido++;
          continue;
        }

        final bytesOptimizados = await optimizeImageBytes(bytesOriginales);
        nuevosItems.add(
          FormImageItem(newBytes: bytesOptimizados, newName: nombre),
        );
      } catch (e, st) {
        LoggerService.e(
          'Error leyendo bytes de archivo: $nombre',
          tag: 'PRODUCT_FORM_IMAGE_HELPER',
          error: e,
          stackTrace: st,
        );
      }
    }

    final List<String> messages = [];
    if (formatoInvalido > 0) {
      messages.add(
        '$formatoInvalido archivo(s) no son imágenes válidas (solo JPG, PNG, WEBP, HEIC).',
      );
    }
    if (pesoExcedido > 0) {
      messages.add(
        '$pesoExcedido imagen(es) superan el peso máximo permitido (5 MB).',
      );
    }
    if (duplicadas > 0) {
      messages.add('$duplicadas imagen(es) repetidas omitidas.');
    }
    if (excedidas > 0) {
      messages.add('$excedidas exceden el cupo de $maxImages fotos.');
    }

    final updated = [...currentImages, ...nuevosItems];
    return (
      updatedImages: updated,
      feedbackMessage: messages.isNotEmpty ? messages.join(' ') : null,
    );
  }

  /// Optimiza la imagen en un Isolate secundario para evitar bloqueos del hilo UI.
  static Future<Uint8List> optimizeImageBytes(Uint8List originalBytes) async {
    if (originalBytes.lengthInBytes < 250 * 1024) return originalBytes;
    if (kIsWeb) {
      return originalBytes;
    }
    try {
      return await IsolateUtils.run(() async {
        final bytesComprimidos = await FlutterImageCompress.compressWithList(
          originalBytes,
          minWidth: 1024,
          minHeight: 1024,
          quality: 75,
          format: CompressFormat.jpeg,
        );
        if (bytesComprimidos.isNotEmpty &&
            bytesComprimidos.lengthInBytes < originalBytes.lengthInBytes) {
          return bytesComprimidos;
        }
        return originalBytes;
      });
    } catch (e, st) {
      LoggerService.e(
        'Error comprimiendo imagen en isolate',
        tag: 'PRODUCT_FORM_IMAGE_HELPER',
        error: e,
        stackTrace: st,
      );
    }
    return originalBytes;
  }

  /// Normaliza el nombre de archivo a minúsculas y extrae el basename.
  static String normalizeFileName(XFile archivo) {
    final rawName = archivo.name.trim();
    if (rawName.isNotEmpty) return rawName.toLowerCase();
    final segments = archivo.path.split(RegExp(r'[/\\]'));
    return segments.isEmpty
        ? archivo.path.toLowerCase()
        : segments.last.toLowerCase();
  }
}
