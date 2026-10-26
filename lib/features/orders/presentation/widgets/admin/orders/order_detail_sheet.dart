import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/order_detail/order_detail_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/order_detail/order_detail_state.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_audit_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_batch_sheet.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_bottom_action_bar.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_credit_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_customer_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_editing_banner.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_fiscal_card.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_header_row.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_items_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_metadata_strip.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_payment_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_points_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_skeleton.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_status_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_total_summary_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_quantity_edit_dialog.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_reason_dialog.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_return_confirm_dialog.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/payment_status_section.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_receipt_export_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/open_shift_sheet.dart';

class OrderDetailSheet extends StatelessWidget {
  final OrderEntity order;
  final bool isEmbedded;
  final ValueChanged<bool>? onPop;
  final ValueChanged<OrderEntity>? onOrderUpdated;

  const OrderDetailSheet({
    super.key,
    required this.order,
    this.isEmbedded = false,
    this.onPop,
    this.onOrderUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OrderDetailCubit>(
      create:
          (_) =>
              sl<OrderDetailCubit>()
                ..setInitialOrder(order)
                ..fetchData(order.id),
      child: _OrderDetailSheetContent(
        order: order,
        isEmbedded: isEmbedded,
        onPop: onPop,
        onOrderUpdated: onOrderUpdated,
      ),
    );
  }
}

class _OrderDetailSheetContent extends StatefulWidget {
  final OrderEntity order;
  final bool isEmbedded;
  final ValueChanged<bool>? onPop;
  final ValueChanged<OrderEntity>? onOrderUpdated;

  const _OrderDetailSheetContent({
    required this.order,
    this.isEmbedded = false,
    this.onPop,
    this.onOrderUpdated,
  });

  @override
  State<_OrderDetailSheetContent> createState() =>
      _OrderDetailSheetContentState();
}

class _OrderDetailSheetContentState extends State<_OrderDetailSheetContent> {
  static const String _accountTypeCaja = 'CAJA';
  static const String _accountTypeCredito = 'CREDITO';
  static const String _paymentStatusPaid = 'PAID';

  final TextEditingController _pointsUsedCtrl = TextEditingController();
  final TextEditingController _manualNameCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = false;
    _pointsUsedCtrl.text = '0';
    _manualNameCtrl.text = widget.order.customerName.trim();
  }

