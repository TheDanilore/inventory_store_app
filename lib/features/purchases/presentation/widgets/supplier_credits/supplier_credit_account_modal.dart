import 'dart:async';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_existing_credit_supplier_ids_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/search_suppliers_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_admin_profile_id_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/save_supplier_credit_usecase.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class SupplierCreditAccountModal extends StatefulWidget {
  final VoidCallback onSaved;
  final SupplierCreditEntity? accountToEdit;
  const SupplierCreditAccountModal({
    super.key,
    required this.onSaved,
    this.accountToEdit,
  });
  @override
  State<SupplierCreditAccountModal> createState() =>
      _SupplierCreditAccountModalState();
}

class _SupplierCreditAccountModalState
    extends State<SupplierCreditAccountModal> {
  final _searchCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _matches = [];
  String? _selectedSupplierId;
  String? _selectedSupplierName;
  bool get _isEditing => widget.accountToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _selectedSupplierId = widget.accountToEdit!.supplierId;
      _selectedSupplierName = widget.accountToEdit!.supplierName;
      _searchCtrl.text = _selectedSupplierName!;
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
    if (_selectedSupplierId != null) {
      setState(() {
        _selectedSupplierId = null;
        _selectedSupplierName = null;
      });
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchSuppliers(query),
    );
  }

  Future<void> _searchSuppliers(String query) async {
    final text = query.trim();
    if (text.isEmpty) {
      setState(() {
        _matches = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final existingIdsResult = await sl<GetExistingCreditSupplierIdsUseCase>()
          .call(
            excludeSupplierId:
                _isEditing ? widget.accountToEdit!.supplierId : null,
          );
      final existingIds = existingIdsResult.fold((l) => <String>{}, (r) => r);
      final filteredResult = await sl<SearchSuppliersUseCase>().call(
        text,
        existingIds,
      );
      final filtered = filteredResult.fold(
        (l) => <Map<String, dynamic>>[],
        (r) => r,
      );

      if (mounted) {
        setState(() {
          _matches = filtered;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSupplier(Map<String, dynamic> supplier) {
    setState(() {
      _selectedSupplierId = supplier['id'] as String;
      _selectedSupplierName = supplier['name'] as String;
      _searchCtrl.text = _selectedSupplierName!;
      _matches = [];
      FocusScope.of(context).unfocus();
    });
  }

  Future<void> _saveAccount() async {
    if (_selectedSupplierId == null || _limitCtrl.text.isEmpty) return;
    final limitVal = double.tryParse(_limitCtrl.text.trim()) ?? 0.0;
    if (_isEditing && limitVal < widget.accountToEdit!.currentDebt) {
      AppSnackbar.show(
        context,
        message: 'El límite no puede ser menor a la deuda.',
        type: SnackbarType.error,
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final adminProfileIdResult = await sl<GetAdminProfileIdUseCase>().call();
      final adminProfileId = adminProfileIdResult.fold((l) => null, (r) => r);

      final saveResult = await sl<SaveSupplierCreditUseCase>().call(
        creditId: _isEditing ? widget.accountToEdit!.creditId : null,
        supplierId: _selectedSupplierId!,
        creditLimit: limitVal,
        adminProfileId: adminProfileId,
      );
      if (saveResult.isLeft()) {
        throw Exception(saveResult.fold((l) => l.message, (r) => ''));
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Crédito guardado.',
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
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
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
                ? 'Editar línea de crédito'
                : 'Nuevo Crédito de Proveedor',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: _isEditing ? Colors.grey.shade100 : AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _selectedSupplierId != null
                        ? Colors.blue
                        : AppColors.border,
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              enabled: !_isEditing,
              decoration: InputDecoration(
                hintText: 'Buscar proveedor...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color:
                      _selectedSupplierId != null
                          ? Colors.blue
                          : AppColors.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_matches.isNotEmpty && _selectedSupplierId == null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _matches.length,
                itemBuilder:
                    (c, i) => ListTile(
                      title: Text(_matches[i]['name']),
                      subtitle: Text('RUC: ${_matches[i]['tax_id'] ?? '-'}'),
                      onTap: () => _selectSupplier(_matches[i]),
                    ),
              ),
            ),
          const SizedBox(height: 16),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Límite (Ej. 5000.00)',
                prefixIcon: Icon(Icons.attach_money_rounded),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
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
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                    : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
