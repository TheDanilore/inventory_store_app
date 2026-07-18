import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';

class ProductPdfGenerator {
  static Future<Uint8List> _buildPdf(
    ProductEntity product, {
    required List<ProductVariantEntity> variants,
    required Map<String, int> stockByVariant,
  }) async {
    final pdf = pw.Document();

    // 1. Descargar imagen principal si existe
    pw.ImageProvider? mainImage;
    if (product.images.isNotEmpty) {
      try {
        mainImage = await networkImage(product.images.first.imageUrl);
      } catch (_) {}
    }

    // 2. Descargar imágenes de las variantes
    Map<String, pw.ImageProvider> variantImages = {};
    for (var v in variants) {
      String? variantImgUrl;
      if (v.images.isNotEmpty) {
        variantImgUrl = v.images.first.imageUrl;
      } else {
        // Buscar la imagen de la variante en las imágenes del producto
        try {
          final match = product.images.firstWhere(
            (img) => img.variantId == v.id,
          );
          variantImgUrl = match.imageUrl;
        } catch (_) {}
      }

      if (variantImgUrl != null && variantImgUrl.isNotEmpty) {
        try {
          variantImages[v.id] = await networkImage(variantImgUrl);
        } catch (_) {}
      }
    }

    // 3. Construir el PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // --- CABECERA DEL PRODUCTO ---
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (mainImage != null)
                  pw.Container(
                    width: 120,
                    height: 120,
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.ClipRRect(
                      horizontalRadius: 12,
                      verticalRadius: 12,
                      child: pw.Image(mainImage, fit: pw.BoxFit.cover),
                    ),
                  ),
                if (mainImage != null) pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        product.name,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Precio Base: S/ ${product.salePrice.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.teal800,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      if (product.description != null &&
                          product.description!.trim().isNotEmpty)
                        pw.Text(
                          'Descripción: ${product.description}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      if (product.details.isNotEmpty) ...[
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'Detalles Adicionales:',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        ...product.details.entries.map(
                          (e) => pw.Text(
                            '- ${e.key}: ${e.value}',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 16),

            // --- TABLA DE VARIANTES Y STOCK ---
            pw.Text(
              'Variantes Disponibles',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FixedColumnWidth(50),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FixedColumnWidth(70),
                4: const pw.FixedColumnWidth(60),
              },
              children: [
                // Cabecera de la tabla
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.teal700),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Img',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Atributos',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'SKU',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Precio',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Stock',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // Filas por cada variante
                ...variants.map((v) {
                  final price = v.salePrice ?? product.salePrice;
                  final stock = stockByVariant[v.id] ?? 0;
                  final img = variantImages[v.id] ?? mainImage;

                  return pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Center(
                          child:
                              img != null
                                  ? pw.Container(
                                    width: 36,
                                    height: 36,
                                    child: pw.Image(img, fit: pw.BoxFit.cover),
                                  )
                                  : pw.SizedBox(width: 36, height: 36),
                        ),
                      ),

                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          v.label,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          v.sku ?? '-',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'S/ ${price.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '$stock',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color:
                                stock > 0
                                    ? PdfColors.green700
                                    : PdfColors.red700,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printProduct(
    ProductEntity product, {
    required List<ProductVariantEntity> variants,
    required Map<String, int> stockByVariant,
  }) async {
    final bytes = await _buildPdf(
      product,
      variants: variants,
      stockByVariant: stockByVariant,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Producto_${product.name.replaceAll(' ', '_')}.pdf',
    );
  }

  static Future<void> shareProduct(
    ProductEntity product, {
    required List<ProductVariantEntity> variants,
    required Map<String, int> stockByVariant,
  }) async {
    final bytes = await _buildPdf(
      product,
      variants: variants,
      stockByVariant: stockByVariant,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Producto_${product.name.replaceAll(' ', '_')}.pdf',
    );
  }

  static Future<void> saveProduct(
    ProductEntity product, {
    required List<ProductVariantEntity> variants,
    required Map<String, int> stockByVariant,
  }) async {
    final bytes = await _buildPdf(
      product,
      variants: variants,
      stockByVariant: stockByVariant,
    );

    await FileSaver.instance.saveFile(
      name: 'Producto_${product.name.replaceAll(' ', '_')}',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static Future<void> saveProductAs(
    ProductEntity product, {
    required List<ProductVariantEntity> variants,
    required Map<String, int> stockByVariant,
  }) async {
    final bytes = await _buildPdf(
      product,
      variants: variants,
      stockByVariant: stockByVariant,
    );

    await FileSaver.instance.saveAs(
      name: 'Producto_${product.name.replaceAll(' ', '_')}',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }
}
