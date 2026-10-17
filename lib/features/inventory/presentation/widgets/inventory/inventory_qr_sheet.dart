import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// URL pública de la app. El QR "Enlace a ficha" apunta a
/// `<base>/product/<productId>?variantId=<variantId>` (misma ruta que usa
/// el inventario para abrir la ficha completa), así que cualquier celular
/// que lo escanee con la cámara abre el producto directamente.
///
/// Cámbiala si el dominio de producción es otro.
const String kInventoryQrBaseUrl = 'https://inventory-store-app-six.vercel.app';

enum _QrContent { link, sku }

/// Muestra el código QR de una variante de inventario.
///
/// Desktop/tablet: panel lateral. Móvil: bottom sheet
/// (ver [AdaptiveDetailSheet]).
class InventoryQrSheet {
  static Future<void> show(
    BuildContext context, {
    required String productId,
    required String variantId,
    required String productName,
    String? variantName,
    String? sku,
  }) {
    return AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: 420,
      barrierLabel: 'Cerrar código QR',
      builder:
          (_) => _InventoryQrContent(
            productId: productId,
            variantId: variantId,
            productName: productName,
            variantName: variantName,
            sku: sku,
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

  const _InventoryQrContent({
    required this.productId,
    required this.variantId,
    required this.productName,
    this.variantName,
    this.sku,
  });

  @override
  State<_InventoryQrContent> createState() => _InventoryQrContentState();
}

class _InventoryQrContentState extends State<_InventoryQrContent> {
  _QrContent _mode = _QrContent.link;

  String? get _cleanSku {
    final s = widget.sku?.trim();
    if (s == null || s.isEmpty || s.toUpperCase() == 'N/A') return null;
    return s;
  }

  bool get _hasSku => _cleanSku != null;

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

  String get _payload =>
      _mode == _QrContent.sku && _hasSku ? _cleanSku! : _linkPayload;

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
      if (_hasSku) 'SKU $_cleanSku',
    ];

    return DetailSheetFrame(
      title: widget.productName,
      subtitle:
          subtitleParts.isEmpty
              ? const Text(
                'Código QR de la variante',
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
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.qr_code_2_rounded,
          size: 20,
          color: AppColors.primary,
        ),
      ),
      bodyPadding: const EdgeInsets.all(20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector de contenido
          if (_hasSku) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Enlace a la ficha'),
                  avatar: const Icon(Icons.link_rounded, size: 16),
                  selected: _mode == _QrContent.link,
                  onSelected: (_) => setState(() => _mode = _QrContent.link),
                ),
                ChoiceChip(
                  label: const Text('Solo SKU'),
                  avatar: const Icon(Icons.tag_rounded, size: 16),
                  selected: _mode == _QrContent.sku,
                  onSelected: (_) => setState(() => _mode = _QrContent.sku),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Tarjeta del QR (fondo blanco siempre, para que escanee bien
          // también en modo oscuro)
          DetailSectionCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: QrImageView(
                    data: _payload,
                    version: QrVersions.auto,
                    size: 230,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.productName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_variantLabel.isNotEmpty)
                  Text(
                    _variantLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (_hasSku)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _cleanSku!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Contenido codificado
          DetailSectionCard(
            title: 'Contenido del QR',
            icon: Icons.data_object_rounded,
            child: SelectableText(
              _payload,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      footer: Row(
        children: [
          if (_hasSku) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copy(_cleanSku!, 'SKU'),
                icon: const Icon(Icons.tag_rounded, size: 16),
                label: const Text('Copiar SKU'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed:
                  () => _copy(
                    _payload,
                    _mode == _QrContent.sku && _hasSku ? 'SKU' : 'Enlace',
                  ),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copiar contenido'),
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
