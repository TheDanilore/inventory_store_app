import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/models/supplier_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

// ─── PANTALLA PRINCIPAL ───────────────────────────────────────────────────────
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<SupplierModel> _allSuppliers = [];
  List<SupplierModel> _filteredSuppliers = [];
  bool _isLoading = true;

  static const int _pageSize = 8;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('suppliers')
          .select()
          .order('name', ascending: true);

      final list =
          (response as List)
              .map((item) => SupplierModel.fromJson(item))
              .toList();

      if (mounted) {
        setState(() {
          _allSuppliers = list;
          _applyFilter(_searchCtrl.text);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) {
      _filteredSuppliers = List.from(_allSuppliers);
    } else {
      _filteredSuppliers =
          _allSuppliers.where((s) {
            return s.name.toLowerCase().contains(term) ||
                (s.taxId?.toLowerCase().contains(term) ?? false) ||
                (s.contactName?.toLowerCase().contains(term) ?? false);
          }).toList();
    }
    setState(() {
      _currentPage = 0;
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _applyFilter(query);
    });
  }

  Future<void> _toggleStatus(SupplierModel supplier) async {
    try {
      await _supabase
          .from('suppliers')
          .update({'is_active': !supplier.isActive})
          .eq('id', supplier.id);

      _fetchSuppliers();
      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              supplier.isActive
                  ? 'Proveedor desactivado'
                  : 'Proveedor activado',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _openSupplierModal([SupplierModel? supplier]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _SupplierFormModal(
            supplierToEdit: supplier,
            onSaved: _fetchSuppliers,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Proveedores',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSupplierModal(),
        backgroundColor: AppColors.teal,
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: const Text(
          'Nuevo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // ── Buscador ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, RUC o contacto...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // ── Lista ──
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredSuppliers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 60,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay proveedores registrados',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : Builder(
                      builder: (context) {
                        final totalPages =
                            (_filteredSuppliers.length / _pageSize).ceil();
                        final safePage =
                            _currentPage >= totalPages ? 0 : _currentPage;
                        final pageStart = safePage * _pageSize;
                        final pageEnd = (pageStart + _pageSize).clamp(
                          0,
                          _filteredSuppliers.length,
                        );
                        final pageItems = _filteredSuppliers.sublist(
                          pageStart,
                          pageEnd,
                        );

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Mostrando ${pageStart + 1}–$pageEnd de ${_filteredSuppliers.length} proveedores',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _fetchSuppliers,
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    16,
                                  ),
                                  itemCount: pageItems.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final supplier = pageItems[index];
                                    return _SupplierCard(
                                      supplier: supplier,
                                      onEdit:
                                          () => _openSupplierModal(supplier),
                                      onToggleStatus:
                                          () => _toggleStatus(supplier),
                                    );
                                  },
                                ),
                              ),
                            ),
                            if (totalPages > 1)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  10,
                                ),
                                child: AdminPageBlocks(
                                  currentPage: _currentPage,
                                  totalPages: totalPages,
                                  onPageChanged:
                                      (page) =>
                                          setState(() => _currentPage = page),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

// ─── WIDGET: Tarjeta de Proveedor ─────────────────────────────────────────────

class _SupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const _SupplierCard({
    required this.supplier,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor:
                      supplier.isActive
                          ? AppColors.tealLight
                          : Colors.grey.shade200,
                  child: Text(
                    supplier.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color:
                          supplier.isActive ? AppColors.tealDark : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              supplier.isActive
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                          decoration:
                              supplier.isActive
                                  ? null
                                  : TextDecoration.lineThrough,
                        ),
                      ),
                      if (supplier.taxId != null && supplier.taxId!.isNotEmpty)
                        Text(
                          'RUC / ID: ${supplier.taxId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        supplier.isActive
                            ? AppColors.successLight
                            : AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    supplier.isActive ? 'ACTIVO' : 'INACTIVO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color:
                          supplier.isActive
                              ? AppColors.success
                              : AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),

            // Tarjeta interior con los datos financieros (Crédito)
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    supplier.creditLimit > 0
                        ? Colors.blue.shade50
                        : AppColors.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      supplier.creditLimit > 0
                          ? Colors.blue.shade100
                          : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Límite de Crédito',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        supplier.creditLimit > 0
                            ? 'S/ ${supplier.creditLimit.toStringAsFixed(2)}'
                            : 'Al contado',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color:
                              supplier.creditLimit > 0
                                  ? Colors.blue.shade800
                                  : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Plazo Pactado',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color:
                                supplier.creditLimit > 0
                                    ? Colors.blue.shade700
                                    : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${supplier.paymentTermsDays} días',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color:
                                  supplier.creditLimit > 0
                                      ? Colors.blue.shade800
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Detalles de contacto si existen
            if (supplier.contactName != null ||
                supplier.phone != null ||
                supplier.email != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    if (supplier.contactName != null &&
                        supplier.contactName!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.person_rounded,
                        text: supplier.contactName!,
                      ),
                    if (supplier.phone != null && supplier.phone!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _InfoRow(
                          icon: Icons.phone_rounded,
                          text: supplier.phone!,
                        ),
                      ),
                    if (supplier.email != null && supplier.email!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _InfoRow(
                          icon: Icons.email_rounded,
                          text: supplier.email!,
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onToggleStatus,
                  icon: Icon(
                    supplier.isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_rounded,
                    size: 16,
                    color:
                        supplier.isActive
                            ? AppColors.danger
                            : AppColors.success,
                  ),
                  label: Text(
                    supplier.isActive ? 'Desactivar' : 'Activar',
                    style: TextStyle(
                      color:
                          supplier.isActive
                              ? AppColors.danger
                              : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tealLight,
                    foregroundColor: AppColors.tealDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Editar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── MODAL: Crear / Editar Proveedor ──────────────────────────────────────────

class _SupplierFormModal extends StatefulWidget {
  final SupplierModel? supplierToEdit;
  final VoidCallback onSaved;

  const _SupplierFormModal({this.supplierToEdit, required this.onSaved});

  @override
  State<_SupplierFormModal> createState() => _SupplierFormModalState();
}

class _SupplierFormModalState extends State<_SupplierFormModal> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();
  final _paymentTermsCtrl = TextEditingController();

  bool _isSaving = false;

  bool get _isEditing => widget.supplierToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final s = widget.supplierToEdit!;
      _nameCtrl.text = s.name;
      _taxIdCtrl.text = s.taxId ?? '';
      _contactCtrl.text = s.contactName ?? '';
      _phoneCtrl.text = s.phone ?? '';
      _emailCtrl.text = s.email ?? '';
      _addressCtrl.text = s.address ?? '';
      _creditLimitCtrl.text = s.creditLimit.toStringAsFixed(2);
      _paymentTermsCtrl.text = s.paymentTermsDays.toString();
    } else {
      _creditLimitCtrl.text = '0.00';
      _paymentTermsCtrl.text = '30';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taxIdCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _creditLimitCtrl.dispose();
    _paymentTermsCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final limitVal = double.tryParse(_creditLimitCtrl.text.trim()) ?? 0.0;
      final termsVal = int.tryParse(_paymentTermsCtrl.text.trim()) ?? 30;

      final data = {
        'name': _nameCtrl.text.trim(),
        'tax_id':
            _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
        'contact_name':
            _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'address':
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'credit_limit': limitVal,
        'payment_terms_days': termsVal,
      };

      if (_isEditing) {
        await _supabase
            .from('suppliers')
            .update(data)
            .eq('id', widget.supplierToEdit!.id);
      } else {
        await _supabase.from('suppliers').insert(data);
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message: _isEditing ? 'Proveedor actualizado' : 'Proveedor creado',
          type: SnackbarType.success,
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        if (e.code == '23505') {
          AppSnackbar.show(
            context,
            message: 'Ya existe un proveedor con ese número de RUC/ID fiscal.',
            type: SnackbarType.error,
          );
        } else {
          AppSnackbar.show(
            context,
            message: 'Error de base de datos: ${e.message}',
            type: SnackbarType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error inesperado: $e',
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
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
                _isEditing ? 'Editar Proveedor' : 'Nuevo Proveedor',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // ── Datos Generales ──
              const Text(
                'Datos Generales',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nameCtrl,
                label: 'Nombre o Razón Social *',
                icon: Icons.business_rounded,
                validator:
                    (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              _buildTextField(
                controller: _taxIdCtrl,
                label: 'RUC / ID Fiscal (Opcional)',
                icon: Icons.assignment_ind_rounded,
              ),
              _buildTextField(
                controller: _contactCtrl,
                label: 'Nombre del contacto (Opcional)',
                icon: Icons.person_rounded,
              ),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _phoneCtrl,
                      label: 'Teléfono',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      controller: _emailCtrl,
                      label: 'Correo electrónico',
                      icon: Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              _buildTextField(
                controller: _addressCtrl,
                label: 'Dirección (Opcional)',
                icon: Icons.location_on_rounded,
              ),

              const Divider(height: 32),

              // ── Condiciones de Crédito ──
              const Text(
                'Condiciones Comerciales',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _creditLimitCtrl,
                      label: 'Límite de Crédito (S/)',
                      icon: Icons.account_balance_wallet_rounded,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      controller: _paymentTermsCtrl,
                      label: 'Plazo (Días)',
                      icon: Icons.calendar_today_rounded,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Si no te ofrecen crédito, deja el límite en 0.00.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: _isSaving ? null : _saveSupplier,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
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
                          _isEditing ? 'Guardar Cambios' : 'Crear Proveedor',
                          style: const TextStyle(
                            color: Colors.white,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
          filled: true,
          fillColor: AppColors.bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
