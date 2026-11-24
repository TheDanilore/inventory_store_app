import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credit_account_form_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credit_account_form_state.dart';

class SupplierCreditAccountSheet extends StatefulWidget {
  final ValueChanged<SupplierCreditEntity?> onSaved;
  final SupplierCreditEntity? accountToEdit;
  final bool isDialog;

  const SupplierCreditAccountSheet({
    super.key,
    required this.onSaved,
    this.accountToEdit,
    required this.isDialog,
  });

  static Future<void> show(
    BuildContext context, {
    SupplierCreditEntity? accountToEdit,
    required ValueChanged<SupplierCreditEntity?> onSaved,
  }) {
    return AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: 480.0,
      barrierLabel:
          accountToEdit != null ? 'Cerrar edición de crédito' : 'Cerrar crédito',
      builder:
          (ctx) => BlocProvider(
            create:
                (_) =>
                    sl<SupplierCreditAccountFormCubit>()..init(accountToEdit),
            child: SupplierCreditAccountSheet(
              accountToEdit: accountToEdit,
              isDialog: AdaptiveDetailSheet.isSideSheet(ctx),
              onSaved: onSaved,
            ),
          ),
    );
  }

  @override
  State<SupplierCreditAccountSheet> createState() =>
      _SupplierCreditAccountSheetState();
}

class _SupplierCreditAccountSheetState
    extends State<SupplierCreditAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();

  bool get _isEditing => widget.accountToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _searchCtrl.text = widget.accountToEdit!.supplierName;
      _limitCtrl.text = widget.accountToEdit!.creditLimit.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  void _selectSupplier(SupplierCandidateEntity supplier) {
    _searchCtrl.text = supplier.name;
    FocusScope.of(context).unfocus();
    context.read<SupplierCreditAccountFormCubit>().selectSupplier(supplier);
  }

  void _submit(SupplierCreditAccountFormState formState) {
    if (!_formKey.currentState!.validate()) return;

    if (formState.selectedSupplierId == null) {
      AppSnackbar.show(
        context,
        message: 'Debe seleccionar un proveedor.',
        type: SnackbarType.error,
      );
      return;
    }

    final limitVal = double.tryParse(_limitCtrl.text.trim()) ?? 0.0;
    if (_isEditing && limitVal < widget.accountToEdit!.currentDebt) {
      AppSnackbar.show(
        context,
        message: 'El límite no puede ser menor a la deuda.',
        type: SnackbarType.error,
      );
      return;
    }

    context.read<SupplierCreditAccountFormCubit>().save(limitVal);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = widget.isDialog;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return BlocConsumer<
      SupplierCreditAccountFormCubit,
      SupplierCreditAccountFormState
    >(
      listenWhen:
          (prev, curr) =>
              prev.savedSuccessfully != curr.savedSuccessfully ||
              prev.saveFailure != curr.saveFailure,
      listener: (context, state) {
        if (state.saveFailure != null) {
          AppSnackbar.show(
            context,
            message: state.saveFailure!.message,
            type: SnackbarType.error,
          );
        } else if (state.savedSuccessfully) {
          AppSnackbar.show(
            context,
            message: 'Crédito guardado.',
            type: SnackbarType.success,
          );
          widget.onSaved(state.savedCredit);
          Navigator.pop(context);
        }
      },
      builder: (context, state) {
        final cubit = context.read<SupplierCreditAccountFormCubit>();
        final hasSelection = state.selectedSupplierId != null;

        final searchField = TextFormField(
          controller: _searchCtrl,
          onChanged: cubit.onSearchChanged,
          enabled: !_isEditing,
          decoration: InputDecoration(
            hintText: 'Buscar proveedor...',
            prefixIcon: Icon(
              Icons.search_rounded,
              color: hasSelection ? Colors.blue : AppColors.textMuted,
            ),
            filled: true,
            fillColor:
                _isEditing ? Colors.grey.shade100 : AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasSelection ? Colors.blue : AppColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasSelection ? Colors.blue : AppColors.border,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        );

        final resultsArea = _buildResultsArea(state);

        final limitField = TextFormField(
          controller: _limitCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'Límite (Ej. 5000.00)',
            prefixIcon: const Icon(Icons.attach_money_rounded),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El límite es requerido';
            }
            if (double.tryParse(value.trim()) == null) {
              return 'Monto inválido';
            }
            return null;
          },
        );

        if (isDesktop) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isEditing
                            ? 'Editar línea de crédito'
                            : 'Nuevo Crédito de Proveedor',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textMuted,
                        ),
                        splashRadius: 20,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Seleccionar Proveedor',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  searchField,
                  resultsArea,
                  const SizedBox(height: 16),
                  const Text(
                    'Límite Asignado (S/)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  limitField,
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
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
                            state.isSaving ? null : () => _submit(state),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child:
                            state.isSaving
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text(
                                  'Guardar crédito',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSheetDragHandle(padding: EdgeInsets.only(bottom: 12)),
                  Text(
                    _isEditing
                        ? 'Editar línea de crédito'
                        : 'Nuevo Crédito de Proveedor',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  searchField,
                  resultsArea,
                  const SizedBox(height: 16),
                  limitField,
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: state.isSaving ? null : () => _submit(state),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child:
                        state.isSaving
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              'Guardar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsArea(SupplierCreditAccountFormState state) {
    if (state.isSearching) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.searchFailure != null) {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: AppColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.searchFailure!.message,
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ),
          ],
        ),
      );
    }

    if (state.matches.isNotEmpty && state.selectedSupplierId == null) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        constraints: const BoxConstraints(maxHeight: 160),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: state.matches.length,
          itemBuilder: (c, i) {
            final item = state.matches[i];
            return ListTile(
              title: Text(item.name),
              subtitle: Text('RUC: ${item.taxId ?? '-'}'),
              onTap: () => _selectSupplier(item),
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
