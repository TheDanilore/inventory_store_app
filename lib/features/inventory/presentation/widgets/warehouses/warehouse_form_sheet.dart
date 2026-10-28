import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/warehouses/warehouses_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/warehouses/warehouses_state.dart';

/// Formulario inteligente adaptable para Almacenes y Tiendas.
/// Muta entre BottomSheet táctil (Móvil) y Diálogo centrado con atajos (Desktop/Tablet).
class WarehouseFormSheet extends StatefulWidget {
  final WarehouseEntity? warehouseToEdit;
  final bool isDialog;
  final VoidCallback? onSaved;

  const WarehouseFormSheet({
    super.key,
    this.warehouseToEdit,
    this.isDialog = false,
    this.onSaved,
  });

  @override
  State<WarehouseFormSheet> createState() => _WarehouseFormSheetState();
}

class _WarehouseFormSheetState extends State<WarehouseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _addressCtrl;
  late final FocusNode _nameFocusNode;
  late final FocusNode _codeFocusNode;
  late final FocusNode _addressFocusNode;
  late bool _isActive;
  late String _type;

  bool get _isEditing => widget.warehouseToEdit != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.warehouseToEdit?.name ?? '');
    _codeCtrl = TextEditingController(text: widget.warehouseToEdit?.code ?? '');
    _addressCtrl = TextEditingController(
      text: widget.warehouseToEdit?.address ?? '',
    );
    _nameFocusNode = FocusNode();
    _codeFocusNode = FocusNode();
    _addressFocusNode = FocusNode();
    _isActive = widget.warehouseToEdit?.isActive ?? true;
    _type = widget.warehouseToEdit?.type ?? 'warehouse';

    if (widget.isDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _addressCtrl.dispose();
    _nameFocusNode.dispose();
    _codeFocusNode.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<WarehousesCubit>();
    final initialLayout =
        widget.warehouseToEdit?.layoutConfig ??
        (_type == 'store'
            ? WarehouseLayoutConfig.generateDefaultStore()
            : _type == 'dark_store'
            ? WarehouseLayoutConfig.generateDefaultDarkStore()
            : WarehouseLayoutConfig.generateDefaultCentral());

    final success = await cubit.saveWarehouse(
      existingWarehouse: widget.warehouseToEdit,
      name: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      isActive: _isActive,
      type: _type,
      code: _codeCtrl.text.trim().isNotEmpty ? _codeCtrl.text.trim() : null,
      layoutConfig: widget.warehouseToEdit != null ? null : initialLayout,
    );

    if (!mounted) return;

    if (success) {
      widget.onSaved?.call();
      Navigator.of(context).pop();
    } else if (cubit.state.errorMessage != null) {
      AppSnackbar.show(
        context,
        message: cubit.state.errorMessage!,
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDesktop = widget.isDialog;

    final content = BlocBuilder<WarehousesCubit, WarehousesState>(
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                isDesktop
                    ? BorderRadius.circular(20)
                    : const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow:
                isDesktop
                    ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                    : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 20,
                isDesktop ? 20 : 12,
                isDesktop ? 24 : 20,
                isDesktop ? 24 : bottomInset + 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- CABECERA ---
                    if (isDesktop)
                      _buildDesktopHeader(context)
                    else
                      _buildMobileHeader(),

                    SizedBox(height: isDesktop ? 20 : 16),

                    // --- SELECTOR: TIPO DE ESTABLECIMIENTO ---
                    _buildFieldLabel(
                      label: 'Tipo de Establecimiento',
                      isRequired: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTypeOption(
                            type: 'store',
                            label: 'Tienda / Sucursal',
                            icon: Icons.storefront_rounded,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTypeOption(
                            type: 'warehouse',
                            label: 'Almacén Central',
                            icon: Icons.warehouse_rounded,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTypeOption(
                            type: 'dark_store',
                            label: 'Dark Store',
                            icon: Icons.bolt_rounded,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // --- CAMPO: CÓDIGO CORTO Y NOMBRE ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel(
                                label: 'Código',
                                isRequired: false,
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _codeCtrl,
                                focusNode: _codeFocusNode,
                                textCapitalization:
                                    TextCapitalization.characters,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      _type == 'store' ? 'TDA-01' : 'ALM-01',
                                  hintStyle: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                                onFieldSubmitted:
                                    (_) => _nameFocusNode.requestFocus(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel(
                                label: 'Nombre comercial',
                                isRequired: true,
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nameCtrl,
                                focusNode: _nameFocusNode,
                                textCapitalization: TextCapitalization.words,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      _type == 'store'
                                          ? 'Ej. Tienda Central, Sucursal Norte'
                                          : 'Ej. Depósito Principal',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                  prefixIcon: Icon(
                                    _type == 'store'
                                        ? Icons.storefront_rounded
                                        : Icons.warehouse_rounded,
                                    color:
                                        _type == 'store'
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFF3B82F6),
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 1.6,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.error,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Ingresa un nombre';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) {
                                  _addressFocusNode.requestFocus();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // --- CAMPO: DIRECCIÓN ---
                    _buildFieldLabel(
                      label: 'Dirección o Ubicación',
                      isRequired: false,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _addressCtrl,
                      focusNode: _addressFocusNode,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      minLines: 1,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Ej. Av. Los Pinos 123, Distrito / Referencia',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 2),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // --- SWITCH: ESTADO ACTIVO ---
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _isActive
                                ? AppColors.successLight.withValues(alpha: 0.25)
                                : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              _isActive
                                  ? AppColors.success.withValues(alpha: 0.3)
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  _isActive
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.pause_circle_rounded,
                              size: 20,
                              color:
                                  _isActive
                                      ? AppColors.successDark
                                      : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isActive
                                      ? 'Almacén Operativo (Activo)'
                                      : 'Almacén Deshabilitado',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        _isActive
                                            ? AppColors.successDark
                                            : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isActive
                                      ? 'Disponible para movimientos, compras y stock'
                                      : 'No disponible para nuevas operaciones',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        _isActive
                                            ? AppColors.successDark.withValues(
                                              alpha: 0.8,
                                            )
                                            : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isActive,
                            onChanged:
                                state.isSaving
                                    ? null
                                    : (val) => setState(() => _isActive = val),
                            activeThumbColor: AppColors.primary,
                            activeTrackColor: AppColors.primaryLight,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isDesktop ? 24 : 20),

                    // --- ACCIONES INFERIORES ---
                    if (isDesktop)
                      _buildDesktopActions(context, state)
                    else
                      _buildMobileActions(state),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (isDesktop) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape):
              () => Navigator.of(context).pop(),
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              _submit,
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): _submit,
        },
        child: Focus(autofocus: true, child: content),
      );
    }

    return content;
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: const Icon(
            Icons.store_mall_directory_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Editar Almacén' : 'Nuevo Almacén',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _isEditing
                    ? 'Actualiza los datos del depósito o punto de venta'
                    : 'Registra un nuevo punto de almacenaje o sucursal',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          tooltip: 'Cerrar (Esc)',
          color: AppColors.textSecondary,
          onPressed: () => Navigator.of(context).pop(),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF1F5F9),
            hoverColor: const Color(0xFFE2E8F0),
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(34, 34),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      children: [
        // Drag Handle para iOS / Android
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _isEditing ? 'Editar Almacén' : 'Nuevo Almacén',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel({required String label, required bool isRequired}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopActions(BuildContext context, WarehousesState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: state.isSaving ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Cancelar',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: state.isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon:
              state.isSaving
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Icon(Icons.check_rounded, size: 18),
          label: Text(
            state.isSaving
                ? 'Guardando...'
                : (_isEditing ? 'Guardar Cambios' : 'Crear Almacén'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileActions(WarehousesState state) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: state.isSaving ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon:
            state.isSaving
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : const Icon(Icons.check_rounded, size: 18),
        label: Text(
          state.isSaving
              ? 'Guardando...'
              : (_isEditing ? 'Guardar Cambios' : 'Crear Almacén'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required String type,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _type == type;

    return InkWell(
      onTap: () => setState(() => _type = type),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? color.withValues(alpha: 0.12)
                  : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
