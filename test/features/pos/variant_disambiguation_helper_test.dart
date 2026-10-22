import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/variant_attribute_value_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/services/variant_disambiguation_helper.dart';

void main() {
  group('VariantDisambiguationHelper Unit Tests', () {
    test('Detects volume presentations accurately (Litro, Galon, etc.)', () {
      expect(
        VariantDisambiguationHelper.detectPresentationUnit(
          'FERTILIZANTE FOLIAR CONTENIDO NETO 1 LITRO',
        ),
        equals('1 Litro'),
      );
      expect(
        VariantDisambiguationHelper.detectPresentationUnit(
          'GLIFOSATO 480 SL 1 L',
        ),
        equals('1 Litro'),
      );
      expect(
        VariantDisambiguationHelper.detectPresentationUnit(
          'INSECTICIDA AGRICOLA 250 ML',
        ),
        equals('250 ml'),
      );
      expect(
        VariantDisambiguationHelper.detectPresentationUnit(
          'ABONO FOLIAR 1 GALON 4L',
        ),
        equals('Galón'),
      );
    });

    test('Detects weight/package presentations (Sobre, Saco, Kilo)', () {
      expect(
        VariantDisambiguationHelper.detectPresentationUnit(
          'BAYFOLAN POLVO SOBRE 100 G',
        ),
        equals('Sobre 100g'),
      );
      expect(
        VariantDisambiguationHelper.detectPresentationUnit(
          'FUNGICIDA EN SOBRE',
        ),
        equals('Sobre'),
      );
      expect(
        VariantDisambiguationHelper.detectPresentationUnit(
          'UREA AGRICOLA SACO 50 KG',
        ),
        equals('Saco 50kg'),
      );
      expect(
        VariantDisambiguationHelper.detectPresentationUnit(
          'SULFATO DE COBRE 1 KILO',
        ),
        equals('1 Kilo'),
      );
    });

    test('Disambiguates between variants: Bayfolan Litro vs Sobre vs Galón', () {
      const vLitro = ProductVariantEntity(
        id: 'var-litro-1',
        productId: 'prod-bayfolan',
        sku: 'BAY-1L',
        salePrice: 45.0,
        attributeValues: [
          VariantAttributeValueEntity(
            attributeValueId: 'av-1',
            attributeId: 'att-vol',
            attributeName: 'Presentación',
            value: '1 Litro',
          ),
        ],
      );

      const vSobre = ProductVariantEntity(
        id: 'var-sobre-2',
        productId: 'prod-bayfolan',
        sku: 'BAY-SOBRE',
        salePrice: 8.0,
        attributeValues: [
          VariantAttributeValueEntity(
            attributeValueId: 'av-2',
            attributeId: 'att-vol',
            attributeName: 'Presentación',
            value: 'Sobre 100g',
          ),
        ],
      );

      const vGalon = ProductVariantEntity(
        id: 'var-galon-3',
        productId: 'prod-bayfolan',
        sku: 'BAY-GALON',
        salePrice: 155.0,
        attributeValues: [
          VariantAttributeValueEntity(
            attributeValueId: 'av-3',
            attributeId: 'att-vol',
            attributeName: 'Presentación',
            value: 'Galón 4L',
          ),
        ],
      );

      const product = ProductEntity(
        id: 'prod-bayfolan',
        name: 'Bayfolan Forte',
        productVariants: [vLitro, vSobre, vGalon],
      );

      // Caso 1: Etiqueta con "1 Litro"
      final resLitro = VariantDisambiguationHelper.disambiguate(
        product: product,
        ocrRawText:
            'BAYER BAYFOLAN FORTE FERTILIZANTE FOLIAR CONTENIDO NETO 1 LITRO',
      );
      expect(resLitro.isDirectMatch, isTrue);
      expect(resLitro.resolvedVariant?.id, equals('var-litro-1'));

      // Caso 2: Etiqueta con "Sobre 100g"
      final resSobre = VariantDisambiguationHelper.disambiguate(
        product: product,
        ocrRawText:
            'BAYER BAYFOLAN POLVO SOLUBLE PRESENTACION SOBRE 100G PRECAUCION',
      );
      expect(resSobre.isDirectMatch, isTrue);
      expect(resSobre.resolvedVariant?.id, equals('var-sobre-2'));

      // Caso 3: Etiqueta con "Galón"
      final resGalon = VariantDisambiguationHelper.disambiguate(
        product: product,
        ocrRawText: 'BAYFOLAN FORTE BIDON GALON 4 LITROS',
      );
      expect(resGalon.isDirectMatch, isTrue);
      expect(resGalon.resolvedVariant?.id, equals('var-galon-3'));

      // Caso 4: Solo título sin unidad clara -> ambigüedad controlada para selector de chips
      final resAmbiguous = VariantDisambiguationHelper.disambiguate(
        product: product,
        ocrRawText: 'BAYER BAYFOLAN FORTE FERTILIZANTE',
      );
      expect(resAmbiguous.isDirectMatch, isFalse);
      expect(resAmbiguous.candidateVariants.length, equals(3));
    });
  });
}
