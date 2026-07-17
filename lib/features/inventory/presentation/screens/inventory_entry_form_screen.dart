import 'package:flutter/material.dart';
import 'dart:ui' as dart_ui;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form_state.dart';

import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product_sheet.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/po_form_item_tile.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/po_form_summary_card.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryEntryFormScreen extends StatefulWidget {
  final String? purchaseOrderId;
  final List<InventoryEntryItemEntity>? prefillItems;
  final String? prefillSupplierId;
  final String? prefillSupplierName;

  final String? prefillDocumentType;
  final String? prefillDocumentNumber;
  final DateTime? prefillDocumentDate;

  const InventoryEntryFormScreen({
    super.key,
    this.purchaseOrderId,
    this.prefillItems,
    this.prefillSupplierId,
    this.prefillSupplierName,
    this.prefillDocumentType,
    this.prefillDocumentNumber,
    this.prefillDocumentDate,
  });

  @override
  State<InventoryEntryFormScreen> createState() =>
      _InventoryEntryFormScreenState();
}

class _InventoryEntryFormScreenState extends State<InventoryEntryFormScreen> {
  final _documentNumberCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  static const List<String> _docTypes = [
    'NINGUNO',
    'FACTURA',
    'BOLETA',
    'GUIA_REMISION',
    'TICKET',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.prefillDocumentNumber != null) {
      _documentNumberCtrl.text = widget.prefillDocumentNumber!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cubit = context.read<InventoryEntryFormCubit>();

      String? activeShiftId;
      final shiftResp =
          await Supabase.instance.client
              .from('cash_shifts')
              .select('id')
              .eq('status', 'OPEN')
              .maybeSingle();
      if (shiftResp != null) {
        activeShiftId = shiftResp['id'] as String;
      }
      cubit.setActiveShiftId(activeShiftId);

      await cubit.init(
        purchaseOrderId: widget.purchaseOrderId,
        prefillItems: widget.prefillItems,
        prefillSupplierId: widget.prefillSupplierId,
        prefillDocumentType: widget.prefillDocumentType,
        prefillDocumentNumber: widget.prefillDocumentNumber,
        prefillDocumentDate: widget.prefillDocumentDate,
      );
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _documentNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocumentDate(BuildContext context) async {
    final cubit = context.read<InventoryEntryFormCubit>();
    final picked = await showDatePicker(
      context: context,
      initialDate: cubit.state.documentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha del Documento Físico',
    );
    if (picked != null) {
      cubit.setDocumentDate(picked);
    }
  }

  Future<void> _showAddProductSheet(BuildContext context) async {
    final cubit = context.read<InventoryEntryFormCubit>();
    if (cubit.state.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione un almacén destino primero',
        type: SnackbarType.warning,
      );
      return;
    }

    final newItem = await showModalBottomSheet<InventoryEntryItemEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => AddEntryProductSheet(
            warehouseId: cubit.state.selectedWarehouseId,
          ),
    );

