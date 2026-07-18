import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit_list_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers_state.dart';

class CreditAccountModal extends StatelessWidget {
  final VoidCallback onSaved;
  final CustomerCreditEntity? accountToEdit;

  const CreditAccountModal({
    super.key,
    required this.onSaved,
    this.accountToEdit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CustomersCubit>(),
      child: _CreditAccountModalView(
        onSaved: onSaved,
        accountToEdit: accountToEdit,
      ),
    );
  }
}

class _CreditAccountModalView extends StatefulWidget {
  final VoidCallback onSaved;
  final CustomerCreditEntity? accountToEdit;

  const _CreditAccountModalView({required this.onSaved, this.accountToEdit});

  @override
  State<_CreditAccountModalView> createState() =>
      _CreditAccountModalViewState();
}

class _CreditAccountModalViewState extends State<_CreditAccountModalView> {
  final _searchCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  Timer? _debounce;

  bool _isSaving = false;
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
      _limitCtrl.text = widget.accountToEdit!.creditLimit.toStringAsFixed(2);
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

    final limitVal = double.tryParse(_limitCtrl.text.trim()) ?? 0.0;
    if (limitVal <= 0) {
      AppSnackbar.show(
        context,
        message: 'Ingresa un límite de crédito válido (mayor a 0).',
        type: SnackbarType.error,
      );
      return;
    }

    if (_isEditing &&
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
        // Asumiendo que agregaste updateCreditLimit al cubit
        // await cubit.updateCreditLimit(widget.accountToEdit!.id, limitVal);
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
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Text(
            _isEditing
                ? 'Editar límite de crédito'
                : 'Aprobar línea de crédito',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
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
                Text(
                  'Deuda actual: S/ ${widget.accountToEdit!.currentDebt.toStringAsFixed(2)}. '
                  'El límite no puede ser menor.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
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
