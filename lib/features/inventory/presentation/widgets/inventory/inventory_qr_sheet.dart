import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:inventory_store_app/core/services/file_export_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

/// URL pública de la app. El QR "Enlace a ficha" apunta a
/// `<base>/product/<productId>?variantId=<variantId>`
const String kInventoryQrBaseUrl = 'https://inventory-store-app-six.vercel.app';

enum _CodeType { barcode, qr }

enum _CodePayloadMode { sku, barcode, productId, link }

/// Generador de Etiquetas: Códigos de Barra (1D Code 128) y Códigos QR (2D).
///
/// Permite previsualizar, alternar formato (Barras / QR) y copiar o imprimir
/// la etiqueta para identificación física en góndolas, almacén y POS.
class InventoryQrSheet {
  static Future<void> show(
    BuildContext context, {
    required String productId,
    required String variantId,
    required String productName,
    String? variantName,
    String? sku,
    String? barcode,
  }) {
    return AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: 480,
      barrierLabel: 'Cerrar generador de códigos',
      builder:
          (_) => _InventoryQrContent(
            productId: productId,
            variantId: variantId,
            productName: productName,
            variantName: variantName,
            sku: sku,
            barcode: barcode,
          ),
    );
  }
}

class _InventoryQrContent extends StatefulWidget {
  final String productId;
  final String variantId;
  final String productName;
  final String? variantName;
  final String? sku;
  final String? barcode;

  const _InventoryQrContent({
    required this.productId,
    required this.variantId,
    required this.productName,
    this.variantName,
    this.sku,
    this.barcode,
  });

  @override
  State<_InventoryQrContent> createState() => _InventoryQrContentState();
}

class _InventoryQrContentState extends State<_InventoryQrContent> {
  _CodeType _type = _CodeType.barcode;
  late _CodePayloadMode _payloadMode;

  @override
  void initState() {
    super.initState();
    if (_hasBarcode) {
      _payloadMode = _CodePayloadMode.barcode;
    } else if (_hasSku) {
      _payloadMode = _CodePayloadMode.sku;
    } else {
      _payloadMode = _CodePayloadMode.productId;
    }
  }

  String? get _cleanSku {
    final s = widget.sku?.trim();
    if (s == null || s.isEmpty || s.toUpperCase() == 'N/A') return null;
    return s;
  }

  String? get _cleanBarcode {
    final b = widget.barcode?.trim();
    if (b == null || b.isEmpty) return null;
    return b;
  }

  bool get _hasSku => _cleanSku != null;
  bool get _hasBarcode => _cleanBarcode != null;

  String get _variantLabel {
    final v = widget.variantName?.trim() ?? '';
    if (v.isEmpty ||
        v == 'Única' ||
        v.toLowerCase() == 'variante estándar' ||
        v.toLowerCase() == 'estándar') {
      return '';
    }
    return v;
  }

  String get _linkPayload {
    final base = Uri.parse(kInventoryQrBaseUrl);
    return base
        .replace(
          path: '/product/${widget.productId}',
          queryParameters:
              widget.variantId.isNotEmpty
                  ? {'variantId': widget.variantId}
                  : null,
        )
        .toString();
  }

  String get _effectiveData {
    switch (_payloadMode) {
      case _CodePayloadMode.barcode:
        return _cleanBarcode ?? _cleanSku ?? widget.productId;
      case _CodePayloadMode.sku:
        return _cleanSku ?? _cleanBarcode ?? widget.productId;
      case _CodePayloadMode.productId:
        return widget.productId;
      case _CodePayloadMode.link:
        return _linkPayload;
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.success,
    );
  }

