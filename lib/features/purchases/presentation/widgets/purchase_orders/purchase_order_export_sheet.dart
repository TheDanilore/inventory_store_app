import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/data/utils/purchase_order_pdf_generator.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_purchase_order_items_usecase.dart';

/// Sheet adaptativo para previsualizar y exportar/compartir una Orden de Compra.
///
/// Responsive: Bottom sheet en móviles y Side Sheet flotante en desktop (>=900px).
/// Permite comprobar los detalles de la orden antes de emitir, imprimir en PDF,
/// compartir vía WhatsApp o Correo, o guardar el archivo PDF.
class PurchaseOrderExportSheet extends StatefulWidget {
  final PurchaseOrderModel po;
  final List<PurchaseOrderItemEntity>? initialItems;
  final Future<List<PurchaseOrderItemEntity>> Function()? loadItems;

  const PurchaseOrderExportSheet({
    super.key,
    required this.po,
    this.initialItems,
    this.loadItems,
  });

  static Future<void> show(
    BuildContext context, {
    required PurchaseOrderModel po,
    List<PurchaseOrderItemEntity>? initialItems,
    Future<List<PurchaseOrderItemEntity>> Function()? loadItems,
  }) {
    final shortCode =
        po.id.substring(0, po.id.length >= 8 ? 8 : po.id.length).toUpperCase();
    return AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: 540,
      barrierLabel: 'Cerrar vista de orden #OC-$shortCode',
      builder:
          (_) => PurchaseOrderExportSheet(
            po: po,
            initialItems: initialItems,
            loadItems: loadItems,
          ),
    );
  }

  @override
  State<PurchaseOrderExportSheet> createState() =>
      _PurchaseOrderExportSheetState();
}

class _PurchaseOrderExportSheetState extends State<PurchaseOrderExportSheet> {
  late List<PurchaseOrderItemEntity> _items;
  bool _isLoadingItems = false;
  bool _isProcessingAction = false;

