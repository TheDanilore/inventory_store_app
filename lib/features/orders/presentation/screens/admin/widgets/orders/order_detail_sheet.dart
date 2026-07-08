import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/widgets/batch_edit_sheet.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/order_detail_components/order_detail_skeleton.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inventory_store_app/features/orders/data/models/order_item_model.dart';
import 'package:inventory_store_app/features/orders/data/models/order_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/core/config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:inventory_store_app/features/orders/data/repositories/order_pdf_generator.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/order_detail_components/order_detail_header_row.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/order_detail_components/order_detail_status_section.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/order_detail_components/order_detail_customer_section.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/order_detail_components/order_detail_payment_section.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/order_detail_components/order_detail_total_summary_section.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/order_detail_components/order_detail_items_section.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/order_detail_components/order_detail_points_section.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/order_detail_components/order_detail_credit_section.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/order_detail_components/payment_status_section.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/order_detail_components/order_detail_audit_section.dart';

class OrderDetailSheet extends StatefulWidget {
  final OrderModel order;
  final bool isEmbedded;
  final ValueChanged<bool>? onPop;

  const OrderDetailSheet({
    super.key,
    required this.order,
    this.isEmbedded = false,
    this.onPop,
  });

  @override
  State<OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<OrderDetailSheet> {
  final TextEditingController _pointsUsedCtrl = TextEditingController();
  final TextEditingController _manualNameCtrl = TextEditingController();
  List<TextEditingController> _quantityControllers = [];
  bool _isEditing = false;
  late OrderDetailProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = OrderDetailProvider(widget.order);
    _pointsUsedCtrl.text = _provider.pointsUsed.toString();
    _manualNameCtrl.text = widget.order.displayCustomerName.trim();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.fetchData(_manualNameCtrl.text).then((_) {
        if (mounted) {
          setState(() {
            _quantityControllers =
                _provider.items
                    .map(
                      (item) =>
                          TextEditingController(text: item.quantity.toString()),
                    )
                    .toList();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _pointsUsedCtrl.dispose();
    _manualNameCtrl.dispose();
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    _provider.dispose();
    super.dispose();
  }

  void _handlePop([bool result = false]) {
    if (widget.isEmbedded) {
      widget.onPop?.call(result);
    } else {
      Navigator.pop(context, result);
    }
  }

  Future<void> _showBatchEditSheet(OrderItemModel item) async {
    final warehouseId = _provider.order.warehouseId;
    if (warehouseId == null) return;

    List<BatchAssignmentModel> batches;
    try {
      batches = await _provider.fetchAvailableBatches(
        item.variantId ?? '',
        warehouseId,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Error cargando lotes: $e',
        type: SnackbarType.error,
      );
      return;
    }

    if (batches.isEmpty) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'No hay lotes con stock para este producto.',
        type: SnackbarType.warning,
      );
      return;
    }

    final saved = _provider.batchOverrides[item.id ?? ''];
    if (saved != null) {
      for (final s in saved) {
        final idx = batches.indexWhere((b) => b.batchId == s.batchId);
        if (idx >= 0) batches[idx].assigned = s.assigned;
      }
    } else {
      int remaining = item.quantity;
      for (final b in batches) {
        if (remaining <= 0) break;
        b.assigned = (remaining > b.available) ? b.available : remaining;
        remaining -= b.assigned;
      }
    }

    if (!mounted) return;
    final result = await showModalBottomSheet<List<BatchAssignmentModel>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => BatchEditSheet(
            productName: item.productName ?? 'Producto',
            variantLabel: item.variantLabel,
            totalRequired: item.quantity,
            batches: batches,
          ),
    );

    if (result != null && mounted) {
      _provider.updateBatchOverrides(item.id ?? '', result);
    }
  }

  Future<String?> _showReasonDialog(String title, String hint) async {
    String notes = '';
    return showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hint, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 3,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText:
                        'Ej. Producto dañado, cliente cambió de opinión...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (val) => notes = val,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, notes),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continuar'),
              ),
            ],
          ),
    );
  }

  void _showStockErrorDialog(List<String> messages) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              'Stock Insuficiente',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'El stock varió y ya no hay disponibilidad para completar este pedido:\n\n${messages.join('\n')}',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }

  Future<void> _saveChanges(double pointsToSolesRatio) async {
    final isNowCancelled = _provider.currentStatus.toUpperCase() == 'CANCELLED';
    String? notesOverride;

    if (isNowCancelled) {
      notesOverride = await _showReasonDialog(
        'Cancelar Pedido',
        'Ingresa el motivo de la cancelación:',
      );
      if (notesOverride == null) return;
    }

    final result = await _provider.saveChanges(
      notesOverride: notesOverride,
      manualCustomerName: _manualNameCtrl.text,
      pointsToSolesRatio: pointsToSolesRatio,
    );

    if (!mounted) return;

    if (result.success) {
      AppSnackbar.show(
        context,
        message: 'Cambios guardados correctamente',
        type: SnackbarType.success,
      );
      _handlePop(true);
    } else if (result.stockError) {
      _showStockErrorDialog(result.stockMessages);
    } else {
      AppSnackbar.show(
        context,
        message: result.errorMessage ?? 'Error desconocido',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _processReturn(String? notes) async {
    final result = await _provider.processReturn(notes);
    if (!mounted) return;
    if (result.success) {
      AppSnackbar.show(
        context,
        message: 'Devolución procesada con éxito',
        type: SnackbarType.success,
      );
      _handlePop(true);
    } else {
      AppSnackbar.show(
        context,
        message: result.errorMessage ?? 'Error procesando devolución',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _confirmReturn() async {
    final notes = await _showReasonDialog(
      'Registrar Devolución',
      'Ingresa el motivo de la devolución:',
    );
    if (notes == null) return;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.assignment_return_rounded,
                  color: Colors.red.shade600,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Confirmar Devolución',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              'Esta acción cancelará el pedido y revertirá todos los movimientos asociados:\n\n'
              '• Stock de productos devuelto al almacén\n'
              '• Monedas de fidelidad revertidas\n'
              '• Deuda de crédito o cuenta ajustada\n\n'
              '¿Deseas continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.assignment_return_rounded, size: 18),
                label: const Text('Confirmar'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      await _processReturn(notes.isNotEmpty ? notes : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigCubit>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final earningRate = config.getDouble('points_earning_rate', 0.03);

    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<OrderDetailProvider>(
        builder: (context, provider, _) {
          final isEditing = provider.canToggleEdit;
          final isCompleted = provider.isCompleted;
          final maxPtsUser =
              provider.selectedCustomerId != null
                  ? provider.profiles.firstWhere(
                            (p) => p['id'] == provider.selectedCustomerId,
                            orElse: () => {'wallet_balance': 0},
                          )['wallet_balance']
                          as int? ??
                      0
                  : 0;

          final subtotal = provider.items.fold(
            0.0,
            (sum, i) => sum + i.subtotal,
          );

          final rawDiscount = provider.pointsUsed * pointsToSolesRatio;
          final maxDiscount = subtotal * 0.5;
          final appliedDiscount =
              rawDiscount > maxDiscount ? maxDiscount : rawDiscount;
          final totalFinal =
              subtotal - appliedDiscount - provider.order.discountAmount;
          final actualTotal = totalFinal < 0 ? 0.0 : totalFinal;

          List<Map<String, dynamic>> profiles = provider.profiles;

          String getCustomerLabel(String? customerId) {
            if (customerId == null) {
              final manualName = _manualNameCtrl.text.trim();
              return manualName.isNotEmpty ? manualName : 'Cliente mostrador';
            }
            try {
              final profile = provider.profiles.firstWhere(
                (p) => p['id'] == customerId,
              );
              final name = (profile['full_name'] as String?)?.trim();
              if (name != null && name.isNotEmpty) return name;
            } catch (_) {}
            return provider.order.displayCustomerName.isNotEmpty
                ? provider.order.displayCustomerName
                : 'Cliente mostrador';
          }

          Widget child = Container(
            height:
                widget.isEmbedded
                    ? null
                    : MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color:
                  widget.isEmbedded ? Colors.transparent : Colors.grey.shade50,
              borderRadius:
                  widget.isEmbedded
                      ? BorderRadius.zero
                      : const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  if (!widget.isEmbedded)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 5),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  Expanded(
                    child:
                        provider.isLoading
                            ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: OrderDetailSkeleton(),
                            )
                            : provider.hasError
                            ? AppEmptyState(
                              icon: Icons.error_outline_rounded,
                              color: Colors.red,
                              title: 'Ocurrió un error al cargar el pedido',
                              message:
                                  'Verifica tu conexión a internet o intenta nuevamente.',
                              action: ElevatedButton.icon(
                                onPressed:
                                    () => provider.fetchData(
                                      _manualNameCtrl.text,
                                    ),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Reintentar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.teal,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            )
                            : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              children: [
                                OrderDetailHeaderRow(
                                  orderId: provider.order.id,
                                  isCompleted: isCompleted,
                                  isEditing: _isEditing,
                                  canToggleEdit: provider.canToggleEdit,
                                  onToggleEditing: () {
                                    if (_isEditing) {
                                      provider.resetEditState();
                                      _pointsUsedCtrl.text =
                                          provider.pointsUsed.toString();
                                      _manualNameCtrl.text =
                                          provider.order.displayCustomerName
                                              .trim();
                                    }
                                    setState(() {
                                      _isEditing = !_isEditing;
                                    });
                                  },
                                  onShare:
                                      () => OrderPdfGenerator.shareTicket(
                                        provider.order,
                                        items: provider.items,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                OrderDetailStatusSection(
                                  originalStatus: provider.order.status,
                                  currentStatus: provider.currentStatus,
                                  isEditing: false, // Siempre en modo lectura
                                  onChanged: (val) {
                                    if (val != null) {
                                      provider.updateStatus(val);
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                OrderDetailCustomerSection(
                                  isEditing: _isEditing,
                                  isCompleted: isCompleted,
                                  hasManualName:
                                      _manualNameCtrl.text.isNotEmpty,
                                  manualNameController: _manualNameCtrl,
                                  profiles: profiles,
                                  selectedCustomerLabel: getCustomerLabel(
                                    provider.selectedCustomerId,
                                  ),
                                  selectedCustomerId:
                                      provider.selectedCustomerId,
                                  onSelectCustomer: (id) {
                                    provider.selectCustomer(
                                      id,
                                      pointsToSolesRatio,
                                      earningRate,
                                    );
                                  },
                                  onClearCustomer: () {
                                    provider.selectCustomer(
                                      null,
                                      pointsToSolesRatio,
                                      earningRate,
                                    );
                                    _manualNameCtrl.text = '';
                                  },
                                ),
                                const SizedBox(height: 16),
                                OrderDetailPaymentSection(
                                  isEditing: _isEditing,
                                  isCompleted: isCompleted,
                                  accounts: provider.accounts,
                                  currentPaymentMethod: provider.paymentMethod,
                                  onChanged: (val) {
                                    if (val != null) {
                                      provider.updatePaymentMethod(
                                        val,
                                        pointsToSolesRatio,
                                        earningRate,
                                      );
                                      if (val == 'CRÉDITO') {
                                        _pointsUsedCtrl.text = '0';
                                      }
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                if (provider.order.paymentStatus != 'PAID')
                                  PaymentStatusSection(
                                    orderId: provider.order.id,
                                    paymentStatus: provider.order.paymentStatus,
                                    totalAmount: provider.order.totalAmount,
                                    amountPaid: provider.order.amountPaid,
                                    paymentMethod: provider.paymentMethod,
                                    creditInfo: provider.creditInfo,
                                    supabase: Supabase.instance.client,
                                    accounts: provider.accounts,
                                    customerId: provider.selectedCustomerId,
                                    pointsEarned: provider.pointsEarned,
                                    onPaymentRegistered: () {
                                      provider.wasModified = true;
                                      provider.fetchData(_manualNameCtrl.text);
                                    },
                                    isLoyaltyEnabled:
                                        config.loyaltyGlobalEnabled,
                                  ),
                                const SizedBox(height: 16),
                                if (provider.selectedCustomerId != null &&
                                    provider.selectedCustomerId!.isNotEmpty &&
                                    provider.creditInfo != null) ...[
                                  OrderDetailCreditSection(
                                    creditInfo: provider.creditInfo!,
                                    customerId: provider.selectedCustomerId!,
                                  ),
                                ],
                                const SizedBox(height: 16),
                                OrderDetailItemsSection(
                                  items: provider.items,
                                  isLoading: provider.isLoading,
                                  isEditing: _isEditing,
                                  isLocked:
                                      provider.currentStatus.toUpperCase() !=
                                      'PENDING',
                                  batchesByVariant: provider.batchesByVariant,
                                  usesBatchesMap: provider.usesBatchesMap,
                                  batchOverrides: provider.batchOverrides,
                                  quantityControllers: _quantityControllers,
                                  onDecrease: (idx) {
                                    if (provider.items[idx].quantity > 1) {
                                      provider.updateItemQuantity(
                                        idx,
                                        provider.items[idx].quantity - 1,
                                        pointsToSolesRatio,
                                        earningRate,
                                      );
                                      _quantityControllers[idx].text =
                                          provider.items[idx].quantity
                                              .toString();
                                    }
                                  },
                                  onIncrease: (idx) {
                                    provider.updateItemQuantity(
                                      idx,
                                      provider.items[idx].quantity + 1,
                                      pointsToSolesRatio,
                                      earningRate,
                                    );
                                    _quantityControllers[idx].text =
                                        provider.items[idx].quantity.toString();
                                  },
                                  onQuantityChanged: (idx, val) {
                                    final qty = int.tryParse(val) ?? 1;
                                    if (qty > 0) {
                                      provider.updateItemQuantity(
                                        idx,
                                        qty,
                                        pointsToSolesRatio,
                                        earningRate,
                                      );
                                    }
                                  },
                                  onEditBatches:
                                      (item) => _showBatchEditSheet(item),
                                ),
                                const SizedBox(height: 16),
                                if (config.loyaltyGlobalEnabled &&
                                    provider.selectedCustomerId != null &&
                                    provider.selectedCustomerId!.isNotEmpty &&
                                    provider.paymentMethod != 'CRÉDITO') ...[
                                  OrderDetailPointsSection(
                                    isEditing: _isEditing,
                                    pointsUsed: provider.pointsUsed,
                                    pointsUsedCtrl: _pointsUsedCtrl,
                                    maxPointsAvailable: maxPtsUser,
                                    pointsToSolesRatio: pointsToSolesRatio,
                                    onPointsChanged: (val) {
                                      final pts = int.tryParse(val) ?? 0;
                                      provider.updatePointsUsed(
                                        pts <= maxPtsUser ? pts : maxPtsUser,
                                        pointsToSolesRatio,
                                        earningRate,
                                      );
                                      if (pts > maxPtsUser) {
                                        _pointsUsedCtrl.text =
                                            maxPtsUser.toString();
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                OrderDetailAuditSection(
                                  order: provider.order,
                                  updaterName: provider.updaterName,
                                ),
                                const SizedBox(height: 16),
                                OrderDetailTotalSummarySection(
                                  subtotal: subtotal,
                                  pointsUsed: provider.pointsUsed,
                                  pointsEarned: provider.pointsEarned,
                                  pointsToSolesRatio: pointsToSolesRatio,
                                  discountAmount: provider.order.discountAmount,
                                  isCompleted:
                                      isCompleted &&
                                      provider.order.paymentStatus == 'PAID',
                                  isLoyaltyEnabled: config.loyaltyGlobalEnabled,
                                ),
                              ],
                            ),
                  ),
                  if (!provider.isLoading && !provider.hasError)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'S/ ${actualTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (isEditing)
                            Expanded(
                              flex: 5,
                              child: ElevatedButton(
                                onPressed:
                                    provider.isSaving
                                        ? null
                                        : () =>
                                            _saveChanges(pointsToSolesRatio),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child:
                                    provider.isSaving
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Text(
                                          'Guardar',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                              ),
                            )
                          else if (isCompleted)
                            Expanded(
                              flex: 5,
                              child: ElevatedButton.icon(
                                onPressed:
                                    provider.isReturning
                                        ? null
                                        : _confirmReturn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                  foregroundColor: Colors.red.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                ),
                                icon:
                                    provider.isReturning
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.red,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.assignment_return_rounded,
                                        ),
                                label: const Text(
                                  'Devolución',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              flex: 5,
                              child: TextButton(
                                onPressed:
                                    () => _handlePop(provider.wasModified),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text(
                                  'Cerrar',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );

          if (widget.isEmbedded) {
            return child;
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, dynamic result) {
              if (didPop) return;
              _handlePop(provider.wasModified);
            },
            child: child,
          );
        },
      ),
    );
  }
}
