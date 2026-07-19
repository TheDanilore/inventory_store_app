import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/order_detail_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/order_detail_state.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_audit_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_credit_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_customer_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_header_row.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_items_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_payment_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_points_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_skeleton.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_status_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_total_summary_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/payment_status_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_batch_sheet.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_reason_dialog.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_return_confirm_dialog.dart';

class OrderDetailSheet extends StatefulWidget {
  final OrderEntity order;
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

  @override
  void initState() {
    super.initState();
    context.read<OrderDetailCubit>().setInitialOrder(widget.order);
    _pointsUsedCtrl.text =
        context.read<OrderDetailCubit>().state.pointsUsed.toString();
    _manualNameCtrl.text = widget.order.customerName.trim();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderDetailCubit>().fetchData(_manualNameCtrl.text).then((
        _,
      ) {
        if (mounted) {
          final state = context.read<OrderDetailCubit>().state;
          setState(() {
            _quantityControllers =
                state.items
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
    super.dispose();
  }

  void _handlePop([bool result = false]) {
    if (widget.isEmbedded) {
      widget.onPop?.call(result);
    } else {
      Navigator.pop(context, result);
    }
  }

  Future<void> _saveChanges(double pointsToSolesRatio) async {
    final state = context.read<OrderDetailCubit>().state;
    final isNowCancelled = state.currentStatus.toUpperCase() == 'CANCELLED';
    String? notesOverride;

    if (isNowCancelled) {
      notesOverride = await OrderReasonDialog.show(
        context,
        title: 'Cancelar Pedido',
        hint: 'Ingresa el motivo de la cancelación:',
      );
      if (notesOverride == null) return;
    }

    if (!mounted) return;

    final result = await context.read<OrderDetailCubit>().saveChanges(
      notesOverride: notesOverride,
      manualCustomerName: _manualNameCtrl.text,
      pointsToSolesRatio: pointsToSolesRatio,
    );

    if (!mounted) return;

    if (result) {
      AppSnackbar.show(
        context,
        message: 'Cambios guardados correctamente',
        type: SnackbarType.success,
      );
      _handlePop(true);
    } else {
      AppSnackbar.show(
        context,
        message:
            context.read<OrderDetailCubit>().state.errorMessage ??
            'Error desconocido',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _processReturn(String? notes) async {
    final result = await context.read<OrderDetailCubit>().processReturn(notes);
    if (!mounted) return;
    if (result) {
      AppSnackbar.show(
        context,
        message: 'Devolución procesada con éxito',
        type: SnackbarType.success,
      );
      _handlePop(true);
    } else {
      AppSnackbar.show(
        context,
        message:
            context.read<OrderDetailCubit>().state.errorMessage ??
            'Error procesando devolución',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _confirmReturn() async {
    final notes = await OrderReasonDialog.show(
      context,
      title: 'Registrar Devolución',
      hint: 'Ingresa el motivo de la devolución:',
    );
    if (notes == null) return;
    if (!mounted) return;

    final confirmed = await OrderReturnConfirmDialog.show(context);
    if (confirmed == true && mounted) {
      await _processReturn(notes.isNotEmpty ? notes : null);
    }
  }

  String _getCustomerLabel(
    String? customerId,
    List<Map<String, dynamic>> profiles,
    OrderEntity? order,
  ) {
    if (customerId == null) {
      final manualName = _manualNameCtrl.text.trim();
      return manualName.isNotEmpty ? manualName : 'Cliente mostrador';
    }
    try {
      final profile = profiles.firstWhere((p) => p['id'] == customerId);
      final name = (profile['full_name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return order?.customerName.isNotEmpty == true
        ? order!.customerName
        : 'Cliente mostrador';
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigCubit>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final earningRate = config.getDouble('points_earning_rate', 0.03);

    return BlocBuilder<OrderDetailCubit, OrderDetailState>(
      builder: (context, state) {
        if (state.order == null) return const SizedBox.shrink();

        final isEditing = state.canToggleEdit;
        final isCompleted = state.isCompleted;
        final maxPtsUser =
            state.selectedCustomerId != null
                ? state.profiles.firstWhere(
                          (p) => p['id'] == state.selectedCustomerId,
                          orElse: () => {'wallet_balance': 0},
                        )['wallet_balance']
                        as int? ??
                    0
                : 0;

        final subtotal = state.items.fold(0.0, (sum, i) => sum + i.subtotal);

        final rawDiscount = state.pointsUsed * pointsToSolesRatio;
        final maxDiscount = subtotal * 0.5;
        final appliedDiscount =
            rawDiscount > maxDiscount ? maxDiscount : rawDiscount;
        final totalFinal =
            subtotal - appliedDiscount - state.order!.discountAmount;
        final actualTotal = totalFinal < 0 ? 0.0 : totalFinal;

        Widget child = Container(
          height:
              widget.isEmbedded
                  ? null
                  : MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: widget.isEmbedded ? Colors.transparent : Colors.grey.shade50,
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
                      state.isLoading
                          ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: OrderDetailSkeleton(),
                          )
                          : state.hasError
                          ? AppEmptyState(
                            icon: Icons.error_outline_rounded,
                            color: Colors.red,
                            title: 'Ocurrió un error al cargar el pedido',
                            message:
                                'Verifica tu conexión a internet o intenta nuevamente.',
                            action: ElevatedButton.icon(
                              onPressed:
                                  () => context
                                      .read<OrderDetailCubit>()
                                      .fetchData(_manualNameCtrl.text),
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
                                orderId: state.order!.id,
                                isCompleted: isCompleted,
                                isEditing: _isEditing,
                                canToggleEdit: state.canToggleEdit,
                                onToggleEditing: () {
                                  if (_isEditing) {
                                    context
                                        .read<OrderDetailCubit>()
                                        .resetEditState();
                                    _pointsUsedCtrl.text =
                                        state.pointsUsed.toString();
                                    _manualNameCtrl.text =
                                        state.order!.customerName.trim();
                                  }
                                  setState(() {
                                    _isEditing = !_isEditing;
                                  });
                                },
                                onShare:
                                    () => OrderPdfGenerator.shareTicket(
                                      state.order!,
                                      items: state.items,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              OrderDetailStatusSection(
                                originalStatus: state.order!.status,
                                currentStatus: state.currentStatus,
                                isEditing: false, // Siempre en modo lectura
                                onChanged: (val) {
                                  if (val != null) {
                                    context
                                        .read<OrderDetailCubit>()
                                        .updateStatus(val);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              OrderDetailCustomerSection(
                                isEditing: _isEditing,
                                isCompleted: isCompleted,
                                hasManualName: _manualNameCtrl.text.isNotEmpty,
                                manualNameController: _manualNameCtrl,
                                profiles: state.profiles,
                                selectedCustomerLabel: _getCustomerLabel(
                                  state.selectedCustomerId,
                                  state.profiles,
                                  state.order,
                                ),
                                selectedCustomerId: state.selectedCustomerId,
                                onSelectCustomer: (id) {
                                  context
                                      .read<OrderDetailCubit>()
                                      .selectCustomer(
                                        id,
                                        pointsToSolesRatio,
                                        earningRate,
                                      );
                                },
                                onClearCustomer: () {
                                  context
                                      .read<OrderDetailCubit>()
                                      .selectCustomer(
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
                                accounts: state.accounts,
                                currentPaymentMethod: state.paymentMethod,
                                onChanged: (val) {
                                  if (val != null) {
                                    context
                                        .read<OrderDetailCubit>()
                                        .updatePaymentMethod(
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
                              if (state.order!.paymentStatus != 'PAID')
                                PaymentStatusSection(
                                  orderId: state.order!.id,
                                  paymentStatus: state.order!.paymentStatus,
                                  totalAmount: state.order!.totalAmount,
                                  amountPaid: state.order!.amountPaid,
                                  paymentMethod: state.paymentMethod,
                                  creditInfo: state.creditInfo,
                                  supabase: Supabase.instance.client,
                                  accounts: state.accounts,
                                  customerId: state.selectedCustomerId,
                                  pointsEarned: state.pointsEarned,
                                  onPaymentRegistered: () {
                                    context
                                        .read<OrderDetailCubit>()
                                        .setWasModified();
                                    context.read<OrderDetailCubit>().fetchData(
                                      _manualNameCtrl.text,
                                    );
                                  },
                                  isLoyaltyEnabled: config.loyaltyGlobalEnabled,
                                ),
                              const SizedBox(height: 16),
                              if (state.selectedCustomerId != null &&
                                  state.selectedCustomerId!.isNotEmpty &&
                                  state.creditInfo != null) ...[
                                OrderDetailCreditSection(
                                  creditInfo: state.creditInfo!,
                                  customerId: state.selectedCustomerId!,
                                ),
                              ],
                              const SizedBox(height: 16),
                              OrderDetailItemsSection(
                                items: state.items,
                                isLoading: state.isLoading,
                                isEditing: _isEditing,
                                isLocked:
                                    state.currentStatus.toUpperCase() !=
                                    'PENDING',
                                batchesByVariant: state.batchesByVariant,
                                usesBatchesMap: state.usesBatchesMap,
                                batchOverrides: state.batchOverrides,
                                quantityControllers: _quantityControllers,
                                onDecrease: (idx) {
                                  if (state.items[idx].quantity > 1) {
                                    context
                                        .read<OrderDetailCubit>()
                                        .updateItemQuantity(
                                          idx,
                                          state.items[idx].quantity - 1,
                                          pointsToSolesRatio,
                                          earningRate,
                                        );
                                    _quantityControllers[idx].text =
                                        state.items[idx].quantity.toString();
                                  }
                                },
                                onIncrease: (idx) {
                                  context
                                      .read<OrderDetailCubit>()
                                      .updateItemQuantity(
                                        idx,
                                        state.items[idx].quantity + 1,
                                        pointsToSolesRatio,
                                        earningRate,
                                      );
                                  _quantityControllers[idx].text =
                                      state.items[idx].quantity.toString();
                                },
                                onQuantityChanged: (idx, val) {
                                  final qty = int.tryParse(val) ?? 1;
                                  if (qty > 0) {
                                    context
                                        .read<OrderDetailCubit>()
                                        .updateItemQuantity(
                                          idx,
                                          qty,
                                          pointsToSolesRatio,
                                          earningRate,
                                        );
                                  }
                                },
                                onEditBatches:
                                    (item) => OrderDetailBatchSheet.show(
                                      context,
                                      item,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              if (config.loyaltyGlobalEnabled &&
                                  state.selectedCustomerId != null &&
                                  state.selectedCustomerId!.isNotEmpty &&
                                  state.paymentMethod != 'CRÉDITO') ...[
                                OrderDetailPointsSection(
                                  isEditing: _isEditing,
                                  pointsUsed: state.pointsUsed,
                                  pointsUsedCtrl: _pointsUsedCtrl,
                                  maxPointsAvailable: maxPtsUser,
                                  pointsToSolesRatio: pointsToSolesRatio,
                                  onPointsChanged: (val) {
                                    final pts = int.tryParse(val) ?? 0;
                                    context
                                        .read<OrderDetailCubit>()
                                        .updatePointsUsed(
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
                                order: state.order!,
                                updaterName: state.updaterName,
                              ),
                              const SizedBox(height: 16),
                              OrderDetailTotalSummarySection(
                                subtotal: subtotal,
                                pointsUsed: state.pointsUsed,
                                pointsEarned: state.pointsEarned,
                                pointsToSolesRatio: pointsToSolesRatio,
                                discountAmount: state.order!.discountAmount,
                                isCompleted:
                                    isCompleted &&
                                    state.order!.paymentStatus == 'PAID',
                                isLoyaltyEnabled: config.loyaltyGlobalEnabled,
                              ),
                            ],
                          ),
                ),
                if (!state.isLoading && !state.hasError)
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
                                  state.isSaving
                                      ? null
                                      : () => _saveChanges(pointsToSolesRatio),
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
                                  state.isSaving
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
                                  state.isReturning ? null : _confirmReturn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                                foregroundColor: Colors.red.shade700,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.red.shade200),
                                ),
                              ),
                              icon:
                                  state.isReturning
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
                              onPressed: () => _handlePop(state.wasModified),
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
            _handlePop(state.wasModified);
          },
          child: child,
        );
      },
    );
  }
}
