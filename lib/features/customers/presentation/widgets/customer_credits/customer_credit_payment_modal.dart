import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/register_payment/register_payment_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/register_payment/register_payment_state.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';

class CustomerCreditPaymentModal extends StatelessWidget {
  final VoidCallback onSaved;
  final CustomerCreditEntity account;
  final Future<void> Function(
    double amount,
    String? accountId,
    String? orderId,
    String? notes,
  )
  onSavePayment;

  const CustomerCreditPaymentModal({
    super.key,
    required this.onSaved,
    required this.account,
    required this.onSavePayment,
  });

  static Future<bool?> show(
    BuildContext context, {
    required CustomerCreditEntity account,
    required VoidCallback onSaved,
    required Future<void> Function(
      double amount,
      String? accountId,
      String? orderId,
      String? notes,
    )
    onSavePayment,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (_) => CustomerCreditPaymentModal(
              account: account,
              onSaved: onSaved,
              onSavePayment: onSavePayment,
            ),
      );
    } else {
      return showDialog<bool>(
        context: context,
        builder:
            (_) => CustomerCreditPaymentModal(
              account: account,
              onSaved: onSaved,
              onSavePayment: onSavePayment,
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) =>
              GetIt.I<RegisterPaymentCubit>()
                ..loadInitialData(account.profileId),
      child: _RegisterPaymentModalView(
        account: account,
        onSaved: onSaved,
        onSavePayment: onSavePayment,
      ),
    );
  }
}

class _RegisterPaymentModalView extends StatefulWidget {
  final VoidCallback onSaved;
  final CustomerCreditEntity account;
  final Future<void> Function(
    double amount,
    String? accountId,
    String? orderId,
    String? notes,
  )
  onSavePayment;

  const _RegisterPaymentModalView({
    required this.onSaved,
    required this.account,
    required this.onSavePayment,
  });

  @override
  State<_RegisterPaymentModalView> createState() =>
      _RegisterPaymentModalViewState();
}

