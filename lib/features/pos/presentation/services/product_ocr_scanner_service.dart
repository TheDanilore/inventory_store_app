import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/pos/presentation/services/variant_disambiguation_helper.dart';

/// Modelo con el resultado del análisis OCR y su producto / variante resuelta
class ProductOcrMatchResult {
  final ProductEntity product;
  final ProductVariantEntity? variant;
  final List<ProductVariantEntity> candidateVariants;
  final String rawText;
  final String? detectedPresentation;
  final bool isDirectMatch;

  const ProductOcrMatchResult({
    required this.product,
    this.variant,
    this.candidateVariants = const [],
    required this.rawText,
    this.detectedPresentation,
    required this.isDirectMatch,
  });
}

/// Servicio que integra Google ML Kit Text Recognition (On-Device OCR)
/// con el catálogo de productos y el motor de desambiguación de variantes.
class ProductOcrScannerService {
  static TextRecognizer? _recognizer;

  static TextRecognizer get _getTextRecognizer {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _recognizer!;
  }

  /// Libera recursos del recognizer de ML Kit
  static void dispose() {
    try {
      _recognizer?.close();
      _recognizer = null;
    } catch (_) {}
  }

  /// Procesa una imagen física (tomada con cámara o picker) mediante OCR y busca el producto
  static Future<ProductOcrMatchResult?> recognizeFromImageFile(
    String filePath, {
    String? warehouseId,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        LoggerService.w(
          'El archivo de imagen no existe: $filePath',
          tag: 'ProductOcrScannerService',
        );
        return null;
      }

      final inputImage = InputImage.fromFilePath(filePath);
      final recognizedText = await _getTextRecognizer.processImage(inputImage);

      final fullText = recognizedText.text.trim();
      if (fullText.isEmpty) {
        LoggerService.d(
          'No se detectó texto en la imagen',
          tag: 'ProductOcrScannerService',
        );
        return null;
      }

      LoggerService.i(
        'Texto OCR detectado:\n$fullText',
        tag: 'ProductOcrScannerService',
      );
      return await matchProductFromText(fullText, warehouseId: warehouseId);
    } catch (e, st) {
      LoggerService.e(
        'Error ejecutando OCR en imagen: $filePath',
        tag: 'ProductOcrScannerService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Analiza texto extraído (raw OCR text) y encuentra el producto + variante más afín
  static Future<ProductOcrMatchResult?> matchProductFromText(
    String rawText, {
    String? warehouseId,
  }) async {
    final cleanTokens = VariantDisambiguationHelper.extractMeaningfulKeywords(
      rawText,
    );
    if (cleanTokens.isEmpty) return null;

    final repo = sl<ProductsRepository>();

    // 1. Estrategia de Búsqueda 1: Frases compuestas de 2 a 3 tokens principales
    // (Ej: "BAYFOLAN FORTE", "UREA 46", "GLIFOSATO 480")
    final candidatePhrases = <String>[];
    for (int i = 0; i < cleanTokens.length; i++) {
      if (i + 1 < cleanTokens.length) {
        candidatePhrases.add('${cleanTokens[i]} ${cleanTokens[i + 1]}');
      }
      if (i + 2 < cleanTokens.length) {
        candidatePhrases.add(
          '${cleanTokens[i]} ${cleanTokens[i + 1]} ${cleanTokens[i + 2]}',
        );
      }
    }
    // Agregar también palabras individuales de mayor longitud (> 3 caracteres)
    for (final token in cleanTokens) {
      if (token.length >= 4 && !candidatePhrases.contains(token)) {
        candidatePhrases.add(token);
      }
    }

    ProductEntity? matchedProduct;

    // Buscar en el repositorio con las frases candidatas más prometedoras
    for (final phrase in candidatePhrases.take(6)) {
      try {
        final res = await repo.getProducts(
          searchQuery: phrase,
          isActive: true,
          limit: 5,
        );

        final products = res.fold((l) => <ProductEntity>[], (r) => r.products);
        if (products.isNotEmpty) {
          // Evaluar cuál producto del resultado tiene mayor similitud de nombre
          matchedProduct = _pickBestProduct(products, rawText, cleanTokens);
          if (matchedProduct != null) break;
        }
      } catch (_) {}
    }

    // 2. Estrategia de Búsqueda 2 (Respaldo): Búsqueda por ingrediente activo si no se encontró por título
    if (matchedProduct == null && cleanTokens.isNotEmpty) {
      for (final token in cleanTokens.where((t) => t.length >= 4).take(3)) {
        try {
          final res = await repo.getProducts(
            searchQuery: token,
            searchByIngredient: true,
            isActive: true,
            limit: 3,
          );
          final products = res.fold(
            (l) => <ProductEntity>[],
            (r) => r.products,
          );
          if (products.isNotEmpty) {
            matchedProduct = products.first;
            break;
          }
        } catch (_) {}
      }
    }

    if (matchedProduct == null) {
      LoggerService.d(
        'No se encontró coincidencia en catálogo para el texto OCR',
        tag: 'ProductOcrScannerService',
      );
      return null;
    }

    // 3. Desambiguación de Variante (Litro vs Sobre vs Galón vs Kilo)
    final resolution = VariantDisambiguationHelper.disambiguate(
      product: matchedProduct,
      ocrRawText: rawText,
    );

    return ProductOcrMatchResult(
      product: matchedProduct,
      variant: resolution.resolvedVariant,
      candidateVariants:
          resolution.candidateVariants.isNotEmpty
              ? resolution.candidateVariants
              : matchedProduct.productVariants
                  .where((v) => v.isActive)
                  .toList(),
      rawText: rawText,
      detectedPresentation: resolution.detectedPresentation,
      isDirectMatch: resolution.isDirectMatch,
    );
  }

  /// Selecciona el producto que mejor encaja con el texto OCR entre los resultados
  static ProductEntity? _pickBestProduct(
    List<ProductEntity> products,
    String rawOcrText,
    List<String> keywords,
  ) {
    if (products.isEmpty) return null;
    if (products.length == 1) return products.first;

    final normOcr = VariantDisambiguationHelper.normalize(rawOcrText);

    ProductEntity? bestProd;
    double maxScore = -1.0;

    for (final prod in products) {
      double score = 0.0;
      final prodNameNorm = VariantDisambiguationHelper.normalize(prod.name);

      // Si el texto OCR contiene el nombre completo del producto
      if (normOcr.contains(prodNameNorm)) {
        score += 100.0;
      }

      // Conteo de palabras en común
      final nameWords = prodNameNorm.split(RegExp(r'\s+'));
      for (final word in nameWords) {
        if (word.length >= 3 && keywords.contains(word)) {
          score += 25.0;
        }
      }

      // Si la marca coincide
      if (prod.brandName != null && prod.brandName!.isNotEmpty) {
        final brandNorm = VariantDisambiguationHelper.normalize(
          prod.brandName!,
        );
        if (normOcr.contains(brandNorm)) {
          score += 30.0;
        }
      }

      if (score > maxScore) {
        maxScore = score;
        bestProd = prod;
      }
    }

    return bestProd ?? products.first;
  }
}
