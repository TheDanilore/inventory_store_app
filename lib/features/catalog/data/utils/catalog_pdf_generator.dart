import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/catalog/data/utils/product_pdf_generator.dart';

import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:flutter/foundation.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

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
  return await CatalogPdfGenerator._buildPdfInternal(
    products: args.products,
    variantsByProduct: args.variantsByProduct,
    stockByVariant: args.stockByVariant,
  );
}

class CatalogPdfGenerator {
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

  static Future<void> shareProduct(
    ProductEntity product, {
    required List<ProductVariantEntity> variants,
    required Map<String, int> stockByVariant,
  }) async {
    await ProductPdfGenerator.shareProduct(
      product,
      variants: variants,
      stockByVariant: stockByVariant,
    );
  }

  static Future<Uint8List> _buildPdfInternal({
    required List<ProductEntity> products,
    required Map<String, List<ProductVariantEntity>> variantsByProduct,
    required Map<String, int> stockByVariant,
  }) async {
    pw.Font baseFont;
    pw.Font boldFont;
    pw.Font italicFont;
    try {
      baseFont = await PdfGoogleFonts.notoSansRegular();
      boldFont = await PdfGoogleFonts.notoSansBold();
      italicFont = await PdfGoogleFonts.notoSansItalic();
    } catch (_) {
      baseFont = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
      italicFont = pw.Font.helveticaOblique();
    }

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
    pw.ImageProvider? imageProvider;
    if (imageBytes != null) {
      try {
        imageProvider = pw.MemoryImage(imageBytes);
      } catch (_) {
        imageProvider = null;
      }
    }

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
              imageProvider != null
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
                        imageProvider,
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

              // Nombre + descripción + resumen de precio y stock
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
                    pw.SizedBox(height: 4),
                    if (product.categoryName != null &&
                        product.categoryName!.trim().isNotEmpty) ...[
                      pw.Text(
                        'Categoría: ${product.categoryName}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                    ],
                    if (product.description != null &&
                        product.description!.trim().isNotEmpty) ...[
                      pw.Text(
                        product.description!,
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                    ],
                    // Siempre mostrar resumen de precio y stock por defecto
                    pw.Text(
                      'Precio base: ${_currencyFormat.format(product.displaySalePrice ?? 0.0)}   |   Stock total: ${product.totalStock}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Tabla de variantes si tiene variantes personalizadas o múltiples
          if (variants.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Variantes / Desglose de Stock',
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
                      ['Atributos / SKU', 'Precio', 'Stock'].map((label) {
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
                  var stock = stockByVariant[variant.id] ?? 0;
                  if (stock == 0 && variants.length == 1 && product.totalStock > 0) {
                    stock = product.totalStock;
                  }
                  final price = variant.salePrice ?? product.displaySalePrice ?? 0.0;
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
  static Future<void> shareCatalog({
    required List<ProductEntity> products,
    required Map<String, List<ProductVariantEntity>> variantsByProduct,
    required Map<String, int> stockByVariant,
  }) async {
    final bytes = await _buildPdf(
      products: products,
      variantsByProduct: variantsByProduct,
      stockByVariant: stockByVariant,
    );
    final fileName = 'Catalogo_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: fileName,
      );
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );
    }
  }
}