class _RegisterPaymentModalViewState extends State<_RegisterPaymentModalView> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double _pendingOf(OrderEntity order) {
    return (order.totalAmount - order.amountPaid).clamp(0.0, double.infinity);
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'CAJA':
        return Icons.point_of_sale_rounded;
      case 'BANCO':
        return Icons.account_balance_rounded;
      case 'DIGITAL':
        return Icons.smartphone_rounded;
      default:
        return Icons.wallet_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RegisterPaymentCubit, RegisterPaymentState>(
      builder: (context, state) {
        final cubit = context.read<RegisterPaymentCubit>();
        final mediaQuery = MediaQuery.of(context);
        final isMobile = mediaQuery.size.width < 600;
        final bottomInset = mediaQuery.viewInsets.bottom;
        final debt = widget.account.currentDebt;
        final hasDebt = debt > 0;
        final bool cajaSinTurno =
            state.selectedAccount != null &&
            state.selectedAccount!.type == 'CAJA' &&
            state.activeShift == null;

        final isSubmitDisabled =
            state.isSaving ||
            !hasDebt ||
            cajaSinTurno ||
            state.amountError != null ||
            _amountCtrl.text.trim().isEmpty;

        return BlocListener<RegisterPaymentCubit, RegisterPaymentState>(
          listenWhen:
              (previous, current) =>
                  previous.isSuccess != current.isSuccess ||
                  previous.errorMessage != current.errorMessage,
          listener: (context, state) {
            if (state.isSuccess) {
              widget.onSaved();
              Navigator.pop(context, true);
              AppSnackbar.showMessenger(
                ScaffoldMessenger.of(context),
                message: 'Pago registrado correctamente.',
                type: SnackbarType.success,
              );
            } else if (state.errorMessage != null) {
              AppSnackbar.showMessenger(
                ScaffoldMessenger.of(context),
                message: state.errorMessage!,
                type: SnackbarType.error,
              );
              cubit.clearErrorMessage();
            }
          },
          child: _buildContent(
            context,
            state,
            cubit,
            isMobile,
            bottomInset,
            debt,
            hasDebt,
            isSubmitDisabled,
            cajaSinTurno,
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    RegisterPaymentState state,
    RegisterPaymentCubit cubit,
    bool isMobile,
    double bottomInset,
    double debt,
    bool hasDebt,
    bool isSubmitDisabled,
    bool cajaSinTurno,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final childContent = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        isMobile ? 12 : 24,
        24,
        24 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: AppColors.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registrar Abono / Pago',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Selecciona el modo de aplicación y la cuenta de destino',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: state.isSaving ? null : () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                ),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Tarjeta Deuda Actual
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hasDebt ? AppColors.dangerLight : AppColors.successLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (hasDebt ? AppColors.danger : AppColors.success)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      hasDebt
                          ? Icons.account_balance_wallet_rounded
                          : Icons.check_circle_rounded,
                      color: hasDebt ? AppColors.danger : AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasDebt ? 'Deuda actual:' : 'Deuda saldada:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: hasDebt ? AppColors.danger : AppColors.success,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text(
                  'S/ ${debt.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: hasDebt ? AppColors.danger : AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          // Selección de Aplicación (A cuenta global o a pedido específico)
          const Text(
            'Aplicar abono a',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          if (state.isLoading)
            const SizedBox(
              height: 40,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (state.loadingError != null)
            Text(
              state.loadingError!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            )
          else ...[
            _OrderSelectionTile(
              label: 'Deuda Global (Abono a la cuenta)',
              sublabel: 'Reduce la deuda total del cliente',
              isSelected: state.selectedOrder == null,
              onTap: () {
                cubit.selectOrder(null, debt);
                _amountCtrl.clear();
              },
            ),
            ...state.pendingOrders.map((order) {
              final pending = _pendingOf(order);
              final isPartial = order.paymentStatus == 'PARTIAL';
              final shortId = order.id.split('-').first;
              final pointsEarned = (order.totalAmount * 0.03 / 0.01).floor();

              return _OrderSelectionTile(
                label: 'Pedido #$shortId',
                sublabel:
                    isPartial
                        ? 'Pago parcial · Pendiente S/ ${pending.toStringAsFixed(2)}'
                        : 'Sin cobrar · S/ ${pending.toStringAsFixed(2)}',
                pointsEarned: pointsEarned > 0 ? pointsEarned : null,
                isSelected: state.selectedOrder?.id == order.id,
                onTap: () {
                  cubit.selectOrder(order, pending);
                  _amountCtrl.text = pending.toStringAsFixed(2);
                },
              );
            }),
          ],

          const SizedBox(height: 16),
          // Chips de Montos Rápidos
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickAmountChip(
                label: 'Deuda Total (S/ ${debt.toStringAsFixed(2)})',
                isSelected: state.selectedQuickChip == 'TOTAL',
                onTap: () {
                  cubit.selectQuickAmount(debt, 'TOTAL', debt);
                  _amountCtrl.text = debt.toStringAsFixed(2);
                },
              ),
              if (debt >= 20)
                _QuickAmountChip(
                  label: '50% (S/ ${(debt / 2).toStringAsFixed(2)})',
                  isSelected: state.selectedQuickChip == '50%',
                  onTap: () {
                    cubit.selectQuickAmount(debt / 2, '50%', debt);
                    _amountCtrl.text = (debt / 2).toStringAsFixed(2);
                  },
                ),
            ],
          ),

          const SizedBox(height: 16),
          // Campo Monto
          const Text(
            'Monto a abonar (S/)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (val) {
              final maxDebt =
                  state.selectedOrder != null
                      ? _pendingOf(state.selectedOrder!)
                      : debt;
              cubit.validateAmount(val, maxDebt);
            },
            decoration: InputDecoration(
              hintText: '0.00',
              prefixIcon: const Icon(
                Icons.attach_money_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
          if (state.amountError != null) ...[
            const SizedBox(height: 6),
            Text(
              state.amountError!,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 16),
          // Cuenta de Destino
          const Text(
            'Cuenta de destino (Caja / Banco)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          if (state.isLoading && state.accounts.isEmpty)
            const SizedBox(
              height: 40,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.surface,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<FinancialAccountEntity>(
                  value: state.selectedAccount,
                  isExpanded: true,
                  items:
                      state.accounts.map((acc) {
                        final type = acc.type;
                        return DropdownMenuItem<FinancialAccountEntity>(
                          value: acc,
                          child: Row(
                            children: [
                              Icon(
                                _getIconForType(type),
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                acc.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  onChanged: (val) {
                    if (val != null) cubit.selectAccount(val);
                  },
                ),
              ),
            ),

          // Alerta de Turno Abierto o Cerrado
          if (state.selectedAccount != null &&
              state.selectedAccount!.type == 'CAJA') ...[
            const SizedBox(height: 8),
            if (state.activeShift != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Turno abierto · Se registrará en la caja activa',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La cuenta Caja no tiene un turno abierto. Abre el turno primero.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 16),
          // Notas Opcionales
          const Text(
            'Notas / Referencia (opcional)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Ej. Pago del pedido #123, depósito bcp...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),

          const SizedBox(height: 24),
          // Acciones
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: state.isSaving ? null : () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed:
                    isSubmitDisabled
                        ? null
                        : () {
                          cubit.submitPayment(
                            debt: debt,
                            onSavePayment: widget.onSavePayment,
                            notesText: _notesCtrl.text,
                          );
                        },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
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
                        : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Confirmar pago',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
              ),
            ],
          ),
        ],
      ),
    );

    if (isMobile) {
      return Container(
        constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.88),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: childContent,
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(width: 500, child: childContent),
    );
  }
}

class _OrderSelectionTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final int? pointsEarned;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrderSelectionTile({
    required this.label,
    required this.sublabel,
    this.pointsEarned,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color:
                          isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isSelected ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (pointsEarned != null && pointsEarned! > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Colors.amber,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+$pointsEarned pts',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickAmountChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.success : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.success : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
