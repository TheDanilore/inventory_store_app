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

class SupplierCreditAccountSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final SupplierCreditEntity? accountToEdit;
  final bool isDialog;
  const SupplierCreditAccountSheet({
    super.key,
    required this.onSaved,
    this.accountToEdit,
    required this.isDialog,
  });
  @override
  State<SupplierCreditAccountSheet> createState() =>
      _SupplierCreditAccountSheetState();
}

class _SupplierCreditAccountSheetState
    extends State<SupplierCreditAccountSheet> {
  final _formKey = GlobalKey<FormState>();
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
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSupplierId == null) {
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
    final isDesktop = widget.isDialog;

    // ── 1. COMPONENTES COMPARTIDOS (Inputs y Lógica) ──
    final searchField = TextFormField(
      controller: _searchCtrl,
      onChanged: _onSearchChanged,
      enabled: !_isEditing,
      decoration: InputDecoration(
        hintText: 'Buscar proveedor...',
        prefixIcon: Icon(
          Icons.search_rounded,
          color:
              _selectedSupplierId != null ? Colors.blue : AppColors.textMuted,
        ),
        filled: true,
        fillColor: _isEditing ? Colors.grey.shade100 : AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _selectedSupplierId != null ? Colors.blue : AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _selectedSupplierId != null ? Colors.blue : AppColors.border,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );

    final resultsArea =
        _isSearching
            ? const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
            : (_matches.isNotEmpty && _selectedSupplierId == null)
            ? Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
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
            )
            : const SizedBox.shrink();

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

    // ── 2. FILOSOFÍA ERP: DISEÑO DESKTOP ──
    if (isDesktop) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Container(
          width: 450, // Límite estricto de ancho
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
                      onPressed: _isSaving ? null : _saveAccount,
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
                        elevation: 0, // Plano y limpio para desktop
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
        ),
      );
    }

    // ── 3. FILOSOFÍA APPLE/MATERIAL: DISEÑO MÓVIL ──
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
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
                onPressed: _isSaving ? null : _saveAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ), // Botón más redondo en móvil
                  elevation: 0,
                ),
                child:
                    _isSaving
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white),
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
  }
}