  String get _shortCode =>
      widget.po.id
          .substring(0, widget.po.id.length >= 8 ? 8 : widget.po.id.length)
          .toUpperCase();

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems ?? [];
    if (_items.isEmpty) {
      _fetchItems();
    }
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoadingItems = true);
    try {
      if (widget.loadItems != null) {
        final res = await widget.loadItems!();
        if (mounted) setState(() => _items = res);
      } else {
        final useCase = sl<FetchPurchaseOrderItemsUseCase>();
        final res = await useCase.call(widget.po.id);
        if (mounted) {
          res.fold((l) => null, (r) => setState(() => _items = r));
        }
      }
    } catch (_) {
      // Ignorar fallback a lista vacía
    } finally {
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _handlePrint() async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);
    try {
      await PurchaseOrderPdfGenerator.printPdf(po: widget.po, items: _items);
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al abrir diálogo de impresión: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handleSavePdf() async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);
    try {
      final result = await PurchaseOrderPdfGenerator.savePdf(
        po: widget.po,
        items: _items,
      );
      if (!mounted) return;
      if (result.isSaved) {
        AppSnackbar.show(
          context,
          message: 'Orden de compra guardada exitosamente.',
          type: SnackbarType.success,
        );
      } else if (result.isFailed) {
        AppSnackbar.show(
          context,
          message: 'Error al guardar la orden: ${result.error}',
          type: SnackbarType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al generar PDF: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handleWhatsApp() async {
    final text = PurchaseOrderPdfGenerator.buildWhatsAppText(
      po: widget.po,
      items: _items,
    );
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
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

  Future<void> _handleEmail() async {
    final subject =
        'Orden de Compra #OC-$_shortCode - ${widget.po.supplierName}';
    final body = PurchaseOrderPdfGenerator.buildWhatsAppText(
      po: widget.po,
      items: _items,
    );
    final emailUri = Uri(
      scheme: 'mailto',
      queryParameters: {'subject': subject, 'body': body},
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'No se pudo abrir el gestor de correo',
            type: SnackbarType.warning,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al abrir correo: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _handleCopy() {
    final text = PurchaseOrderPdfGenerator.buildWhatsAppText(
      po: widget.po,
      items: _items,
    );
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: 'Resumen de la orden copiado al portapapeles',
      type: SnackbarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es');

    return DetailSheetFrame(
      title: 'Orden de Compra #OC-$_shortCode',
      subtitle: Text(
        '${widget.po.supplierName} · ${dateFormat.format(widget.po.createdAt.toLocal())}',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F766E).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.shopping_bag_outlined,
          size: 20,
          color: Color(0xFF0F766E),
        ),
      ),
      bodyPadding: const EdgeInsets.all(20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Aviso de Comprobación previa ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.25),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 18,
                  color: Color(0xFF0284C7),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Verifica los datos y cantidades antes de emitir, imprimir o compartir la orden.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Tarjeta de Previsualización Documento (A4 Look) ───────────────
          DetailSectionCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera interna del documento
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'INVENTORY STORE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ORDEN DE COMPRA OFICIAL',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '#OC-$_shortCode',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),

                // Metadatos en dos columnas
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PROVEEDOR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.po.supplierName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (widget.po.documentNumber != null &&
                              widget.po.documentNumber!.isNotEmpty)
                            Text(
                              '${widget.po.documentType} ${widget.po.documentNumber}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DESTINO & ESTADO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.po.warehouseName ?? 'Almacén Principal',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildStatusBadge(
                                widget.po.status,
                                isPayment: false,
                              ),
                              _buildStatusBadge(
                                widget.po.paymentStatus,
                                isPayment: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Tabla de Ítems
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PRODUCTOS SOLICITADOS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (_isLoadingItems)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      Text(
                        '${_items.length} ítems',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_isLoadingItems && _items.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_items.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'No se cargaron ítems (${widget.po.itemCount} declarados)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        // Encabezado de tabla
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'Producto',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Cant.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Costo',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Total',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        ...List.generate(_items.length, (index) {
                          final item = _items[index];
                          final isLast = index == _items.length - 1;
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName ?? 'Producto',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (item.variantAttrs.isNotEmpty &&
                                              item.variantAttrs != 'Única')
                                            Text(
                                              item.variantAttrs,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${item.quantityOrdered.toStringAsFixed(0)} un',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'S/ ${item.unitCost.toStringAsFixed(2)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'S/ ${item.subtotal.toStringAsFixed(2)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isLast)
                                const Divider(
                                  height: 1,
                                  color: AppColors.border,
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Resumen de Totales
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        'Subtotal:',
                        'S/ ${(widget.po.totalAmount + widget.po.discountAmount - widget.po.taxAmount).toStringAsFixed(2)}',
                      ),
                      if (widget.po.discountAmount > 0) ...[
                        const SizedBox(height: 4),
                        _buildSummaryRow(
                          'Descuento:',
                          '- S/ ${widget.po.discountAmount.toStringAsFixed(2)}',
                        ),
                      ],
                      if (widget.po.taxAmount > 0) ...[
                        const SizedBox(height: 4),
                        _buildSummaryRow(
                          'Impuestos:',
                          'S/ ${widget.po.taxAmount.toStringAsFixed(2)}',
                        ),
                      ],
                      const SizedBox(height: 6),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 6),
                      _buildSummaryRow(
                        'TOTAL DE LA ORDEN:',
                        'S/ ${widget.po.totalAmount.toStringAsFixed(2)}',
                        isBold: true,
                        fontSize: 14,
                        textColor: AppColors.textPrimary,
                      ),
                      const SizedBox(height: 4),
                      _buildSummaryRow(
                        'Monto Pagado:',
                        'S/ ${widget.po.amountPaid.toStringAsFixed(2)}',
                        textColor: const Color(0xFF16A34A),
                      ),
                      if (widget.po.totalAmount - widget.po.amountPaid > 0) ...[
                        const SizedBox(height: 4),
                        _buildSummaryRow(
                          'Saldo Pendiente:',
                          'S/ ${(widget.po.totalAmount - widget.po.amountPaid).toStringAsFixed(2)}',
                          isBold: true,
                          textColor: const Color(0xFFDC2626),
                        ),
                      ],
                    ],
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
          // Botón Primario: Imprimir Orden A4
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessingAction ? null : _handlePrint,
              icon:
                  _isProcessingAction
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.print_rounded, size: 20),
              label: const Text(
                'IMPRIMIR ORDEN DE COMPRA',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Botones secundarios de exportación y compartición
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessingAction ? null : _handleWhatsApp,
                  icon: const Icon(
                    Icons.chat_bubble_rounded,
                    size: 16,
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
                    padding: const EdgeInsets.symmetric(vertical: 11),
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
                  onPressed: _isProcessingAction ? null : _handleEmail,
                  icon: const Icon(
                    Icons.email_outlined,
                    size: 16,
                    color: Color(0xFFEA580C),
                  ),
                  label: const Text(
                    'Correo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: BorderSide(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.4),
                    ),
                    backgroundColor: const Color(
                      0xFFEA580C,
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
                  onPressed: _isProcessingAction ? null : _handleSavePdf,
                  icon: const Icon(
                    Icons.download_rounded,
                    size: 16,
                    color: Color(0xFFDC2626),
                  ),
                  label: const Text(
                    'Guardar PDF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: BorderSide(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                    ),
                    backgroundColor: const Color(
                      0xFFDC2626,
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
                  onPressed: _handleCopy,
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 16,
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
                    padding: const EdgeInsets.symmetric(vertical: 11),
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

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 12,
    Color? textColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: textColor ?? AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: textColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, {required bool isPayment}) {
    Color bg;
    Color fg;
    String label;

    if (isPayment) {
      switch (status.toUpperCase()) {
        case 'PAID':
          bg = const Color(0xFF16A34A).withValues(alpha: 0.12);
          fg = const Color(0xFF15803D);
          label = 'PAGADO';
          break;
        case 'PARTIAL':
          bg = const Color(0xFFD97706).withValues(alpha: 0.12);
          fg = const Color(0xFFB45309);
          label = 'PAGO PARCIAL';
          break;
        default:
          bg = const Color(0xFFDC2626).withValues(alpha: 0.12);
          fg = const Color(0xFFB91C1C);
          label = 'POR PAGAR';
      }
    } else {
      switch (status.toUpperCase()) {
        case 'RECEIVED':
          bg = const Color(0xFF16A34A).withValues(alpha: 0.12);
          fg = const Color(0xFF15803D);
          label = 'RECIBIDA';
          break;
        case 'PARTIAL':
          bg = const Color(0xFF0284C7).withValues(alpha: 0.12);
          fg = const Color(0xFF0369A1);
          label = 'PARCIAL';
          break;
        case 'CANCELLED':
          bg = const Color(0xFFDC2626).withValues(alpha: 0.12);
          fg = const Color(0xFFB91C1C);
          label = 'CANCELADA';
          break;
        default:
          bg = const Color(0xFFD97706).withValues(alpha: 0.12);
          fg = const Color(0xFFB45309);
          label = 'PENDIENTE';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
