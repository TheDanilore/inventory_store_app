import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

/// URL pública de la app. El QR "Enlace a ficha" apunta a
/// `<base>/product/<productId>?variantId=<variantId>`
const String kInventoryQrBaseUrl = 'https://inventory-store-app-six.vercel.app';

enum _CodeType { barcode, qr }

enum _CodePayloadMode { sku, barcode, link }

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
      desktopWidth: 440,
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
  _CodePayloadMode _payloadMode = _CodePayloadMode.sku;

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
        if (_hasBarcode) return _cleanBarcode!;
        if (_hasSku) return _cleanSku!;
        return widget.productId;
      case _CodePayloadMode.sku:
        if (_hasSku) return _cleanSku!;
        if (_hasBarcode) return _cleanBarcode!;
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
              if (_hasSku)
                ChoiceChip(
                  label: const Text('SKU'),
                  avatar: const Icon(Icons.tag_rounded, size: 15),
                  selected: _payloadMode == _CodePayloadMode.sku,
                  onSelected:
                      (_) =>
                          setState(() => _payloadMode = _CodePayloadMode.sku),
                ),
              if (_hasBarcode)
                ChoiceChip(
                  label: const Text('Código de Barras'),
                  avatar: const Icon(Icons.linear_scale_rounded, size: 15),
                  selected: _payloadMode == _CodePayloadMode.barcode,
                  onSelected:
                      (_) => setState(
                        () => _payloadMode = _CodePayloadMode.barcode,
                      ),
                ),
              ChoiceChip(
                label: const Text('Enlace a Ficha'),
                avatar: const Icon(Icons.link_rounded, size: 15),
                selected: _payloadMode == _CodePayloadMode.link,
                onSelected:
                    (_) => setState(() => _payloadMode = _CodePayloadMode.link),
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
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _copy(_effectiveData, 'Código'),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copiar Código'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: AppColors.border),
                foregroundColor: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                _copy(_effectiveData, 'Etiqueta');
                AppSnackbar.show(
                  context,
                  message: 'Etiqueta lista para escaneo o impresión rápida.',
                  type: SnackbarType.success,
                );
              },
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Listo para Imprimir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
