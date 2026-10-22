import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';

/// Resultado del análisis y desambiguación de variantes de un producto frente a texto OCR
class VariantResolutionResult {
  /// La variante resuelta con alta certeza (si hubo match unívoco)
  final ProductVariantEntity? resolvedVariant;

  /// Lista de variantes candidatas ordenadas por relevancia/score
  final List<ProductVariantEntity> candidateVariants;

  /// La presentación o unidad detectada en el texto (ej. "1 Litro", "Sobre 100g", "Galón")
  final String? detectedPresentation;

  /// Nivel de confianza entre 0.0 y 1.0
  final double confidence;

  /// Indica si se determinó una única variante con certeza suficiente para auto-selección
  bool get isDirectMatch => resolvedVariant != null && confidence >= 0.70;

  const VariantResolutionResult({
    this.resolvedVariant,
    this.candidateVariants = const [],
    this.detectedPresentation,
    this.confidence = 0.0,
  });
}

/// Helper para normalizar texto, extraer indicios de unidades y encontrar
/// la variante exacta entre opciones como "Litro", "Sobre", "Galón", "Kilo", etc.
class VariantDisambiguationHelper {
  /// Lista de palabras vacías o ruido frecuente en etiquetas agrícolas y retail
  static final Set<String> _stopwords = {
    'contenido',
    'neto',
    'cont',
    'registro',
    'senasa',
    'nro',
    'lote',
    'venc',
    'vencimiento',
    'exp',
    'fecha',
    'fabricacion',
    'precaucion',
    'peligro',
    'cuidado',
    'toxico',
    'ligeramente',
    'moderadamente',
    'altamente',
    'ingrediente',
    'activo',
    'composicion',
    'formulacion',
    'concentrado',
    'suspension',
    'emulsionable',
    'polvo',
    'mojable',
    'soluble',
    'sl',
    'wp',
    'ec',
    'sc',
    'gr',
    'distribuido',
    'por',
    'fabricado',
    'industria',
    'peruana',
    'agitese',
    'antes',
    'de',
    'usar',
    'mantengase',
    'fuera',
    'del',
    'alcance',
    'ninos',
    'dosis',
    'aplicacion',
    'instrucciones',
    'uso',
    'hoja',
    'foliar',
  };

  /// Normaliza un texto removiendo acentos, caracteres especiales y pasando a minúsculas
  static String normalize(String text) {
    var result = text.toLowerCase();
    result = result.replaceAll(RegExp(r'[áàäâ]'), 'a');
    result = result.replaceAll(RegExp(r'[éèëê]'), 'e');
    result = result.replaceAll(RegExp(r'[íìïî]'), 'i');
    result = result.replaceAll(RegExp(r'[óòöô]'), 'o');
    result = result.replaceAll(RegExp(r'[úùüû]'), 'u');
    result = result.replaceAll(RegExp(r'ñ'), 'n');
    result = result.replaceAll(RegExp(r'[^a-z0-9\s\.\,\-]'), ' ');
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }

  /// Limpia una lista de líneas o bloques de OCR eliminando stopwords irrelevantes
  static List<String> extractMeaningfulKeywords(String rawOcrText) {
    final normalized = normalize(rawOcrText);
    final tokens = normalized.split(RegExp(r'[\s,\/\-]+'));
    final filtered = <String>[];

    for (final token in tokens) {
      final clean = token.trim();
      if (clean.length >= 2 && !_stopwords.contains(clean)) {
        filtered.add(clean);
      }
    }
    return filtered;
  }

  /// Detecta si en el texto de la etiqueta hay indicios claros de una unidad o presentación
  static String? detectPresentationUnit(String rawOcrText) {
    final text = normalize(rawOcrText);

    // 1. Detección de Galón (evaluar antes de litros genéricos como 4L)
    if (RegExp(r'\b(galon|galones|gal|3\.785\s*l)\b').hasMatch(text)) {
      return 'Galón';
    }

    // 2. Detección de Bidón
    if (RegExp(r'\b(bidon|bidones|20\s*l)\b').hasMatch(text)) {
      return 'Bidón 20L';
    }

    // 3. Detección de Saco / Bolsa
    if (RegExp(r'\b(saco|sacos|bolsa|bolsas)\b').hasMatch(text)) {
      final sackKg = RegExp(r'\b(\d+)\s*(?:kg|kilos)\b').firstMatch(text);
      if (sackKg != null) {
        return 'Saco ${sackKg.group(1)}kg';
      }
      return 'Saco';
    }

    // 4. Detección de Sobre / Sachet
    if (RegExp(r'\b(sobre|sobres|sachet|sachets)\b').hasMatch(text)) {
      final gramMatch = RegExp(r'\b(\d+)\s*(?:g|gr|gramos)\b').firstMatch(text);
      if (gramMatch != null) {
        return 'Sobre ${gramMatch.group(1)}g';
      }
      return 'Sobre';
    }

    // 5. Detección de Mililitros
    final mlMatch = RegExp(
      r'\b(\d+)\s*(?:ml|cc|cm3|mililitros)\b',
    ).firstMatch(text);
    if (mlMatch != null) {
      return '${mlMatch.group(1)} ml';
    }

    // 6. Detección de Litros / Volumen
    final literMatch = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*(?:l|lt|lts|litro|litros)\b',
    ).firstMatch(text);
    if (literMatch != null) {
      final qty = literMatch.group(1);
      return qty == '1' ? '1 Litro' : '$qty Litros';
    }
    if (RegExp(r'\b(litro|litros|un litro)\b').hasMatch(text)) {
      return '1 Litro';
    }

