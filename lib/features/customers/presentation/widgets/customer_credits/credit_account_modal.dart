import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_state.dart';

class CreditAccountModal extends StatelessWidget {
  final VoidCallback onSaved;
  final CustomerCreditEntity? accountToEdit;
  final bool isDialog;

  const CreditAccountModal({
    super.key,
    required this.onSaved,
    this.accountToEdit,
    this.isDialog = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    CustomerCreditEntity? accountToEdit,
    required VoidCallback onSaved,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    if (isDesktop) {
      return showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 520,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: CreditAccountModal(
                  accountToEdit: accountToEdit,
                  onSaved: onSaved,
                  isDialog: true,
                ),
              ),
            ),
          );
        },
      );
    } else {
      return showModalBottomSheet<bool>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (sheetCtx) => CreditAccountModal(
              accountToEdit: accountToEdit,
              onSaved: onSaved,
              isDialog: false,
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CustomersCubit>(),
      child: _CreditAccountModalView(
        onSaved: onSaved,
        accountToEdit: accountToEdit,
        isDialog: isDialog,
      ),
    );
  }
}

class _CreditAccountModalView extends StatefulWidget {
  final VoidCallback onSaved;
  final CustomerCreditEntity? accountToEdit;
  final bool isDialog;

  const _CreditAccountModalView({
    required this.onSaved,
    this.accountToEdit,
    this.isDialog = false,
  });

  @override
  State<_CreditAccountModalView> createState() =>
      _CreditAccountModalViewState();
}

class _CreditAccountModalViewState extends State<_CreditAccountModalView> {
  final _searchCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  Timer? _debounce;

  bool _isSaving = false;
  bool _isUnlimited = true;
  String? _selectedProfileId;
  String? _selectedProfileName;

  bool get _isEditing => widget.accountToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _selectedProfileId = widget.accountToEdit!.profileId;
      _selectedProfileName = widget.accountToEdit!.customerName;
      _searchCtrl.text = _selectedProfileName ?? '';
      _isUnlimited = widget.accountToEdit!.isUnlimited;
      if (!_isUnlimited) {
        _limitCtrl.text = widget.accountToEdit!.creditLimit.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _limitCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_selectedProfileId != null) {
      setState(() {
        _selectedProfileId = null;
        _selectedProfileName = null;
      });
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => context.read<CustomersCubit>().search(query),
    );
  }

  void _selectClient(String id, String name) {
    setState(() {
      _selectedProfileId = id;
      _selectedProfileName = name;
      _searchCtrl.text = _selectedProfileName!;
      FocusScope.of(context).unfocus();
    });
  }

  Future<void> _saveAccount() async {
    if (_selectedProfileId == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un cliente primero.',
        type: SnackbarType.error,
      );
      return;
    }

    final limitVal =
        _isUnlimited ? 0.0 : (double.tryParse(_limitCtrl.text.trim()) ?? 0.0);

    if (!_isUnlimited && limitVal <= 0) {
      AppSnackbar.show(
        context,
        message: 'Ingresa un límite de crédito válido (mayor a 0).',
        type: SnackbarType.error,
      );
      return;
    }

    if (_isEditing &&
        !_isUnlimited &&
        limitVal < widget.accountToEdit!.currentDebt &&
        widget.accountToEdit!.currentDebt > 0) {
      AppSnackbar.show(
        context,
        message:
            'El límite no puede ser menor a la deuda actual (S/ ${widget.accountToEdit!.currentDebt.toStringAsFixed(2)}).',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final cubit = context.read<CustomerCreditListCubit>();

      if (_isEditing) {
        await cubit.updateCreditLimit(widget.accountToEdit!.id, limitVal);
      } else {
        await cubit.createCreditAccount(_selectedProfileId!, limitVal);
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              _isEditing
                  ? 'Límite de crédito actualizado.'
                  : 'Línea de crédito aprobada.',
          type: SnackbarType.success,
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        widget.isDialog ? 24 : 16,
        24,
        24 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            widget.isDialog
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.isDialog)
            const AppSheetDragHandle(padding: EdgeInsets.only(bottom: 16)),
          Row(
            children: [
              Expanded(
                child: Text(
                  _isEditing
                      ? 'Editar límite de crédito'
                      : 'Aprobar línea de crédito',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (widget.isDialog)
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  splashRadius: 18,
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Cliente',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: _isEditing ? Colors.grey.shade100 : AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _selectedProfileId != null
                        ? AppColors.primary
                        : AppColors.border,
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              enabled: !_isEditing,
              style: TextStyle(
                color:
                    _isEditing ? Colors.grey.shade600 : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, DNI o teléfono...',
                prefixIcon: Icon(
                  _selectedProfileId != null
                      ? Icons.check_circle_rounded
                      : Icons.search_rounded,
                  color:
                      _selectedProfileId != null
                          ? AppColors.primary
                          : AppColors.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (!_isEditing && _selectedProfileId == null)
            BlocBuilder<CustomersCubit, CustomersState>(
              builder: (context, state) {
                if (state is CustomersLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                } else if (state is CustomersLoaded &&
                    state.customers.isNotEmpty) {
                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: state.customers.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final client = state.customers[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primaryLight,
                            child: Text(
                              client.fullName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            client.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('Doc: ${client.documentNumber}'),
                          onTap:
                              () => _selectClient(client.id, client.fullName),
                        );
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          const SizedBox(height: 16),
          const Text(
            'Tipo de límite de crédito',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isUnlimited = true;
                        _limitCtrl.clear();
                      });
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isUnlimited ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow:
                            _isUnlimited
                                ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.all_inclusive_rounded,
                            size: 16,
                            color:
                                _isUnlimited
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sin límite (∞)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  _isUnlimited
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                              color:
                                  _isUnlimited
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isUnlimited = false;
                      });
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            !_isUnlimited ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow:
                            !_isUnlimited
                                ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color:
                                !_isUnlimited
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Límite fijo (S/)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  !_isUnlimited
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                              color:
                                  !_isUnlimited
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isUnlimited)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF059669),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Crédito ilimitado activado. El cliente puede realizar compras a crédito sin un tope máximo predeterminado.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade800,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            const Text(
              'Límite de crédito (S/)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _limitCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Ej. 500.00',
                  prefixIcon: Icon(
                    Icons.attach_money_rounded,
                    color: AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_isEditing && widget.accountToEdit!.currentDebt > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Deuda actual: S/ ${widget.accountToEdit!.currentDebt.toStringAsFixed(2)}. '
                      'El límite no puede ser menor.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                _isSaving
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : Text(
                      _isEditing
                          ? 'Actualizar límite'
                          : 'Crear cuenta de crédito',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