    if (newItem != null && mounted) {
      cubit.addItem(newItem);
    }
  }

  Future<void> _handleSave() async {
    final cubit = context.read<InventoryEntryFormCubit>();

    cubit.setDocumentNumber(_documentNumberCtrl.text.trim());

    // Obtenemos el shift activo que seteamos en el initState (que ahora está guardado en el cubit)
    String activeShiftId = "";
    final shiftResp =
        await Supabase.instance.client
            .from('cash_shifts')
            .select('id')
            .eq('status', 'OPEN')
            .maybeSingle();
    if (shiftResp != null) {
      activeShiftId = shiftResp['id'] as String;
      cubit.setActiveShiftId(activeShiftId);
    }

    if (!mounted) return;
    if (!cubit.validate(activeShiftId)) {
      AppSnackbar.show(
        context,
        message: cubit.state.errorMessage,
        type: SnackbarType.error,
      );
      return;
    }

    await cubit.saveEntry(_notesCtrl.text.trim());
    if (!mounted) return;

    if (cubit.state.isSuccess) {
      AppSnackbar.show(
        context,
        message:
            widget.purchaseOrderId != null
                ? 'Recepción registrada. Kardex y Orden actualizados.'
                : 'Ingreso manual registrado correctamente.',
        type: SnackbarType.success,
      );
      Navigator.pop(context, true);
    } else if (cubit.state.errorMessage.isNotEmpty) {
      AppSnackbar.show(
        context,
        message: cubit.state.errorMessage,
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _handleClearDraft() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Descartar Borrador'),
            content: const Text(
              '¿Estás seguro de que quieres limpiar los productos ingresados?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Descartar',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      context.read<InventoryEntryFormCubit>().clearDraft();
      _documentNumberCtrl.clear();
      _notesCtrl.clear();
      AppSnackbar.show(
        context,
        message: 'Borrador descartado',
        type: SnackbarType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final cubit = context.read<InventoryEntryFormCubit>();
        // Si no hay ítems o está guardando, permitimos salir directamente
        if (cubit.state.items.isEmpty ||
            cubit.state.isSaving ||
            widget.purchaseOrderId != null) {
          if (cubit.state.items.isEmpty) cubit.clearDraft();
          Navigator.pop(context, result);
          return;
        }

        final action = await showDialog<String>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Cambios sin guardar'),
                content: const Text(
                  'Tienes un registro en curso. ¿Qué deseas hacer al salir?',
                ),
                actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, 'cancel'),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, 'discard'),
                        child: const Text(
                          'Descartar',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, 'draft'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Borrador'),
                      ),
                    ],
                  ),
                ],
              ),
        );

        if (!context.mounted) return;

        if (action == 'discard') {
          cubit.clearDraft();
          Navigator.pop(context, result);
        } else if (action == 'draft') {
          Navigator.pop(context, result);
        }
      },
      child: BlocBuilder<InventoryEntryFormCubit, InventoryEntryFormState>(
        builder: (context, state) {
          final cubit = context.read<InventoryEntryFormCubit>();
          if (cubit.state.isLoading) {
            return const AdminLayout(
              title: 'Entrada de Inventario',
              showBackButton: true,
              showProfileButton: false,
              showDrawerButton: false,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          return AdminLayout(
            title:
                widget.purchaseOrderId != null
                    ? 'Recepción de Orden'
                    : 'Nueva Entrada Manual',
            showBackButton: true,
            showProfileButton: false,
            showDrawerButton: false,
            body:
                cubit.state.isSaving
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                    : Stack(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isTablet = constraints.maxWidth >= 800;
                            return isTablet
                                ? _buildTabletLayout(context, state, cubit)
                                : _buildMobileLayout(context, state, cubit);
                          },
                        ),
                        _buildBottomActionButton(context, state, cubit),
                      ],
                    ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // LAYOUTS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout(
    BuildContext context,
    InventoryEntryFormState state,
    InventoryEntryFormCubit cubit,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainDataSection(context, state, cubit),
          const SizedBox(height: 16),
          if (widget.purchaseOrderId == null) ...[
            _buildFinanceSection(context, state, cubit),
            const SizedBox(height: 16),
          ],
          _buildDocumentSection(context, state, cubit),
          const SizedBox(height: 16),
          _buildProductsSection(context, state, cubit),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(
    BuildContext context,
    InventoryEntryFormState state,
    InventoryEntryFormCubit cubit,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Settings)
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 12, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainDataSection(context, state, cubit),
                const SizedBox(height: 16),
                if (widget.purchaseOrderId == null) ...[
                  _buildFinanceSection(context, state, cubit),
                  const SizedBox(height: 16),
                ],
                _buildDocumentSection(context, state, cubit),
              ],
            ),
          ),
        ),
        // Right Column (Products)
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 24, 24, 100),
            child: _buildProductsSection(context, state, cubit),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SECTIONS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildMainDataSection(
    BuildContext context,
    InventoryEntryFormState state,
    InventoryEntryFormCubit cubit,
  ) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.storefront_rounded,
            title: 'Datos Principales',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: cubit.state.selectedWarehouseId,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: _dropdownDecoration(
              'Almacén Destino',
              icon: Icons.warehouse_rounded,
            ),
            items:
                cubit.state.warehouses
                    .map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(
                          w.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: cubit.setWarehouse,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: cubit.state.selectedSupplierId,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: _dropdownDecoration(
              'Proveedor (Opcional)',
              icon: Icons.local_shipping_rounded,
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Ninguno (Ajuste/Directo)'),
              ),
              ...cubit.state.suppliers.map(
                (s) => DropdownMenuItem(
                  value: s['id'] as String,
                  child: Text(
                    s['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            onChanged: cubit.setSupplier,
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceSection(
    BuildContext context,
    InventoryEntryFormState state,
    InventoryEntryFormCubit cubit,
  ) {
    final isCredit = cubit.state.paymentMode == 'CRÉDITO';

    return _SectionCard(
      highlightColor: isCredit ? Colors.purple.shade50 : null,
      borderColor: isCredit ? Colors.purple.shade200 : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.payments_rounded,
            title: 'Modo de Pago / Financiamiento',
            iconColor: isCredit ? Colors.purple.shade600 : AppColors.primary,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: cubit.state.paymentMode,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: _dropdownDecoration(
              'Tipo de Operación',
              icon: Icons.money_rounded,
            ),
            items: const [
              DropdownMenuItem(
                value: 'CONTADO',
                child: Text(
                  'Pago al Contado',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DropdownMenuItem(
                value: 'CRÉDITO',
                child: Text(
                  'Compra al Crédito',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              DropdownMenuItem(
                value: 'AJUSTE',
                child: Text(
                  'Ajuste / Sin Costo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            onChanged: (v) {
              if (v != null) cubit.setPaymentMode(v);
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child:
                cubit.state.paymentMode == 'CONTADO'
                    ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: DropdownButtonFormField<String>(
                        initialValue: cubit.state.selectedAccountId,
                        isExpanded: true,
                        icon: const Icon(Icons.expand_more_rounded),
                        decoration: _dropdownDecoration(
                          'Cuenta a debitar',
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                        items:
                            cubit.state.accounts.map((acc) {
                              return DropdownMenuItem(
                                value: acc.id,
                                child: Text(
                                  '${acc.name} (Saldo: S/ ${acc.balance.toStringAsFixed(2)})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }).toList(),
                        onChanged: cubit.setAccount,
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection(
    BuildContext context,
    InventoryEntryFormState state,
    InventoryEntryFormCubit cubit,
  ) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.receipt_long_rounded,
            title: 'Documento Físico',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: cubit.state.documentType,
                  isExpanded: true,
                  icon: const Icon(Icons.expand_more_rounded),
                  decoration: _dropdownDecoration('Tipo Doc.'),
                  items:
                      _docTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(
                                type,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) cubit.setDocumentType(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _documentNumberCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Número / Serie',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DatePickerField(
            label: 'Fecha Emisión',
            value: cubit.state.documentDate,
            onPick: () => _pickDocumentDate(context),
            onClear: () => cubit.setDocumentDate(null),
            icon: Icons.edit_calendar_rounded,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notas adicionales (Opcional)',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(
    BuildContext context,
    InventoryEntryFormState state,
    InventoryEntryFormCubit cubit,
  ) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: _SectionTitle(
                  icon: Icons.inventory_2_rounded,
                  title: 'Productos a Ingresar',
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  if (cubit.state.items.isNotEmpty &&
                      widget.purchaseOrderId == null)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_sweep_rounded,
                        color: AppColors.danger,
                      ),
                      tooltip: 'Descartar borrador',
                      onPressed: _handleClearDraft,
                    ),
                  FilledButton.tonalIcon(
                    onPressed: () => _showAddProductSheet(context),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Agregar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child:
                cubit.state.items.isEmpty
                    ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.border,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.widgets_outlined,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Agrega productos al almacén.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cubit.state.items.length,
                      itemBuilder: (context, index) {
                        return POFormItemTile(
                          item: cubit.state.items[index],
                          onUpdateQuantity: (newQty) {
                            cubit.updateItemQuantity(index, newQty);
                          },
                          onRemove: () => cubit.removeItem(index),
                        );
                      },
                    ),
          ),
          if (cubit.state.items.isNotEmpty) ...[
            const SizedBox(height: 16),
            POFormSummaryCard(items: cubit.state.items),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // FIXED BOTTOM BUTTON
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildBottomActionButton(
    BuildContext context,
    InventoryEntryFormState state,
    InventoryEntryFormCubit cubit,
  ) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.8),
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: cubit.state.items.isEmpty ? null : _handleSave,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text(
                        'Confirmar Ingreso',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // UTILS
  // ════════════════════════════════════════════════════════════════════════════

  InputDecoration _dropdownDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      filled: true,
      fillColor: AppColors.surface,
      prefixIcon:
          icon != null ? Icon(icon, color: AppColors.primary, size: 20) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}

// ── WIDGETS AUXILIARES ──
class _SectionCard extends StatelessWidget {
  final Widget child;
  final Color? highlightColor;
  final Color? borderColor;

  const _SectionCard({
    required this.child,
    this.highlightColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: highlightColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final IconData icon;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value == null
                      ? label
                      : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}',
                  style: TextStyle(
                    color:
                        value == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                    fontWeight:
                        value == null ? FontWeight.normal : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (value != null)
                Tooltip(
                  message: 'Limpiar fecha',
                  child: GestureDetector(
                    onTap: onClear,
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                      size: 20,
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
