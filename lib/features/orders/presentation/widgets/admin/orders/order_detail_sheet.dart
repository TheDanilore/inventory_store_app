import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/order_detail/order_detail_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/order_detail/order_detail_state.dart';
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
import 'package:inventory_store_app/features/pos/presentation/widgets/open_shift_sheet.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_reason_dialog.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_return_confirm_dialog.dart';

import 'package:inventory_store_app/core/di/injection_container.dart';

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
    _isEditing = widget.order.status.toUpperCase() == 'PENDING';
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

    final newQtyStr = await showDialog<String>(
      context: context,
      builder: (ctx) => _QuantityEditDialog(initialQty: currentQty),
    );

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

  Widget _buildEditingBanner(OrderDetailState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.tealLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.tealDark),
          const SizedBox(width: 8),
          const Text(
            'Modo Edición',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.tealDark,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _toggleEditing(state),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetadataStrip(
    OrderDetailState state,
    OrderEntity displayOrder,
  ) {
    final selectedCustomerLabel = _getCustomerLabel(
      state.selectedCustomerId,
      state.profiles,
      state.order,
    );
    final isRegistered =
        state.selectedCustomerId != null && state.selectedCustomerId!.isNotEmpty;
    final cleanName = selectedCustomerLabel.trim().isNotEmpty
        ? selectedCustomerLabel.trim()
        : 'Cliente mostrador';
    final parts = cleanName.split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.isNotEmpty
        ? parts.take(2).map((p) => p[0]).join().toUpperCase()
        : '?';

    final order = state.order ?? displayOrder;
    final safePaymentMethod =
        state.paymentMethod.isNotEmpty ? state.paymentMethod : 'POR ACORDAR';
    final isPaid = order.paymentStatus.toUpperCase() == 'PAID';
    final pending = order.totalAmount - order.amountPaid;

    IconData paymentIcon;
    Color paymentColor;
    if (state.accounts.any((a) => a['name'] == safePaymentMethod)) {
      final accType = state.accounts.firstWhere(
        (a) => a['name'] == safePaymentMethod,
        orElse: () => {'type': 'OTRO'},
      )['type'] as String;
      switch (accType) {
        case 'CAJA':
          paymentIcon = Icons.point_of_sale_rounded;
          paymentColor = const Color(0xFFF59E0B);
          break;
        case 'BANCO':
          paymentIcon = Icons.account_balance_rounded;
          paymentColor = const Color(0xFF2563EB);
          break;
        case 'DIGITAL':
          paymentIcon = Icons.smartphone_rounded;
          paymentColor = const Color(0xFF7C3AED);
          break;
        default:
          paymentIcon = Icons.wallet_rounded;
          paymentColor = const Color(0xFF6B7280);
      }
    } else {
      paymentIcon = safePaymentMethod == 'CRÉDITO'
          ? Icons.handshake_rounded
          : Icons.payment_rounded;
      paymentColor =
          safePaymentMethod == 'CRÉDITO' ? AppColors.teal : AppColors.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // --- COLUMNA 1: CLIENTE ---
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isRegistered
                        ? AppColors.teal.withValues(alpha: 0.12)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: isRegistered
                            ? AppColors.tealDark
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cleanName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRegistered ? 'Cliente registrado' : 'Cliente mostrador',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isRegistered
                              ? AppColors.tealDark
                              : AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divisor vertical
          Container(
            width: 1,
            height: 32,
            color: AppColors.border,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),

          // --- COLUMNA 2: PAGO ---
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: paymentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    paymentIcon,
                    size: 17,
                    color: paymentColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        safePaymentMethod,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPaid
                                  ? AppColors.successDark
                                  : AppColors.warningDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isPaid
                                  ? 'Pagado'
                                  : (pending > 0
                                      ? 'Por Cobrar: S/ ${pending.toStringAsFixed(2)}'
                                      : 'Pendiente'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isPaid
                                    ? AppColors.successDark
                                    : AppColors.warningDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

          // --- BOTÓN EDITAR SI ESTÁ PERMITIDO ---
          if (state.canToggleEdit) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.teal),
              tooltip: 'Editar datos del pedido',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.tealLight.withValues(alpha: 0.5),
                padding: const EdgeInsets.all(6),
                minimumSize: const Size(30, 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () => _toggleEditing(state),
            ),
          ],
        ],
      ),
    );
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
          (p, c) => p.isLoading != c.isLoading || p.hasError != c.hasError,
      builder: (context, rootState) {
        // We use widget.order as fallback for the initial render, before state.order is populated.
        final displayOrder = rootState.order ?? widget.order;

        final isDesktopOrDialog = MediaQuery.sizeOf(context).width >= 800;

        Widget child = Container(
          height:
              widget.isEmbedded
                  ? null
                  : (isDesktopOrDialog
                      ? double.infinity
                      : MediaQuery.of(context).size.height * 0.9),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius:
                widget.isEmbedded || isDesktopOrDialog
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                if (!widget.isEmbedded && !isDesktopOrDialog)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                Expanded(
                  child:
                      rootState.isLoading
                          ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: OrderDetailSkeleton(),
                          )
                          : rootState.hasError
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
                              // HEADER
                              if (!widget.isEmbedded) ...[
                                BlocBuilder<OrderDetailCubit, OrderDetailState>(
                                  buildWhen:
                                      (p, c) =>
                                          p.canToggleEdit != c.canToggleEdit ||
                                          p.isCompleted != c.isCompleted ||
                                          p.pointsUsed != c.pointsUsed,
                                  builder: (context, state) {
                                    return OrderDetailHeaderRow(
                                      orderId: state.order!.id,
                                      isCompleted: state.isCompleted,
                                      isEditing: _isEditing,
                                      canToggleEdit: state.canToggleEdit,
                                      onToggleEditing: () => _toggleEditing(state),
                                      onClose: Navigator.of(context).canPop()
                                          ? () => _handlePop(false)
                                          : null,
                                      onShare:
                                          () => OrderPdfGenerator.shareTicket(
                                            state.order!,
                                            items: state.items,
                                            businessName: config.businessName,
                                            taxId: config.businessTaxId,
                                            address: config.businessAddress,
                                            phone: config.businessPhone,
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
                                    return _buildCompactMetadataStrip(
                                      state,
                                      displayOrder,
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (widget.isEmbedded)
                                        _buildEditingBanner(state),
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
                                        selectedCustomerLabel: _getCustomerLabel(
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
                                      isLoading: state.isLoading,
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

                // BOTTOM BAR (TOTAL & BUTTONS)
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

                      return Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x060F172A),
                              blurRadius: 8,
                              offset: Offset(0, -3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Total del Pedido',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: 'S/ ',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.teal,
                                          ),
                                        ),
                                        TextSpan(
                                          text: actualTotal.toStringAsFixed(2),
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.textPrimary,
                                            letterSpacing: -0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (_isEditing)
                              Expanded(
                                flex: 5,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: ElevatedButton(
                                    onPressed:
                                        state.isSaving
                                            ? null
                                            : () =>
                                                _saveChanges(pointsToSolesRatio),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child:
                                        state.isSaving
                                            ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                            : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.save_rounded, size: 17),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Guardar',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                  ),
                                ),
                              )
                            else if (state.isCompleted)
                              Expanded(
                                flex: 5,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        state.isReturning ? null : _confirmReturn,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      backgroundColor: AppColors.error.withValues(alpha: 0.04),
                                      side: BorderSide(
                                        color: AppColors.error.withValues(alpha: 0.35),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 13,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon:
                                        state.isReturning
                                            ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.error,
                                              ),
                                            )
                                            : const Icon(
                                              Icons.assignment_return_rounded,
                                              size: 16,
                                            ),
                                    label: const Text(
                                      'Devolución',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else if (order.paymentStatus != _paymentStatusPaid)
                              Expanded(
                                flex: 5,
                                child: Row(
                                  children: [
                                    if (state.canToggleEdit) ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: AppColors.textSecondary,
                                        ),
                                        tooltip: 'Editar datos del pedido',
                                        style: IconButton.styleFrom(
                                          side: const BorderSide(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () => _toggleEditing(state),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            if (_scrollController.hasClients) {
                                              _scrollController.animateTo(
                                                _scrollController
                                                    .position.maxScrollExtent,
                                                duration: const Duration(
                                                  milliseconds: 320,
                                                ),
                                                curve: Curves.easeOutCubic,
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.teal,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 13,
                                            ),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.payments_rounded,
                                            size: 17,
                                          ),
                                          label: const Text(
                                            'Registrar Pago',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (state.canToggleEdit)
                              Expanded(
                                flex: 5,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _toggleEditing(state),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.tealDark,
                                      side: const BorderSide(
                                        color: Color(0xFFCBD5E1),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 13,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.edit_note_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Editar Pedido',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                flex: 5,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: TextButton(
                                    onPressed:
                                        () async =>
                                            await _handlePop(state.wasModified),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 13,
                                      ),
                                    ),
                                    child: const Text(
                                      'Cerrar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
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
            await _handlePop(state.wasModified);
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

class _QuantityEditDialog extends StatefulWidget {
  final String initialQty;

  const _QuantityEditDialog({required this.initialQty});

  @override
  State<_QuantityEditDialog> createState() => _QuantityEditDialogState();
}

class _QuantityEditDialogState extends State<_QuantityEditDialog> {
  late final TextEditingController _dlgCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _dlgCtrl = TextEditingController(text: widget.initialQty);
  }

  @override
  void dispose() {
    _dlgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Modificar Cantidad',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _dlgCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ingresa la cantidad',
            labelText: 'Cantidad',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Requerido';
            final val = int.tryParse(value.trim());
            if (val == null || val <= 0) return 'Debe ser mayor a 0';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, _dlgCtrl.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
