import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_side_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements/account_movements_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements/account_movements_state.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_state.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';

class MovementFormSheet extends StatefulWidget {
  final bool isSlideOver;

  const MovementFormSheet({super.key, this.isSlideOver = false});

  static Future<bool?> show(BuildContext context) {
    final accCubit = context.read<FinancialAccountsCubit>();
    final movCubit = context.read<AccountMovementsCubit>();
    final shiftCubit = context.read<CashShiftsCubit>();

    return AdaptiveSideSheet.show<bool>(
      context: context,
      desktopWidth: 500.0,
      builder: (dialogCtx, isSlideOver) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: accCubit),
          BlocProvider.value(value: movCubit),
          BlocProvider.value(value: shiftCubit),
        ],
        child: MovementFormSheet(isSlideOver: isSlideOver),
      ),
    );
  }

  @override
  State<MovementFormSheet> createState() => _MovementFormSheetState();
}

class _MovementFormSheetState extends State<MovementFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _type = 'INCOME';
  String? _sourceAccountId;
  String? _destAccountId;

  List<FinancialAccountEntity> _accounts = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accState = context.read<FinancialAccountsCubit>().state;
      final accounts = accState is FinancialAccountsLoaded
          ? accState.accounts.where((a) => a.isActive).toList()
          : <FinancialAccountEntity>[];
      setState(() {
        _accounts = accounts;
        if (_accounts.isNotEmpty) {
          _sourceAccountId = _accounts.first.id;
          if (_accounts.length > 1) {
            _destAccountId = _accounts[1].id;
          } else {
            _destAccountId = _accounts.first.id;
          }
        }
      });
    });
  }

  bool _isCajaWithoutShift(String? accountId) {
    if (accountId == null) return false;
    final acc = _accounts.where((a) => a.id == accountId).firstOrNull;
    if (acc == null || acc.type != 'CAJA') return false;
    final openIds = context.read<CashShiftsCubit>().state.openAccountIds;
    return !openIds.contains(accountId);
  }

  bool get _isSourceCajaWithoutShift => _isCajaWithoutShift(_sourceAccountId);
  bool get _isDestCajaWithoutShift =>
      _type == 'TRANSFER' && _isCajaWithoutShift(_destAccountId);

  bool get _hasShiftBlocker =>
      _isSourceCajaWithoutShift || _isDestCajaWithoutShift;

  String _friendlyError(String rawMessage) {
    final match = RegExp(r'message:\s*(.+?)(?:,|$)').firstMatch(rawMessage);
    if (match != null) return match.group(1)!.trim();
    if (rawMessage.startsWith('Exception: ')) {
      return rawMessage.substring(11).trim();
    }
    return rawMessage;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _sourceAccountId == null) return;

    if (_type == 'TRANSFER' && _sourceAccountId == _destAccountId) {
      AppSnackbar.show(
        context,
        message: 'La cuenta origen y destino no pueden ser la misma',
        type: SnackbarType.warning,
      );
      return;
    }

    if (_hasShiftBlocker) {
      String msg;
      if (_type == 'TRANSFER') {
        if (_isSourceCajaWithoutShift && _isDestCajaWithoutShift) {
          final sName = _accounts.where((a) => a.id == _sourceAccountId).firstOrNull?.name ?? 'origen';
          final dName = _accounts.where((a) => a.id == _destAccountId).firstOrNull?.name ?? 'destino';
          msg = 'Las cuentas "$sName" y "$dName" requieren turnos de caja abiertos.';
        } else if (_isDestCajaWithoutShift) {
          final dName = _accounts.where((a) => a.id == _destAccountId).firstOrNull?.name ?? 'destino';
          msg = 'La cuenta destino "$dName" no tiene un turno de caja abierto.';
        } else {
          final sName = _accounts.where((a) => a.id == _sourceAccountId).firstOrNull?.name ?? 'origen';
          msg = 'La cuenta origen "$sName" no tiene un turno de caja abierto.';
        }
      } else {
        final sName = _accounts.where((a) => a.id == _sourceAccountId).firstOrNull?.name ?? 'seleccionada';
        msg = 'La cuenta "$sName" no tiene un turno de caja abierto.';
      }

      AppSnackbar.show(
        context,
        message: '$msg Abre el turno desde el módulo de Punto de Venta antes de continuar.',
        type: SnackbarType.warning,
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final description = _descCtrl.text.trim();

    final sourceAccount = _accounts.where((a) => a.id == _sourceAccountId).firstOrNull;
    if (sourceAccount != null && (_type == 'EXPENSE' || _type == 'TRANSFER')) {
      if (amount > sourceAccount.balance) {
        AppSnackbar.show(
          context,
          message:
              'Saldo insuficiente en "${sourceAccount.name}". Saldo disponible: S/ ${sourceAccount.balance.toStringAsFixed(2)}',
          type: SnackbarType.warning,
        );
        return;
      }
    }

    setState(() => _saving = true);

    if (_type == 'TRANSFER') {
      if (_destAccountId == null) {
        AppSnackbar.show(
          context,
          message: 'Seleccione una cuenta destino',
          type: SnackbarType.warning,
        );
        setState(() => _saving = false);
        return;
      }
      await context.read<AccountMovementsCubit>().transferFunds(
            sourceAccountId: _sourceAccountId!,
            destAccountId: _destAccountId!,
            amount: amount,
            description: description,
          );
    } else {
      await context.read<AccountMovementsCubit>().saveMovement(
            accountId: _sourceAccountId!,
            movementType: _type,
            amount: amount,
            description: description,
          );
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accState = context.watch<FinancialAccountsCubit>().state;
    if (accState is FinancialAccountsLoaded) {
      final activeAccounts = accState.accounts.where((a) => a.isActive).toList();
      if (_accounts.isEmpty && activeAccounts.isNotEmpty) {
        _accounts = activeAccounts;
        _sourceAccountId ??= _accounts.first.id;
        if (_accounts.length > 1) {
          _destAccountId ??= _accounts[1].id;
        } else {
          _destAccountId ??= _accounts.first.id;
        }
      } else if (activeAccounts.isNotEmpty) {
        _accounts = activeAccounts;
      }
    }

    return BlocListener<AccountMovementsCubit, AccountMovementsState>(
      listener: (context, state) {
        if (state is AccountMovementSaved) {
          context.read<FinancialAccountsCubit>().fetchAccounts();
          AppSnackbar.show(
            context,
            message: 'Movimiento registrado correctamente',
            type: SnackbarType.success,
          );
          Navigator.pop(context, true);
        } else if (state is AccountMovementSaveError) {
          setState(() => _saving = false);
          AppSnackbar.show(
            context,
            message: _friendlyError(state.message),
            type: SnackbarType.error,
          );
        }
      },
      child: widget.isSlideOver ? _buildSlideOverLayout() : _buildBottomSheetLayout(),
    );
  }

  // ── Desktop / Tablet: Slide-over Right Side Sheet Layout ───────────────────
  Widget _buildSlideOverLayout() {
    if (_accounts.isEmpty) {
      return Container(
        color: AppColors.surface,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [
        // Encabezado corporativo Linear/Stripe
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.tealDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nuevo Movimiento Financiero',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Registra ingresos, egresos o traspasos de saldo',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar [Esc]',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Cuerpo desplazable
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: _buildFormFields(),
            ),
          ),
        ),

        // Barra inferior fija
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving || _hasShiftBlocker ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _type == 'INCOME'
                        ? AppColors.tealDark
                        : (_type == 'EXPENSE' ? AppColors.danger : AppColors.primary),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _saving
                        ? 'Guardando...'
                        : (_hasShiftBlocker
                            ? 'Caja sin turno abierto'
                            : 'Guardar Movimiento'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Mobile: Bottom Sheet Layout (Apple HIG) ───────────────────────────────
  Widget _buildBottomSheetLayout() {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    if (_accounts.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Nuevo Movimiento',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: _buildFormFields(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving || _hasShiftBlocker ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _type == 'INCOME'
                      ? AppColors.tealDark
                      : (_type == 'EXPENSE' ? AppColors.danger : AppColors.primary),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _hasShiftBlocker
                            ? 'Caja sin turno abierto'
                            : 'Guardar movimiento',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Tipo de movimiento *'),
        Row(
          children: [
            Expanded(
              child: _TypeToggle(
                label: 'Ingreso',
                icon: Icons.arrow_downward_rounded,
                color: AppColors.tealDark,
                isSelected: _type == 'INCOME',
                onTap: () => setState(() => _type = 'INCOME'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TypeToggle(
                label: 'Egreso',
                icon: Icons.arrow_upward_rounded,
                color: AppColors.danger,
                isSelected: _type == 'EXPENSE',
                onTap: () => setState(() => _type = 'EXPENSE'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TypeToggle(
                label: 'Transfer.',
                icon: Icons.swap_horiz_rounded,
                color: AppColors.primary,
                isSelected: _type == 'TRANSFER',
                onTap: () => setState(() => _type = 'TRANSFER'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        _fieldLabel(
          _type == 'TRANSFER'
              ? 'Cuenta Origen (Sale el dinero) *'
              : 'Cuenta Financiera *',
        ),
        _AccountSelector(
          value: _sourceAccountId,
          accounts: _accounts,
          onChanged: (v) => setState(() => _sourceAccountId = v),
        ),
        const SizedBox(height: 14),

        if (_type == 'TRANSFER') ...[
          _fieldLabel('Cuenta Destino (Entra el dinero) *'),
          _AccountSelector(
            value: _destAccountId,
            accounts: _accounts,
            onChanged: (v) => setState(() => _destAccountId = v),
          ),
          const SizedBox(height: 14),
        ],

        if (_hasShiftBlocker) ...[
          _ShiftWarningBanner(
            isTransfer: _type == 'TRANSFER',
            isSourceBlocked: _isSourceCajaWithoutShift,
            isDestBlocked: _isDestCajaWithoutShift,
            sourceAccountName: _accounts.where((a) => a.id == _sourceAccountId).firstOrNull?.name,
            destAccountName: _accounts.where((a) => a.id == _destAccountId).firstOrNull?.name,
          ),
          const SizedBox(height: 14),
        ],

        _fieldLabel('Monto (S/) *'),
        TextFormField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: _inputDeco('0.00').copyWith(
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                'S/ ',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Ingresa un monto';
            final parsed = double.tryParse(v.replaceAll(',', '.')) ?? 0;
            if (parsed <= 0) return 'Monto debe ser mayor a 0';
            return null;
          },
        ),
        const SizedBox(height: 14),

        _fieldLabel('Descripción o motivo *'),
        TextFormField(
          controller: _descCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: _inputDeco('Ej. Depósito ventas del día, Pago de servicios, etc.'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) && _type != 'TRANSFER'
                  ? 'La descripción es obligatoria'
                  : null,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: AppColors.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      );
}

// ── Banner preventivo de turno de caja ─────────────────────────────────────────
class _ShiftWarningBanner extends StatelessWidget {
  final bool isTransfer;
  final bool isSourceBlocked;
  final bool isDestBlocked;
  final String? sourceAccountName;
  final String? destAccountName;

  const _ShiftWarningBanner({
    required this.isTransfer,
    required this.isSourceBlocked,
    required this.isDestBlocked,
    this.sourceAccountName,
    this.destAccountName,
  });

  @override
  Widget build(BuildContext context) {
    String message;
    if (isTransfer) {
      if (isSourceBlocked && isDestBlocked) {
        final sName = sourceAccountName ?? 'la caja de origen';
        final dName = destAccountName ?? 'la caja de destino';
        message = 'Tanto "$sName" como "$dName" no tienen un turno de caja abierto.';
      } else if (isDestBlocked) {
        final dName = destAccountName ?? 'la caja de destino';
        message = 'La caja destino "$dName" no tiene un turno de caja abierto.';
      } else {
        final sName = sourceAccountName ?? 'la caja de origen';
        message = 'La caja origen "$sName" no tiene un turno de caja abierto.';
      }
    } else {
      final sName = sourceAccountName ?? 'la caja seleccionada';
      message = '"$sName" requiere un turno de caja abierto para registrar movimientos.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warningDark,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$message Abre el turno desde el Punto de Venta antes de registrar este movimiento.',
              style: const TextStyle(
                color: AppColors.warningDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? color : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSelector extends StatelessWidget {
  final String? value;
  final List<FinancialAccountEntity> accounts;
  final ValueChanged<String?> onChanged;

  const _AccountSelector({
    required this.value,
    required this.accounts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.textSecondary),
          items: accounts.map((a) {
            IconData typeIcon = Icons.savings_rounded;
            if (a.type == 'CAJA') typeIcon = Icons.point_of_sale_rounded;
            if (a.type == 'BANCO') typeIcon = Icons.account_balance_rounded;
            if (a.type == 'DIGITAL') typeIcon = Icons.phone_android_rounded;

            return DropdownMenuItem<String>(
              value: a.id,
              child: Row(
                children: [
                  Icon(typeIcon, size: 16, color: AppColors.tealDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      a.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'S/ ${a.balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: a.balance >= 0 ? AppColors.tealDark : AppColors.danger,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
