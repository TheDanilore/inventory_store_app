import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:flutter/foundation.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/pdf_generator_repository.dart';

class _PdfIsolateArgs {
  final List<ProductEntity> products;
  final Map<String, List<ProductVariantEntity>> variantsByProduct;
  final Map<String, int> stockByVariant;

  _PdfIsolateArgs({
    required this.products,
    required this.variantsByProduct,
    required this.stockByVariant,
  });
}

Future<Uint8List> _generatePdfInIsolate(_PdfIsolateArgs args) async {
  return await CatalogPdfGeneratorImpl._buildPdfInternal(
    products: args.products,
    variantsByProduct: args.variantsByProduct,
    stockByVariant: args.stockByVariant,
  );
}

@Injectable(as: PdfGeneratorRepository)
class CatalogPdfGeneratorImpl implements PdfGeneratorRepository {
  // Formato de moneda idéntico al que usaba el screen
  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_PE',
    symbol: 'S/ ',
    decimalDigits: 2,
    customPattern: '¤#,##0.00',
  );

  // ── Build ────────────────────────────────────────────────────────────────

  static Future<Uint8List> _buildPdf({
    required List<ProductEntity> products,
    required Map<String, List<ProductVariantEntity>> variantsByProduct,
    required Map<String, int> stockByVariant,
  }) async {
    return await compute(
      _generatePdfInIsolate,
      _PdfIsolateArgs(
        products: products,
        variantsByProduct: variantsByProduct,
        stockByVariant: stockByVariant,
      ),
    );
  }

  static Future<Uint8List> _buildPdfInternal({
    required List<ProductEntity> products,
    required Map<String, List<ProductVariantEntity>> variantsByProduct,
    required Map<String, int> stockByVariant,
  }) async {
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final italicFont = await PdfGoogleFonts.notoSansItalic();

    final doc = pw.Document();
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Descarga de imágenes en lotes pequeños (máximo 5 a la vez) para no saturar sockets
    final Map<String, Uint8List?> productImages = {};
    const batchSize = 5;
    for (int i = 0; i < products.length; i += batchSize) {
      final chunk = products.skip(i).take(batchSize);
      await Future.wait(
        chunk.map((product) async {
          final url = product.primaryImageUrl;
          if (url != null && url.trim().isNotEmpty) {
            try {
              final resp = await http
                  .get(Uri.parse(url))
                  .timeout(const Duration(seconds: 10));
              productImages[product.id] =
                  resp.statusCode == 200 ? resp.bodyBytes : null;
            } catch (_) {
              productImages[product.id] = null;
            }
          } else {
            productImages[product.id] = null;
          }
        }),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont,
          italic: italicFont,
        ),
        build:
            (context) => [
              pw.Text(
                'Catálogo de productos',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Generado: $generatedAt'),
              pw.SizedBox(height: 16),
              ...products.map(
                (product) => _buildProductCard(
                  product: product,
                  variants: variantsByProduct[product.id] ?? [],
                  imageBytes: productImages[product.id],
                  stockByVariant: stockByVariant,
                ),
              ),
            ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildProductCard({
    required ProductEntity product,
    required List<ProductVariantEntity> variants,
    required Uint8List? imageBytes,
    required Map<String, int> stockByVariant,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Imagen o placeholder
              imageBytes != null
                  ? pw.Container(
                    width: 86,
                    height: 86,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.ClipRRect(
                      horizontalRadius: 6,
                      verticalRadius: 6,
                      child: pw.Image(
                        pw.MemoryImage(imageBytes),
                        fit: pw.BoxFit.cover,
                      ),
                    ),
                  )
                  : pw.Container(
                    width: 86,
                    height: 86,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'Sin imagen',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),

              pw.SizedBox(width: 12),

              // Nombre + descripción
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      product.name,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    if (product.description != null &&
                        product.description!.trim().isNotEmpty)
                      pw.Text(
                        product.description!,
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Tabla de variantes
          if (variants.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Variantes',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.8),
                1: const pw.FlexColumnWidth(2.2),
                2: const pw.FlexColumnWidth(1.2),
              },
              children: [
                // Encabezado
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children:
                      ['Atributos', 'Precio', 'Stock'].map((label) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            label,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                // Filas de variantes
                ...variants.map((variant) {
                  final stock = stockByVariant[variant.id] ?? 0;
                  final price = variant.salePrice ?? product.salePrice;
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          variant.label,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          _currencyFormat.format(price),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          '$stock',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Métodos públicos (misma convención que OrderPdfGenerator) ────────────

  /// Abre el diálogo de impresión / vista previa del sistema.
  @override
  Future<void> shareCatalog({
    required List<ProductEntity> products,
    required Map<String, List<ProductVariantEntity>> variantsByProduct,
    required Map<String, int> stockByVariant,
  }) async {
    final bytes = await _buildPdf(
      products: products,
      variantsByProduct: variantsByProduct,
      stockByVariant: stockByVariant,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Catalogo_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
