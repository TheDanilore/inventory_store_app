import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class SupplierFormModal extends StatefulWidget {
  final SupplierEntity? supplierToEdit;
  final VoidCallback onSaved;
  final bool isDialog;

  const SupplierFormModal({
    super.key,
    this.supplierToEdit,
    required this.onSaved,
    this.isDialog = false,
  });

  @override
  State<SupplierFormModal> createState() => _SupplierFormModalState();
}

class _SupplierFormModalState extends State<SupplierFormModal> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

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
    super.dispose();
  }

  void _saveSupplier() {
    if (!_formKey.currentState!.validate()) return;

    final supplier = SupplierEntity(
      id: _isEditing ? widget.supplierToEdit!.id : '',
      name: _nameCtrl.text.trim(),
      taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
      contactName:
          _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      address:
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      isActive: _isEditing ? widget.supplierToEdit!.isActive : true,
    );

    context.read<SuppliersCubit>().saveSupplier(supplier);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDesktop = widget.isDialog;

    final formFields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDesktop) ...[
          // Fila 1: Nombre (flex 6) + RUC (flex 4)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildTextField(
                  controller: _nameCtrl,
                  label: 'Nombre o Razón Social *',
                  icon: Icons.business_rounded,
                  validator:
                      (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: _buildTextField(
                  controller: _taxIdCtrl,
                  label: 'RUC / ID Fiscal (Opcional)',
                  icon: Icons.assignment_ind_rounded,
                ),
              ),
            ],
          ),

          // Fila 2: Contacto (flex 5) + Teléfono (flex 5)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _buildTextField(
                  controller: _contactCtrl,
                  label: 'Nombre del contacto (Opcional)',
                  icon: Icons.person_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: _buildTextField(
                  controller: _phoneCtrl,
                  label: 'Teléfono / WhatsApp',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),

          // Fila 3: Correo (flex 5) + Dirección (flex 5)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _buildTextField(
                  controller: _emailCtrl,
                  label: 'Correo electrónico',
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null;
                    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!regex.hasMatch(val.trim())) return 'Correo inválido';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: _buildTextField(
                  controller: _addressCtrl,
                  label: 'Dirección Comercial (Opcional)',
                  icon: Icons.location_on_rounded,
                ),
              ),
            ],
          ),
        ] else ...[
          // Disposición Móvil: Apilada con espaciado ergonómico
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
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null;
                    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!regex.hasMatch(val.trim())) return 'Correo inválido';
                    return null;
                  },
                ),
              ),
            ],
          ),
          _buildTextField(
            controller: _addressCtrl,
            label: 'Dirección (Opcional)',
            icon: Icons.location_on_rounded,
          ),
        ],
      ],
    );

    final actionButtons = BlocConsumer<SuppliersCubit, SuppliersState>(
      listenWhen:
          (previous, current) =>
              current is SupplierSaveSuccess || current is SupplierSaveError,
      listener: (context, state) {
        if (state is SupplierSaveError) {
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.error,
          );
        } else if (state is SupplierSaveSuccess) {
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.success,
          );
          widget.onSaved();
          Navigator.pop(context);
        }
      },
      builder: (context, state) {
        final isLoading = state is SupplierSaving;

        if (isDesktop) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: isLoading ? null : _saveSupplier,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon:
                    isLoading
                        ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _isEditing ? 'Guardar Cambios' : 'Registrar Proveedor',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        }

        return ElevatedButton(
          onPressed: isLoading ? null : _saveSupplier,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.teal,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child:
              isLoading
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
        );
      },
    );

    // --- DISEÑO DESKTOP (Diálogo Corporativo Elegante) ---
    if (isDesktop) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera Desktop con [ESC] y [✕]
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_business_rounded,
                      color: AppColors.tealDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Editar Proveedor' : 'Nuevo Proveedor',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Ingresa los datos fiscales y comerciales del proveedor',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'ESC',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    tooltip: 'Cerrar ventana',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Formulario en 2 Columnas
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Form(key: _formKey, child: formFields),
            ),

            // Footer con botones Cancelar y Guardar
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: actionButtons,
            ),
          ],
        ),
      );
    }

    // --- DISEÑO MÓVIL (Apple HIG BottomSheet con Drag Handle) ---
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
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
                  width: 38,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
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
              const SizedBox(height: 16),
              formFields,
              const SizedBox(height: 12),
              actionButtons,
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
          filled: true,
          fillColor: AppColors.background,
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