  pw.Document _buildLabelDoc() {
    final isBarcode = _type == _CodeType.barcode;
    final data = _effectiveData;
    final doc = pw.Document();

    // Formato estándar de etiqueta adhesiva térmica (50mm x 30mm)
    const pageFormat = PdfPageFormat(
      50 * PdfPageFormat.mm,
      30 * PdfPageFormat.mm,
      marginAll: 2 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  widget.productName,
                  maxLines: 1,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (_variantLabel.isNotEmpty)
                  pw.Text(
                    _variantLabel,
                    maxLines: 1,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                pw.SizedBox(height: 2),
                if (isBarcode)
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: data,
                    height: 14 * PdfPageFormat.mm,
                    width: 44 * PdfPageFormat.mm,
                    drawText: true,
                    textStyle: const pw.TextStyle(fontSize: 6.5),
                  )
                else
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: data,
                    height: 16 * PdfPageFormat.mm,
                    width: 16 * PdfPageFormat.mm,
                    drawText: false,
                  ),
                if (!isBarcode) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    data.length > 25 ? '${data.substring(0, 22)}...' : data,
                    style: const pw.TextStyle(fontSize: 5.5),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    return doc;
  }

  Future<void> _printLabel() async {
    try {
      final doc = _buildLabelDoc();
      await Printing.layoutPdf(
        name: 'Etiqueta_${widget.productName.replaceAll(' ', '_')}',
        onLayout: (format) async => doc.save(),
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al abrir diálogo de impresión: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _savePdfLabel() async {
    try {
      final doc = _buildLabelDoc();
      final bytes = await doc.save();
      final cleanName = widget.productName
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final fileName = 'Etiqueta_${cleanName}_$_effectiveData';

      final result = await FileExportService.save(
        fileName: fileName,
        bytes: bytes,
        extension: 'pdf',
        mimeType: MimeType.pdf,
        dialogTitle: 'Guardar Etiqueta PDF',
      );

      if (!mounted) return;
      if (result.isSaved) {
        AppSnackbar.show(
          context,
          message: 'Etiqueta guardada exitosamente.',
          type: SnackbarType.success,
        );
      } else if (result.isFailed) {
        AppSnackbar.show(
          context,
          message: 'Error al guardar la etiqueta: ${result.error}',
          type: SnackbarType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al exportar la etiqueta: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _shareWhatsApp() async {
    final buffer = StringBuffer();
    buffer.writeln('🏷️ *ETIQUETA DE PRODUCTO*');
    buffer.writeln('📦 *Producto:* ${widget.productName}');
    if (_variantLabel.isNotEmpty) {
      buffer.writeln('🔹 *Variante:* $_variantLabel');
    }
    if (_hasSku) {
      buffer.writeln('🔖 *SKU:* $_cleanSku');
    }
    if (_hasBarcode) {
      buffer.writeln('📊 *Código de Barras:* $_cleanBarcode');
    }
    buffer.writeln('🔢 *Código codificado:* $_effectiveData');
    if (_payloadMode == _CodePayloadMode.link) {
      buffer.writeln('🔗 *Enlace ficha:* $_linkPayload');
    }

    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(buffer.toString())}',
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'No se pudo abrir WhatsApp',
            type: SnackbarType.warning,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al abrir WhatsApp: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (_variantLabel.isNotEmpty) _variantLabel,
      if (_hasSku) 'SKU: $_cleanSku',
      if (_hasBarcode) 'Barras: $_cleanBarcode',
    ];

    return DetailSheetFrame(
      title: widget.productName,
      subtitle:
          subtitleParts.isEmpty
              ? const Text(
                'Generador de Código de Barras y QR',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
              : Text(
                subtitleParts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.teal.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.barcode_reader,
          size: 20,
          color: AppColors.tealDark,
        ),
      ),
      bodyPadding: const EdgeInsets.all(20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Selector de Tipo: Código de Barras 1D vs QR 2D ─────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _type = _CodeType.barcode),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            _type == _CodeType.barcode
                                ? Colors.white
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow:
                            _type == _CodeType.barcode
                                ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                  ),
                                ]
                                : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.barcode_reader,
                            size: 17,
                            color:
                                _type == _CodeType.barcode
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Código de Barras (1D)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  _type == _CodeType.barcode
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                              color:
                                  _type == _CodeType.barcode
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _type = _CodeType.qr),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            _type == _CodeType.qr
                                ? Colors.white
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow:
                            _type == _CodeType.qr
                                ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                  ),
                                ]
                                : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 17,
                            color:
                                _type == _CodeType.qr
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Código QR (2D)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  _type == _CodeType.qr
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                              color:
                                  _type == _CodeType.qr
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Selector de Dato a Codificar ──────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_hasBarcode)
                ChoiceChip(
                  label: Text('Barras: $_cleanBarcode'),
                  avatar: const Icon(Icons.linear_scale_rounded, size: 15),
                  selected: _payloadMode == _CodePayloadMode.barcode,
                  onSelected: (selected) {
                    setState(() {
                      _payloadMode =
                          selected
                              ? _CodePayloadMode.barcode
                              : (_hasSku
                                  ? _CodePayloadMode.sku
                                  : _CodePayloadMode.productId);
                    });
                  },
                ),
              if (_hasSku)
                ChoiceChip(
                  label: Text('SKU: $_cleanSku'),
                  avatar: const Icon(Icons.tag_rounded, size: 15),
                  selected: _payloadMode == _CodePayloadMode.sku,
                  onSelected: (selected) {
                    setState(() {
                      _payloadMode =
                          selected
                              ? _CodePayloadMode.sku
                              : (_hasBarcode
                                  ? _CodePayloadMode.barcode
                                  : _CodePayloadMode.productId);
                    });
                  },
                ),
              ChoiceChip(
                label: const Text('ID de Producto'),
                avatar: const Icon(Icons.fingerprint_rounded, size: 15),
                selected: _payloadMode == _CodePayloadMode.productId,
                onSelected: (selected) {
                  setState(() {
                    _payloadMode =
                        selected
                            ? _CodePayloadMode.productId
                            : (_hasBarcode
                                ? _CodePayloadMode.barcode
                                : (_hasSku
                                    ? _CodePayloadMode.sku
                                    : _CodePayloadMode.productId));
                  });
                },
              ),
              ChoiceChip(
                label: const Text('Enlace a Ficha'),
                avatar: const Icon(Icons.link_rounded, size: 15),
                selected: _payloadMode == _CodePayloadMode.link,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _payloadMode = _CodePayloadMode.link;
                      _type = _CodeType.qr;
                    } else {
                      _payloadMode =
                          _hasBarcode
                              ? _CodePayloadMode.barcode
                              : (_hasSku
                                  ? _CodePayloadMode.sku
                                  : _CodePayloadMode.productId);
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Tarjeta de Etiqueta Imprimible (Fondo Blanco) ───────────────────
          DetailSectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                // Nombre del producto en la etiqueta
                Text(
                  widget.productName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_variantLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _variantLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // Visualizador del Código según el modo
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child:
                      _type == _CodeType.barcode
                          ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BarcodeWidget(
                                barcode: Barcode.code128(),
                                data: _effectiveData,
                                width: 280,
                                height: 85,
                                drawText: true,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                  letterSpacing: 2,
                                ),
                                errorBuilder:
                                    (context, error) => Text(
                                      'Formato no soportado en 1D: $_effectiveData',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 11,
                                      ),
                                    ),
                              ),
                            ],
                          )
                          : QrImageView(
                            data: _effectiveData,
                            version: QrVersions.auto,
                            size: 210,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                            padding: EdgeInsets.zero,
                          ),
                ),
                const SizedBox(height: 12),

                // Detalle del valor codificado
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _effectiveData,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _printLabel,
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text(
                'IMPRIMIR ETIQUETA (50x30mm)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareWhatsApp,
                  icon: const Icon(
                    Icons.chat_bubble_rounded,
                    size: 15,
                    color: Color(0xFF16A34A),
                  ),
                  label: const Text(
                    'WhatsApp',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                    ),
                    backgroundColor: const Color(
                      0xFF16A34A,
                    ).withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _savePdfLabel,
                  icon: const Icon(
                    Icons.download_rounded,
                    size: 15,
                    color: Color(0xFFD97706),
                  ),
                  label: const Text(
                    'Guardar PDF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(
                      color: const Color(0xFFD97706).withValues(alpha: 0.4),
                    ),
                    backgroundColor: const Color(
                      0xFFD97706,
                    ).withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(_effectiveData, 'Código'),
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  label: const Text(
                    'Copiar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