  @override
  void dispose() {
    _pointsUsedCtrl.dispose();
    _manualNameCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handlePop([bool result = false]) async {
    if (_isEditing && !result) {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('¿Salir sin guardar?'),
              content: const Text(
                'Tienes cambios sin guardar. ¿Estás seguro de que deseas salir?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Salir'),
                ),
              ],
            ),
      );
      if (confirm != true) return;
    }

    if (!mounted) return;
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
      final updated = context.read<OrderDetailCubit>().state.order;
      if (updated != null) {
        widget.onOrderUpdated?.call(updated);
      }
      AppSnackbar.show(
        context,
        message: 'Cambios guardados correctamente',
        type: SnackbarType.success,
      );
      await _handlePop(true);
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
      final updated = context.read<OrderDetailCubit>().state.order;
      if (updated != null) {
        widget.onOrderUpdated?.call(updated);
      }
      AppSnackbar.show(
        context,
        message: 'Devolución procesada con éxito',
        type: SnackbarType.success,
      );
      await _handlePop(true);
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

  Future<void> _showQuantityDialog(
    BuildContext context,
    int idx,
    double ratio,
    double rate,
  ) async {
    final cubit = context.read<OrderDetailCubit>();
    final currentQty = cubit.state.items[idx].quantity.toString();

    final newQtyStr = await OrderQuantityEditDialog.show(context, currentQty);

    if (!mounted || newQtyStr == null) return;
    final qty = int.tryParse(newQtyStr) ?? 1;
    if (qty > 0) {
      cubit.updateItemQuantity(idx, qty, ratio, rate);
    }
  }

  Future<void> _validateAndSetPaymentMethod(
    String method,
    double ratio,
    double rate,
  ) async {
    final cubit = context.read<OrderDetailCubit>();
    final state = cubit.state;

    final selectedAccount = state.accounts.firstWhere(
      (a) => a['name'] == method,
      orElse: () => <String, dynamic>{},
    );
    final isCashAccount = selectedAccount['type'] == _accountTypeCaja;

    if (isCashAccount) {
      final shiftId = await cubit.getActiveCashShift();
      if (!mounted) return;
      if (shiftId == null) {
        AppSnackbar.show(
          context,
          message:
              'Se requiere un turno de caja abierto para registrar pago en $method',
          type: SnackbarType.warning,
        );

        final cashAccounts =
            state.accounts.where((a) => a['type'] == _accountTypeCaja).toList();
        final opened = await OpenShiftSheet.show(
          context,
          accounts: cashAccounts.isNotEmpty ? cashAccounts : state.accounts,
        );

        if (opened != true) return;
      }
    }

    if (!mounted) return;
    cubit.updatePaymentMethod(method, ratio, rate);
    if (selectedAccount['type'] == _accountTypeCredito) {
      _pointsUsedCtrl.text = '0';
    }
  }

  String _getCustomerLabel(
    String? customerId,
    List<Map<String, dynamic>> profiles,
    OrderEntity? order,
  ) {
    if (customerId != null && customerId.isNotEmpty) {
      try {
        final profile = profiles.firstWhere((p) => p['id'] == customerId);
        final name = (profile['full_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) return name;
      } catch (e, st) {
        LoggerService.w(
          'Error parseando cliente',
          error: e,
          stackTrace: st,
          tag: 'OrderDetailSheet',
        );
      }
    }
    if (order != null &&
        order.displayCustomerName.isNotEmpty &&
        order.displayCustomerName != 'Cliente General') {
      return order.displayCustomerName;
    }
    final manualName = _manualNameCtrl.text.trim();
    return manualName.isNotEmpty ? manualName : 'Cliente mostrador';
  }

  void _toggleEditing(OrderDetailState state) {
    if (_isEditing) {
      context.read<OrderDetailCubit>().resetEditState();
      _pointsUsedCtrl.text = state.pointsUsed.toString();
      _manualNameCtrl.text = (state.order ?? widget.order).customerName.trim();
    }
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigCubit>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final earningRate =
        config.loyaltyGlobalEnabled
            ? config.getDouble('points_earning_rate', 0.03)
            : 0.0;

    return BlocBuilder<OrderDetailCubit, OrderDetailState>(
      buildWhen:
          (p, c) =>
              p.isLoading != c.isLoading ||
              p.isBackgroundLoading != c.isBackgroundLoading ||
              p.hasError != c.hasError ||
              p.items != c.items ||
              p.order != c.order,
      builder: (context, rootState) {
        final displayOrder = rootState.order ?? widget.order;
        final isDesktopOrDialog = MediaQuery.sizeOf(context).width >= 800;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        Widget child = Container(
          height:
              widget.isEmbedded
                  ? null
                  : (isDesktopOrDialog
                      ? double.infinity
                      : MediaQuery.of(context).size.height * 0.9),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(
                isDesktopOrDialog || widget.isEmbedded ? 0 : 24,
              ),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                if (!widget.isEmbedded && !isDesktopOrDialog)
                  const AppSheetDragHandle(
                    padding: EdgeInsets.only(top: 10, bottom: 4),
                  ),
                Expanded(
                  child:
                      (rootState.isLoading && rootState.order == null)
                          ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: OrderDetailSkeleton(),
                          )
                          : (rootState.hasError && rootState.order == null)
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
                                      .fetchData(widget.order.id),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reintentar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          )
                          : ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              if (rootState.isBackgroundLoading)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: const LinearProgressIndicator(
                                      color: AppColors.teal,
                                      backgroundColor: Color(0xFFE2E8F0),
                                      minHeight: 2.5,
                                    ),
                                  ),
                                ),
                              // HEADER
                              if (!widget.isEmbedded) ...[
                                BlocBuilder<OrderDetailCubit, OrderDetailState>(
                                  buildWhen:
                                      (p, c) =>
                                          p.canToggleEdit != c.canToggleEdit ||
                                          p.isCompleted != c.isCompleted ||
                                          p.pointsUsed != c.pointsUsed ||
                                          p.currentStatus != c.currentStatus ||
                                          p.order != c.order,
                                  builder: (context, state) {
                                    return OrderDetailHeaderRow(
                                      orderId: (state.order ?? displayOrder).id,
                                      orderStatus:
                                          (state.order ?? displayOrder).status,
                                      documentType:
                                          (state.order ?? displayOrder)
                                              .documentType,
                                      documentNumber:
                                          (state.order ?? displayOrder)
                                              .documentNumber,
                                      isCompleted: state.isCompleted,
                                      isEditing: _isEditing,
                                      canToggleEdit: state.canToggleEdit,
                                      onToggleEditing:
                                          () => _toggleEditing(state),
                                      onClose:
                                          Navigator.of(context).canPop()
                                              ? () => _handlePop(
                                                _isEditing
                                                    ? false
                                                    : state.wasModified,
                                              )
                                              : null,
                                      onShare:
                                          () => OrderReceiptExportSheet.show(
                                            context,
                                            order: state.order!,
                                            initialItems: state.items,
                                          ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],

                              // RESUMEN COMPACTO (Lectura rápida) O FORMULARIO COMPLETO (Edición)
                              BlocBuilder<OrderDetailCubit, OrderDetailState>(
                                buildWhen:
                                    (p, c) =>
                                        p.currentStatus != c.currentStatus ||
                                        p.order != c.order ||
                                        p.selectedCustomerId !=
                                            c.selectedCustomerId ||
                                        p.profiles != c.profiles ||
                                        p.paymentMethod != c.paymentMethod ||
                                        p.accounts != c.accounts ||
                                        p.canToggleEdit != c.canToggleEdit,
                                builder: (context, state) {
                                  if (!_isEditing) {
                                    final currentOrder =
                                        state.order ?? displayOrder;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        OrderDetailMetadataStrip(
                                          state: state,
                                          displayOrder: displayOrder,
                                          manualCustomerName:
                                              _manualNameCtrl.text,
                                          onToggleEditing:
                                              () => _toggleEditing(state),
                                        ),
                                        OrderDetailFiscalCard(
                                          order: currentOrder,
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (widget.isEmbedded)
                                        OrderDetailEditingBanner(
                                          onCancel: () => _toggleEditing(state),
                                        ),
                                      OrderDetailStatusSection(
                                        originalStatus:
                                            state.order?.status ??
                                            displayOrder.status,
                                        currentStatus: state.currentStatus,
                                        isEditing: _isEditing,
                                        onChanged: (val) {
                                          if (val != null) {
                                            context
                                                .read<OrderDetailCubit>()
                                                .updateStatus(val);
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      OrderDetailCustomerSection(
                                        isEditing: _isEditing,
                                        isCompleted: state.isCompleted,
                                        hasManualName:
                                            _manualNameCtrl.text.isNotEmpty,
                                        manualNameController: _manualNameCtrl,
                                        profiles: state.profiles,
                                        selectedCustomerLabel:
                                            _getCustomerLabel(
                                              state.selectedCustomerId,
                                              state.profiles,
                                              state.order,
                                            ),
                                        selectedCustomerId:
                                            state.selectedCustomerId,
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
                                      const SizedBox(height: 14),
                                      OrderDetailPaymentSection(
                                        isEditing: _isEditing,
                                        isCompleted: state.isCompleted,
                                        accounts: state.accounts,
                                        currentPaymentMethod:
                                            state.paymentMethod,
                                        onChanged: (val) {
                                          if (val != null) {
                                            _validateAndSetPaymentMethod(
                                              val,
                                              pointsToSolesRatio,
                                              earningRate,
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                  );
                                },
                              ),

                              // 1. ITEMS SECTION (Productos del pedido - Primer plano visual)
                              BlocSelector<
                                OrderDetailCubit,
                                OrderDetailState,
                                _ItemsSectionData
                              >(
                                selector:
                                    (state) => _ItemsSectionData(
                                      items: state.items,
                                      isLoading:
                                          state.isLoading ||
                                          (state.isBackgroundLoading &&
                                              state.items.isEmpty),
                                      currentStatus: state.currentStatus,
                                      batchesByVariant: state.batchesByVariant,
                                      usesBatchesMap: state.usesBatchesMap,
                                      batchOverrides: state.batchOverrides,
                                    ),
                                builder: (context, data) {
                                  return OrderDetailItemsSection(
                                    items: data.items,
                                    isLoading: data.isLoading,
                                    isEditing: _isEditing,
                                    isLocked:
                                        data.currentStatus.toUpperCase() !=
                                        'PENDING',
                                    batchesByVariant: data.batchesByVariant,
                                    usesBatchesMap: data.usesBatchesMap,
                                    batchOverrides: data.batchOverrides,
                                    onDecrease: (idx) {
                                      if (data.items[idx].quantity > 1) {
                                        context
                                            .read<OrderDetailCubit>()
                                            .updateItemQuantity(
                                              idx,
                                              data.items[idx].quantity - 1,
                                              pointsToSolesRatio,
                                              earningRate,
                                            );
                                      }
                                    },
                                    onIncrease: (idx) {
                                      context
                                          .read<OrderDetailCubit>()
                                          .updateItemQuantity(
                                            idx,
                                            data.items[idx].quantity + 1,
                                            pointsToSolesRatio,
                                            earningRate,
                                          );
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
                                    onQuantityTap:
                                        (idx) => _showQuantityDialog(
                                          context,
                                          idx,
                                          pointsToSolesRatio,
                                          earningRate,
                                        ),
                                  );
                                },
                              ),

                              // 2. TOTAL SUMMARY SECTION (Desglose financiero)
                              BlocBuilder<OrderDetailCubit, OrderDetailState>(
                                buildWhen:
                                    (p, c) =>
                                        p.order != c.order ||
                                        p.items != c.items ||
                                        p.pointsUsed != c.pointsUsed ||
                                        p.pointsEarned != c.pointsEarned ||
                                        p.isCompleted != c.isCompleted,
                                builder: (context, state) {
                                  final subtotal = state.items.fold(
                                    0.0,
                                    (sum, i) => sum + i.subtotal,
                                  );
                                  final order = state.order ?? displayOrder;
                                  return OrderDetailTotalSummarySection(
                                    subtotal: subtotal,
                                    pointsUsed: state.pointsUsed,
                                    pointsEarned: state.pointsEarned,
                                    pointsToSolesRatio: pointsToSolesRatio,
                                    discountAmount: order.discountAmount,
                                    isCompleted:
                                        state.isCompleted &&
                                        order.paymentStatus ==
                                            _paymentStatusPaid,
                                    isLoyaltyEnabled:
                                        config.loyaltyGlobalEnabled,
                                    taxAmount: order.taxAmount,
                                    subtotalAmount: order.subtotalAmount,
                                    currencySymbol: order.currencySymbol,
                                    currencyCode: order.currencyCode,
                                    exchangeRate: order.exchangeRate,
                                  );
                                },
                              ),

                              // 3. PAYMENT STATUS (Formulario de cobro y abonos si está pendiente)
                              BlocBuilder<OrderDetailCubit, OrderDetailState>(
                                buildWhen:
                                    (p, c) =>
                                        p.order != c.order ||
                                        p.paymentMethod != c.paymentMethod ||
                                        p.accounts != c.accounts ||
                                        p.selectedCustomerId !=
                                            c.selectedCustomerId ||
                                        p.pointsEarned != c.pointsEarned ||
                                        p.creditInfo != c.creditInfo,
                                builder: (context, state) {
                                  final order = state.order ?? displayOrder;
                                  if (order.paymentStatus ==
                                      _paymentStatusPaid) {
                                    return const SizedBox.shrink();
                                  }

                                  return PaymentStatusSection(
                                    orderId: order.id,
                                    paymentStatus: order.paymentStatus,
                                    totalAmount: order.totalAmount,
                                    amountPaid: order.amountPaid,
                                    paymentMethod: state.paymentMethod,
                                    creditInfo: state.creditInfo,
                                    accounts: state.accounts,
                                    customerId: state.selectedCustomerId,
                                    pointsEarned: state.pointsEarned,
                                    onPaymentRegistered: () async {
                                      final cubit =
                                          context.read<OrderDetailCubit>();
                                      cubit.setWasModified();
                                      await cubit.fetchData(widget.order.id);
                                      final updated = cubit.state.order;
                                      if (updated != null) {
                                        widget.onOrderUpdated?.call(updated);
                                      }
                                    },
                                    isLoyaltyEnabled:
                                        config.loyaltyGlobalEnabled,
                                  );
                                },
                              ),

                              // 4. CREDIT SECTION (Línea de crédito si aplica)
                              BlocBuilder<OrderDetailCubit, OrderDetailState>(
                                buildWhen:
                                    (p, c) =>
                                        p.selectedCustomerId !=
                                            c.selectedCustomerId ||
                                        p.creditInfo != c.creditInfo,
                                builder: (context, state) {
                                  if (state.selectedCustomerId != null &&
                                      state.selectedCustomerId!.isNotEmpty &&
                                      state.creditInfo != null) {
                                    return OrderDetailCreditSection(
                                      creditInfo: state.creditInfo!,
                                      customerId: state.selectedCustomerId!,
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),

                              // 5. POINTS SECTION (Programa de fidelización)
                              BlocBuilder<OrderDetailCubit, OrderDetailState>(
                                buildWhen:
                                    (p, c) =>
                                        p.selectedCustomerId !=
                                            c.selectedCustomerId ||
                                        p.paymentMethod != c.paymentMethod ||
                                        p.pointsUsed != c.pointsUsed ||
                                        p.profiles != c.profiles,
                                builder: (context, state) {
                                  final isCreditMethod = state.accounts.any(
                                    (a) =>
                                        a['name'] == state.paymentMethod &&
                                        a['type'] == _accountTypeCredito,
                                  );
                                  final maxPtsUser =
                                      state.selectedCustomerId != null
                                          ? state.profiles.firstWhere(
                                                    (p) =>
                                                        p['id'] ==
                                                        state
                                                            .selectedCustomerId,
                                                    orElse:
                                                        () => {
                                                          'wallet_balance': 0,
                                                        },
                                                  )['wallet_balance']
                                                  as int? ??
                                              0
                                          : 0;

                                  if (config.loyaltyGlobalEnabled &&
                                      state.selectedCustomerId != null &&
                                      state.selectedCustomerId!.isNotEmpty &&
                                      !isCreditMethod) {
                                    return OrderDetailPointsSection(
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
                                              pts,
                                              pointsToSolesRatio,
                                              earningRate,
                                            );
                                      },
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),

                              // 6. AUDIT SECTION (Trazabilidad y autoría)
                              BlocBuilder<OrderDetailCubit, OrderDetailState>(
                                buildWhen:
                                    (p, c) =>
                                        p.updaterName != c.updaterName ||
                                        p.order != c.order,
                                builder: (context, state) {
                                  return OrderDetailAuditSection(
                                    order: state.order ?? displayOrder,
                                    updaterName: state.updaterName,
                                  );
                                },
                              ),
                            ],
                          ),
                ),

                // BOTTOM ACTION BAR
                if (!rootState.isLoading && !rootState.hasError)
                  BlocBuilder<OrderDetailCubit, OrderDetailState>(
                    buildWhen:
                        (p, c) =>
                            p.order != c.order ||
                            p.items != c.items ||
                            p.pointsUsed != c.pointsUsed ||
                            p.isSaving != c.isSaving ||
                            p.isReturning != c.isReturning ||
                            p.isCompleted != c.isCompleted ||
                            p.wasModified != c.wasModified,
                    builder: (context, state) {
                      final subtotal = state.items.fold(
                        0.0,
                        (sum, i) => sum + i.subtotal,
                      );
                      final rawDiscount = state.pointsUsed * pointsToSolesRatio;
                      final maxDiscount = subtotal * 0.5;
                      final appliedDiscount =
                          rawDiscount > maxDiscount ? maxDiscount : rawDiscount;

                      final order = state.order ?? displayOrder;
                      final totalFinal =
                          subtotal - appliedDiscount - order.discountAmount;
                      final actualTotal = totalFinal < 0 ? 0.0 : totalFinal;

                      return OrderDetailBottomActionBar(
                        state: state,
                        order: order,
                        isEditing: _isEditing,
                        actualTotal: actualTotal,
                        onSave: () => _saveChanges(pointsToSolesRatio),
                        onConfirmReturn: _confirmReturn,
                        onToggleEditing: () => _toggleEditing(state),
                        onScrollToPayment: () {
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                        onClose:
                            () async => await _handlePop(state.wasModified),
                      );
                    },
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
          onPopInvokedWithResult: (didPop, dynamic result) async {
            if (didPop) return;
            final state = context.read<OrderDetailCubit>().state;
            if (_isEditing) {
              await _handlePop(false);
            } else {
              await _handlePop(state.wasModified);
            }
          },
          child: child,
        );
      },
    );
  }
}

class _ItemsSectionData {
  final List<OrderItemEntity> items;
  final bool isLoading;
  final String currentStatus;
  final Map<String, List<Map<String, dynamic>>> batchesByVariant;
  final Map<String, bool> usesBatchesMap;
  final Map<String, List<BatchAssignmentModel>> batchOverrides;

  _ItemsSectionData({
    required this.items,
    required this.isLoading,
    required this.currentStatus,
    required this.batchesByVariant,
    required this.usesBatchesMap,
    required this.batchOverrides,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ItemsSectionData &&
        other.items == items &&
        other.isLoading == isLoading &&
        other.currentStatus == currentStatus &&
        other.batchesByVariant == batchesByVariant &&
        other.usesBatchesMap == usesBatchesMap &&
        other.batchOverrides == batchOverrides;
  }

  @override
  int get hashCode => Object.hash(
    items,
    isLoading,
    currentStatus,
    batchesByVariant,
    usesBatchesMap,
    batchOverrides,
  );
}
