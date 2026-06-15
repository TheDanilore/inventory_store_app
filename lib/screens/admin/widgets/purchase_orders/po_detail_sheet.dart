import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/purchase_order_model.dart';
import 'package:inventory_store_app/models/purchase_order_item_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

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
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Detalle de Orden',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    _Pill(
                      icon: Icons.circle,
                      label: _statusLabel(widget.po.status),
                      color: _statusColor(widget.po.status),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Acciones Adicionales (PDF, etc.)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed:
                                _isProcessingAction
                                    ? null
                                    : () {
                                      AppSnackbar.show(
                                        context,
                                        message: 'Función de PDF próximamente',
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
                        ],
                      ),

                      // Card Proveedor y Finanzas
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PROVEEDOR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textHint,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.po.supplierName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
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
                                        color: AppColors.textHint,
                                      ),
                                    ),
                                    Text(
                                      widget.po.paymentMethod,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
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
                                        color: AppColors.textHint,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(widget.po.createdAt),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'TOTAL',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                      Text(
                                        'S/ ${widget.po.totalAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'PAGADO',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                      Text(
                                        'S/ ${widget.po.amountPaid.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'DEUDA',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                      Text(
                                        'S/ ${widget.po.pending.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color:
                                              widget.po.pending > 0
                                                  ? AppColors.danger
                                                  : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Lista de Items
                      const Text(
                        'Productos Solicitados',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
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
                          'No hay productos',
                          style: TextStyle(color: AppColors.textMuted),
                        )
                      else
                        ..._items!.map(
                          (item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                // Miniatura
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child:
                                      item.imageUrl != null
                                          ? CachedNetworkImage(
                                            imageUrl: item.imageUrl!,
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 104,
                                            placeholder:
                                                (_, _) => AppShimmer(
                                                  width: 52,
                                                  height: 52,
                                                  borderRadius: 8,
                                                ),
                                            errorWidget:
                                                (_, _, _) =>
                                                    const _ImagePlaceholder(),
                                          )
                                          : const _ImagePlaceholder(),
                                ),
                                const SizedBox(width: 12),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName ?? '—',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.variantAttrs != 'Única')
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            item.variantAttrs,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Recibido: ${item.quantityReceived.toInt()} / ${item.quantityOrdered.toInt()}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              item.fullyReceived
                                                  ? AppColors.success
                                                  : AppColors.warning,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'S/ ${item.subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Acciones Administrativas
                      if (widget.po.status == 'PENDING') ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                _isProcessingAction
                                    ? null
                                    : () => _handleUpdateStatus('SENT'),
                            child: const Text(
                              'Marcar como ENVIADA',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (widget.po.status == 'SENT' ||
                          widget.po.status == 'PARTIAL') ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.inventory_rounded, size: 20),
                            label: const Text(
                              'Recepcionar Mercadería',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                _isProcessingAction ? null : widget.onReceive,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (widget.po.status != 'CANCELLED' &&
                          widget.po.status != 'RECEIVED')
                        Center(
                          child: TextButton(
                            onPressed:
                                _isProcessingAction
                                    ? null
                                    : () => _handleUpdateStatus('CANCELLED'),
                            child: const Text(
                              'Anular Orden',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_isProcessingAction)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();
  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(
      Icons.image_not_supported_outlined,
      size: 22,
      color: AppColors.textHint,
    ),
  );
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _Pill({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
