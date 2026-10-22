import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/catalog/data/utils/product_pdf_generator.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';

/// Panel adaptativo de comprobación y exportación de Ficha Técnica de Producto.
class ProductExportSheet extends StatefulWidget {
  final ProductEntity product;
  final List<ProductVariantEntity> variants;
  final Map<String, int> stockByVariant;

  const ProductExportSheet({
    super.key,
    required this.product,
    required this.variants,
    required this.stockByVariant,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductEntity product,
    required List<ProductVariantEntity> variants,
    required Map<String, int> stockByVariant,
  }) {
    return AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: 500,
      barrierLabel: 'Cerrar ficha técnica',
      builder:
          (_) => ProductExportSheet(
            product: product,
            variants: variants,
            stockByVariant: stockByVariant,
          ),
    );
  }

  @override
  State<ProductExportSheet> createState() => _ProductExportSheetState();
}

class _ProductExportSheetState extends State<ProductExportSheet> {
  bool _isProcessing = false;
  String? _processingLabel;

  String get _productShareText {
    final buffer = StringBuffer();
    buffer.writeln('📦 *${widget.product.name.toUpperCase()}*');
    if (widget.product.brandName != null &&
        widget.product.brandName!.isNotEmpty) {
      buffer.writeln('🏷️ Marca: ${widget.product.brandName}');
    }
    if (widget.product.categoryName != null &&
        widget.product.categoryName!.isNotEmpty) {
      buffer.writeln('📂 Categoría: ${widget.product.categoryName}');
    }

    final price = widget.product.displaySalePrice ?? 0.0;
    buffer.writeln('💰 Precio: S/ ${price.toStringAsFixed(2)}');
    buffer.writeln('📊 Stock Total: ${widget.product.totalStock} unidades');

    if (widget.product.description != null &&
        widget.product.description!.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('📝 Descripción:');
      buffer.writeln(widget.product.description!.trim());
    }

    if (widget.variants.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('📋 Variantes disponibles:');
      for (final v in widget.variants) {
        final st = widget.stockByVariant[v.id] ?? 0;
        final p = v.salePrice ?? price;
        final vLabel = v.label.isNotEmpty ? v.label : (v.sku ?? 'Estándar');
        buffer.writeln('• $vLabel: S/ ${p.toStringAsFixed(2)} ($st en stock)');
      }
    }

    return buffer.toString();
  }

  Future<void> _handlePrint() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingLabel = 'Preparando impresión...';
    });

    try {
      await ProductPdfGenerator.printProduct(
        widget.product,
        variants: widget.variants,
        stockByVariant: widget.stockByVariant,
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al imprimir ficha técnica: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingLabel = null;
        });
      }
    }
  }

  Future<void> _handleWhatsApp() async {
    final text = Uri.encodeComponent(_productShareText);
    final url = Uri.parse('https://wa.me/?text=$text');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: _productShareText));
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Información copiada para compartir por WhatsApp.',
            type: SnackbarType.info,
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _productShareText));
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Información copiada al portapapeles.',
          type: SnackbarType.info,
        );
      }
    }
  }

  Future<void> _handleEmail() async {
    final config = context.read<AppConfigCubit>();
    final subject = Uri.encodeComponent(
      'Ficha Técnica: ${widget.product.name} - ${config.businessName}',
    );
    final body = Uri.encodeComponent(_productShareText);
    final url = Uri.parse('mailto:?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: _productShareText));
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Información copiada al portapapeles.',
            type: SnackbarType.info,
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _productShareText));
    }
  }

  Future<void> _handleSavePdf() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingLabel = 'Guardando PDF...';
    });

    try {
      await ProductPdfGenerator.saveProduct(
        widget.product,
        variants: widget.variants,
        stockByVariant: widget.stockByVariant,
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Ficha técnica en PDF descargada con éxito.',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al guardar PDF: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingLabel = null;
        });
      }
    }
  }

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: _productShareText));
    if (mounted) {
      AppSnackbar.show(
        context,
        message: 'Ficha técnica copiada al portapapeles.',
        type: SnackbarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailSheetFrame(
      title: 'Ficha Técnica de Producto',
      subtitle: Text(
        widget.product.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.picture_as_pdf_rounded,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      bodyPadding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── BARRA DE ACCIONES ──
          _buildActionButtons(),

          const SizedBox(height: 16),

          // ── VISTA PREVIA DEL DOCUMENTO ──
          _buildDocumentPreview(),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              child: const Text(
                'Cerrar',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Botón Principal: IMPRIMIR FICHA
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: _isProcessing ? null : _handlePrint,
              icon:
                  _isProcessing &&
                          _processingLabel?.contains('impresión') == true
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.print_rounded, size: 18),
              label: const Text(
                'IMPRIMIR FICHA TÉCNICA',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 13,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Fila 1: WHATSAPP + CORREO
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: _handleWhatsApp,
                    icon: const Icon(Icons.chat_rounded, size: 16),
                    label: const Text(
                      'WHATSAPP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: _handleEmail,
                    icon: const Icon(Icons.mail_rounded, size: 16),
                    label: const Text(
                      'CORREO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Fila 2: GUARDAR PDF + COPIAR DETALLES
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: _isProcessing ? null : _handleSavePdf,
                    icon:
                        _isProcessing &&
                                _processingLabel?.contains('PDF') == true
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 16,
                            ),
                    label: const Text(
                      'GUARDAR PDF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: _handleCopy,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text(
                      'COPIAR TEXTO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF475569),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
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

  Widget _buildDocumentPreview() {
    final price = widget.product.displaySalePrice ?? 0.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Ficha Técnica
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DOCUMENTO TÉCNICO OFICIAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'FORMATO A4',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Título y Precio
          Text(
            widget.product.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  'S/ ${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Stock Total: ${widget.product.totalStock} unidades',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Metadatos
          _specRow('Marca:', widget.product.brandName ?? 'Sin marca'),
          _specRow('Categoría:', widget.product.categoryName ?? 'General'),
          _specRow(
            'Control de Stock:',
            widget.product.stockControl ? 'Activo' : 'Inactivo',
          ),

          if (widget.product.description != null &&
              widget.product.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'DESCRIPCIÓN:',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.product.description!.trim(),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF334155),
                height: 1.4,
              ),
            ),
          ],

          if (widget.variants.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'VARIANTES DEL PRODUCTO:',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Variante',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                        Text(
                          'Stock / Precio',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...widget.variants.map((v) {
                    final st = widget.stockByVariant[v.id] ?? 0;
                    final p = v.salePrice ?? price;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              v.label.isNotEmpty
                                  ? v.label
                                  : (v.sku ?? 'Estándar'),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Text(
                            '$st uds · S/ ${p.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
