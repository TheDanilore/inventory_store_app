import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_item_model.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/detail_sheet_header.dart';
import 'package:inventory_store_app/core/widgets/financial_summary_card.dart';
import 'package:inventory_store_app/core/widgets/product_item_card.dart';

class PODetailSheet extends StatefulWidget {
  final PurchaseOrderModel po;
  final Future<List<PurchaseOrderItemModel>> Function() loadItems;
  final VoidCallback onReceive;
  final Future<void> Function(String) onUpdateStatus;

  const PODetailSheet({
    super.key,
    required this.po,
    required this.loadItems,
    required this.onReceive,
    required this.onUpdateStatus,
  });

  @override
  State<PODetailSheet> createState() => _PODetailSheetState();
}

class _PODetailSheetState extends State<PODetailSheet> {
  List<PurchaseOrderItemModel>? _items;
  bool _isLoadingItems = true;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final items = await widget.loadItems();
      if (mounted) {
        setState(() {
          _items = items;
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingItems = false);
        AppSnackbar.show(
          context,
          message: 'Error al cargar detalles: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _handleUpdateStatus(String newStatus) async {
    if (_isProcessingAction) return;

    setState(() => _isProcessingAction = true);
    try {
      await widget.onUpdateStatus(newStatus);
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Estado actualizado correctamente.',
          type: SnackbarType.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al actualizar: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  /// Confirmación de cancelación con feedback háptico y diálogo.
  Future<void> _confirmCancelOrder() async {
    HapticFeedback.heavyImpact();
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Anular Orden',
      message:
          '¿Estás seguro de que deseas anular esta orden de compra? Esta acción no se puede deshacer.',
      confirmText: 'Sí, anular',
      cancelText: 'Cancelar',
      confirmColor: AppColors.danger,
    );
    if (confirmed == true && mounted) {
      await _handleUpdateStatus('CANCELLED');
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppColors.warning;
      case 'SENT':
        return Colors.blue.shade400;
      case 'PARTIAL':
        return Colors.orange.shade400;
      case 'RECEIVED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pendiente';
      case 'SENT':
        return 'Enviado';
      case 'PARTIAL':
        return 'Parcial';
      case 'RECEIVED':
        return 'Recibido';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header animado compartido ──────────────────────────
              DetailSheetHeader(
                title: 'Detalle de Orden',
                trailing: StatusPill(
                  label: _statusLabel(widget.po.status),
                  color: _statusColor(widget.po.status),
                ),
              ),
              const SizedBox(height: 8),

              // ── Contenido scrolleable ──────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Exportar PDF
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Tooltip(
                            message: 'Exportar orden en PDF',
                            child: TextButton.icon(
                              onPressed:
                                  _isProcessingAction
                                      ? null
                                      : () {
                                        AppSnackbar.show(
                                          context,
                                          message:
                                              'Función de PDF próximamente',
                                          type: SnackbarType.info,
                                        );
                                      },
                              icon: const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              label: const Text(
                                'Exportar PDF',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ── Card Proveedor y Finanzas ──────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Label PROVEEDOR con contraste mejorado
                            const Text(
                              'PROVEEDOR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.po.supplierName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Divider(height: 24, color: AppColors.border),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'MÉTODO DE PAGO',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Text(
                                      widget.po.paymentMethod,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'FECHA EMISIÓN',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(widget.po.createdAt),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // ── Card financiera con animación de conteo ──
                            FinancialSummaryCard(
                              columns: [
                                FinancialColumn(
                                  label: 'TOTAL',
                                  amount: widget.po.totalAmount,
                                  amountColor: AppColors.primary,
                                ),
                                FinancialColumn(
                                  label: 'PAGADO',
                                  amount: widget.po.amountPaid,
                                  amountColor: AppColors.success,
                                ),
                                FinancialColumn(
                                  label: 'DEUDA',
                                  amount: widget.po.pending,
                                  amountColor:
                                      widget.po.pending > 0
                                          ? AppColors.danger
                                          : AppColors.textSecondary,
                                  alignment: CrossAxisAlignment.end,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Lista de Items ─────────────────────────────
                      const Text(
                        'Productos Solicitados',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_isLoadingItems)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 3,
                          itemBuilder:
                              (_, _) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AppShimmer(
                                  width: double.infinity,
                                  height: 76,
                                  borderRadius: 12,
                                ),
                              ),
                        )
                      else if (_items == null || _items!.isEmpty)
                        const Text(
                          'No hay productos en esta orden.',
                          style: TextStyle(color: AppColors.textMuted),
                        )
                      else
                        ...List.generate(_items!.length, (index) {
                          final item = _items![index];
                          final isFullyReceived = item.fullyReceived;
                          final progress =
                              item.quantityOrdered > 0
                                  ? item.quantityReceived / item.quantityOrdered
                                  : 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ProductItemCard(
                              imageUrl: item.imageUrl,
                              productName: item.productName ?? '—',
                              variantLabel: item.variantAttrs,
                              // Progress bar de recepción (Mejora #4)
                              progressWidget: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress.clamp(0.0, 1.0),
                                      backgroundColor: AppColors.border,
                                      color:
                                          isFullyReceived
                                              ? AppColors.success
                                              : AppColors.warning,
                                      minHeight: 4,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Recibido: ${item.quantityReceived.toInt()} / ${item.quantityOrdered.toInt()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isFullyReceived
                                              ? AppColors.success
                                              : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: ItemPriceTrailing(
                                text: 'S/ ${item.subtotal.toStringAsFixed(2)}',
                              ),
                              animationDelay: Duration(
                                milliseconds: 60 * index,
                              ),
                            ),
                          );
                        }),

                      // Espacio para el sticky footer
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Overlay de carga (mejorado: barra en vez de overlay total) ──
          if (_isProcessingAction)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.border,
              ),
            ),

          // ── Sticky Footer con AnimatedSwitcher ────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _StickyFooter(
              status: widget.po.status,
              isProcessing: _isProcessingAction,
              onReceive: widget.onReceive,
              onMarkSent: () => _handleUpdateStatus('SENT'),
              onCancel: _confirmCancelOrder,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky Footer con AnimatedSwitcher
// ─────────────────────────────────────────────────────────────────────────────

class _StickyFooter extends StatelessWidget {
  final String status;
  final bool isProcessing;
  final VoidCallback onReceive;
  final VoidCallback onMarkSent;
  final VoidCallback onCancel;

  const _StickyFooter({
    required this.status,
    required this.isProcessing,
    required this.onReceive,
    required this.onMarkSent,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    // Sin acciones disponibles: no renderizar footer
    final showCancel = status != 'CANCELLED' && status != 'RECEIVED';
    final showReceive = status == 'SENT' || status == 'PARTIAL';
    final showMarkSent = status == 'PENDING';

    if (!showCancel && !showReceive && !showMarkSent) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón de acción primaria con AnimatedSwitcher
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder:
                (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
            child: _buildPrimaryButton(context),
          ),

          // Botón destructivo siempre debajo
          if (showCancel) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: isProcessing ? null : onCancel,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  'Anular Orden',
                  style: TextStyle(
                    color:
                        isProcessing ? AppColors.textMuted : AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context) {
    if (status == 'SENT' || status == 'PARTIAL') {
      return SizedBox(
        key: const ValueKey('receive'),
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.inventory_rounded, size: 20),
          label: const Text(
            'Recepcionar Mercadería',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: isProcessing ? null : onReceive,
        ),
      );
    }

    if (status == 'PENDING') {
      return SizedBox(
        key: const ValueKey('markSent'),
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: isProcessing ? null : onMarkSent,
          child: const Text(
            'Marcar como ENVIADA',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    // RECEIVED o CANCELLED: sin acción primaria
    return const SizedBox.shrink(key: ValueKey('none'));
  }
}