    // 7. Detección de Kilos / Peso
    final kgMatch = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*(?:kg|kilo|kilos|kilogramos)\b',
    ).firstMatch(text);
    if (kgMatch != null) {
      final qty = kgMatch.group(1);
      return qty == '1' ? '1 Kilo' : '$qty Kg';
    }

    // 8. Detección de Gramos solos
    final gMatch = RegExp(r'\b(\d+)\s*(?:g|gr|gramos)\b').firstMatch(text);
    if (gMatch != null) {
      return '${gMatch.group(1)}g';
    }

    return null;
  }

  /// Desambigua qué variante del producto corresponde al texto OCR
  static VariantResolutionResult disambiguate({
    required ProductEntity product,
    required String ocrRawText,
  }) {
    final activeVariants =
        product.productVariants.where((v) => v.isActive).toList();

    // Caso 1: El producto no tiene variantes o solo tiene 1 variante
    if (activeVariants.isEmpty) {
      return VariantResolutionResult(
        resolvedVariant: product.defaultVariant,
        candidateVariants:
            product.defaultVariant != null ? [product.defaultVariant!] : [],
        confidence: 1.0,
      );
    }
    if (activeVariants.length == 1) {
      return VariantResolutionResult(
        resolvedVariant: activeVariants.first,
        candidateVariants: activeVariants,
        confidence: 1.0,
      );
    }

    final normalizedOcr = normalize(ocrRawText);
    final detectedUnit = detectPresentationUnit(ocrRawText);

    // Evaluamos cada variante con un sistema de scoring ponderado
    final scoredVariants = <({ProductVariantEntity variant, double score})>[];

    for (final variant in activeVariants) {
      double score = 0.0;
      final variantLabelNorm = normalize(variant.label);
      final variantShortNorm = normalize(variant.shortLabel);
      final skuNorm = normalize(variant.sku ?? '');

      // Atributos de la variante (ej: "1 Litro", "Sobre", "500 ml")
      final attrValuesNorm =
          variant.attributeValues.map((av) => normalize(av.value)).toList();

      // Comparación con unidad detectada
      if (detectedUnit != null) {
        final detectedNorm = normalize(detectedUnit);

        // Coincidencia exacta con etiqueta de variante o atributo
        if (variantLabelNorm.contains(detectedNorm) ||
            variantShortNorm.contains(detectedNorm)) {
          score += 60.0;
        }
        for (final av in attrValuesNorm) {
          if (av == detectedNorm ||
              av.contains(detectedNorm) ||
              detectedNorm.contains(av)) {
            score += 50.0;
          }
        }

        // Casos comunes de sinónimos:
        // Litro vs 1L vs 1000ml
        if (detectedNorm.contains('litro') || detectedNorm.contains('1 l')) {
          if (variantLabelNorm.contains('litro') ||
              variantLabelNorm.contains('1 l') ||
              variantLabelNorm.contains('1l') ||
              variantLabelNorm.contains('1000')) {
            score += 45.0;
          }
        }
        // Sobre vs Gramos
        if (detectedNorm.contains('sobre')) {
          if (variantLabelNorm.contains('sobre') ||
              variantShortNorm.contains('sobre') ||
              skuNorm.contains('sob')) {
            score += 45.0;
          }
        }
        // Galón vs 4L
        if (detectedNorm.contains('galon') || detectedNorm.contains('4 l')) {
          if (variantLabelNorm.contains('galon') ||
              variantLabelNorm.contains('4 l') ||
              variantLabelNorm.contains('4l')) {
            score += 45.0;
          }
        }
      }

      // Verificación directa en el texto OCR completo
      if (variantShortNorm.isNotEmpty &&
          normalizedOcr.contains(variantShortNorm)) {
        score += 35.0;
      }
      for (final av in attrValuesNorm) {
        if (av.isNotEmpty && normalizedOcr.contains(av)) {
          score += 30.0;
        }
      }
      if (skuNorm.isNotEmpty &&
          skuNorm != 'n a' &&
          normalizedOcr.contains(skuNorm)) {
        score += 40.0;
      }

      scoredVariants.add((variant: variant, score: score));
    }

    // Ordenar por mayor puntuación
    scoredVariants.sort((a, b) => b.score.compareTo(a.score));

    final best = scoredVariants.first;
    final secondBest = scoredVariants.length > 1 ? scoredVariants[1] : null;

    final candidateList = scoredVariants.map((item) => item.variant).toList();

    // Verificamos si el ganador supera holgadamente a los demás
    final isClearWinner =
        best.score >= 40.0 &&
        (secondBest == null || (best.score - secondBest.score) >= 20.0);

    if (isClearWinner) {
      final confidence = (best.score / 100.0).clamp(0.0, 1.0);
      return VariantResolutionResult(
        resolvedVariant: best.variant,
        candidateVariants: candidateList,
        detectedPresentation: detectedUnit ?? best.variant.shortLabel,
        confidence: confidence,
      );
    }

    // Si hay ambigüedad o puntaje bajo, retornamos las variantes candidatas para que el usuario elija con 1 tap
    return VariantResolutionResult(
      resolvedVariant: null,
      candidateVariants: candidateList,
      detectedPresentation: detectedUnit,
      confidence: best.score > 0 ? 0.40 : 0.0,
    );
  }
}
