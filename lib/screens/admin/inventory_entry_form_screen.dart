import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/inventory_entry_form_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/add_entry_product_sheet.dart';
import 'package:inventory_store_app/screens/admin/widgets/purchase_orders/po_form_item_tile.dart';
import 'package:inventory_store_app/screens/admin/widgets/purchase_orders/po_form_summary_card.dart';
import 'package:inventory_store_app/models/entry_item_ui.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryEntryFormScreen extends StatefulWidget {
  final String? purchaseOrderId;
  final List<EntryItemUI>? prefillItems;
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
      final provider = context.read<InventoryEntryFormProvider>();

      String? activeShiftId;
      final shiftResp =
          await Supabase.instance.client
              .from('cash_register_shifts')
              .select('id')
              .eq('status', 'OPEN')
              .maybeSingle();
      if (shiftResp != null) {
        activeShiftId = shiftResp['id'] as String;
      }
      provider.setActiveShiftId(activeShiftId);

      await provider.init(
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
    final provider = context.read<InventoryEntryFormProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.documentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha del Documento Físico',
    );
    if (picked != null) {
      provider.setDocumentDate(picked);
    }
  }

  Future<void> _showAddProductSheet(BuildContext context) async {
    final provider = context.read<InventoryEntryFormProvider>();
    if (provider.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione un almacén destino primero',
        type: SnackbarType.warning,
      );
      return;
    }

    final newItem = await showModalBottomSheet<EntryItemUI>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) =>
              AddEntryProductSheet(warehouseId: provider.selectedWarehouseId),
    );

    if (newItem != null && mounted) {
      provider.addItem(newItem);
    }
  }

  Future<void> _handleSave() async {
    final provider = context.read<InventoryEntryFormProvider>();

    provider.setDocumentNumber(_documentNumberCtrl.text.trim());

    // Obtenemos el shift activo que seteamos en el initState (que ahora está guardado en el provider)
    String activeShiftId = "";
    final shiftResp =
        await Supabase.instance.client
            .from('cash_register_shifts')
            .select('id')
            .eq('status', 'OPEN')
            .maybeSingle();
    if (shiftResp != null) {
      activeShiftId = shiftResp['id'] as String;
      provider.setActiveShiftId(activeShiftId);
    }

    if (!provider.validate(activeShiftId)) {
      return;
    }

    final success = await provider.saveEntry(_notesCtrl.text.trim());
    if (success && mounted) {
      AppSnackbar.show(
        context,
        message:
            widget.purchaseOrderId != null
                ? 'Recepción registrada. Kardex y Orden actualizados.'
                : 'Ingreso manual registrado correctamente.',
        type: SnackbarType.success,
      );
      Navigator.pop(context, true);
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
      context.read<InventoryEntryFormProvider>().clearDraft();
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
    return Consumer<InventoryEntryFormProvider>(
      builder: (context, provider, child) {
        if (provider.errorMessage.isNotEmpty && !provider.isSaving) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppSnackbar.show(
              context,
              message: provider.errorMessage,
              type: SnackbarType.error,
            );
          });
        }

        if (provider.isLoading) {
          return const AdminLayout(
            title: 'Entrada de Inventario',
            showBackButton: true,
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
          body:
              provider.isSaving
                  ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                  : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Datos Principales ──────────────────────────────
                              _SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionTitle(
                                      icon: Icons.storefront_rounded,
                                      title: 'Datos Principales',
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      value: provider.selectedWarehouseId,
                                      icon: const Icon(
                                        Icons.expand_more_rounded,
                                      ),
                                      decoration: _dropdownDecoration(
                                        'Almacén Destino',
                                        icon: Icons.warehouse_rounded,
                                      ),
                                      items:
                                          provider.warehouses
                                              .map(
                                                (w) => DropdownMenuItem(
                                                  value: w.id,
                                                  child: Text(
                                                    w.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: provider.setWarehouse,
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      value: provider.selectedSupplierId,
                                      icon: const Icon(
                                        Icons.expand_more_rounded,
                                      ),
                                      decoration: _dropdownDecoration(
                                        'Proveedor (Opcional)',
                                        icon: Icons.local_shipping_rounded,
                                      ),
                                      items: [
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text(
                                            'Ninguno (Ajuste/Directo)',
                                          ),
                                        ),
                                        ...provider.suppliers.map(
                                          (s) => DropdownMenuItem(
                                            value: s['id'] as String,
                                            child: Text(
                                              s['name'] as String,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: provider.setSupplier,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Finanzas (Solo si no viene de PO) ──────────────
                              if (widget.purchaseOrderId == null)
                                _SectionCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _SectionTitle(
                                        icon: Icons.payments_rounded,
                                        title: 'Modo de Pago / Financiamiento',
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String>(
                                        value: provider.paymentMode,
                                        icon: const Icon(
                                          Icons.expand_more_rounded,
                                        ),
                                        decoration: _dropdownDecoration(
                                          'Tipo de Operación',
                                          icon: Icons.money_rounded,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'CONTADO',
                                            child: Text(
                                              'Pago al Contado',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'CREDITO',
                                            child: Text(
                                              'Compra al Crédito',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: (v) {
                                          if (v != null)
                                            provider.setPaymentMode(v);
                                        },
                                      ),
                                      if (provider.paymentMode ==
                                          'CONTADO') ...[
                                        const SizedBox(height: 12),
                                        DropdownButtonFormField<String>(
                                          value: provider.selectedAccountId,
                                          isExpanded: true,
                                          icon: const Icon(
                                            Icons.expand_more_rounded,
                                          ),
                                          decoration: _dropdownDecoration(
                                            'Cuenta a debitar',
                                            icon:
                                                Icons
                                                    .account_balance_wallet_rounded,
                                          ),
                                          items:
                                              provider.accounts.map((acc) {
                                                return DropdownMenuItem(
                                                  value: acc.id,
                                                  child: Text(
                                                    '${acc.name} (Saldo: S/ ${acc.balance.toStringAsFixed(2)})',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                          onChanged: provider.setAccount,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              if (widget.purchaseOrderId == null)
                                const SizedBox(height: 16),

                              // ── Productos ──────────────────────────────
                              _SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const _SectionTitle(
                                          icon: Icons.inventory_2_rounded,
                                          title: 'Productos a Ingresar',
                                        ),
                                        Row(
                                          children: [
                                            if (provider.items.isNotEmpty &&
                                                widget.purchaseOrderId == null)
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_sweep_rounded,
                                                  color: AppColors.danger,
                                                ),
                                                tooltip: 'Descartar borrador',
                                                onPressed: _handleClearDraft,
                                              ),
                                            TextButton.icon(
                                              onPressed:
                                                  () => _showAddProductSheet(
                                                    context,
                                                  ),
                                              icon: const Icon(
                                                Icons
                                                    .add_circle_outline_rounded,
                                                size: 18,
                                              ),
                                              label: const Text('Agregar'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (provider.items.isEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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
                                              color: AppColors.textHint,
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
                                    else
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: provider.items.length,
                                        itemBuilder: (context, index) {
                                          return POFormItemTile(
                                            item: provider.items[index],
                                            onEditQuantity:
                                                () =>
                                                    _mostrarDialogoCantidadItem(
                                                      context,
                                                      index,
                                                      provider
                                                          .items[index]
                                                          .quantity,
                                                    ),
                                            onRemove:
                                                () =>
                                                    provider.removeItem(index),
                                          );
                                        },
                                      ),
                                    if (provider.items.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      POFormSummaryCard(items: provider.items),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ── Documento y Notas ───────────────────────
                              _SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionTitle(
                                      icon: Icons.receipt_long_rounded,
                                      title: 'Documento Físico',
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<
                                            String
                                          >(
                                            value: provider.documentType,
                                            icon: const Icon(
                                              Icons.expand_more_rounded,
                                            ),
                                            decoration: _dropdownDecoration(
                                              'Tipo Doc.',
                                            ),
                                            items:
                                                _docTypes
                                                    .map(
                                                      (
                                                        type,
                                                      ) => DropdownMenuItem(
                                                        value: type,
                                                        child: Text(
                                                          type,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 13,
                                                              ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                            onChanged: (v) {
                                              if (v != null)
                                                provider.setDocumentType(v);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: _documentNumberCtrl,
                                            decoration: InputDecoration(
                                              labelText: 'Número / Serie',
                                              filled: true,
                                              fillColor: AppColors.background,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: const BorderSide(
                                                  color: AppColors.border,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: const BorderSide(
                                                  color: AppColors.border,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _DatePickerField(
                                      label: 'Fecha Emisión',
                                      value: provider.documentDate,
                                      onPick: () => _pickDocumentDate(context),
                                      onClear:
                                          () => provider.setDocumentDate(null),
                                      icon: Icons.edit_calendar_rounded,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _notesCtrl,
                                      maxLines: 3,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Notas adicionales (Opcional)',
                                        filled: true,
                                        fillColor: AppColors.background,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.border,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 100), // padding inferior
                            ],
                          ),
                        ),
                      ),

                      // ── BOTÓN FIJO ──────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      provider.items.isEmpty
                                          ? null
                                          : _handleSave,
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                  ),
                                  label: const Text(
                                    'Confirmar Ingreso',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        );
      },
    );
  }

  Future<void> _mostrarDialogoCantidadItem(
    BuildContext context,
    int index,
    double cantidadActual,
  ) async {
    final qtyCtrl = TextEditingController(
      text: cantidadActual.toStringAsFixed(0),
    );
    final provider = context.read<InventoryEntryFormProvider>();

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(
              'Cantidad a ingresar',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final newQty = double.tryParse(qtyCtrl.text.trim());
                  if (newQty != null) {
                    provider.updateItemQuantity(index, newQty);
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
    qtyCtrl.dispose();
  }

  InputDecoration _dropdownDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      filled: true,
      fillColor: AppColors.background,
      prefixIcon:
          icon != null ? Icon(icon, color: AppColors.textHint, size: 20) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

// ── WIDGETS AUXILIARES ──
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
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
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textHint, size: 20),
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
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textHint,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
