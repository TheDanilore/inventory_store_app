import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/providers/purchase_order_form_provider.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product_sheet.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/po_form_item_tile.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/po_form_summary_card.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class PurchaseOrderFormScreen extends StatefulWidget {
  const PurchaseOrderFormScreen({super.key});

  @override
  State<PurchaseOrderFormScreen> createState() =>
      _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends State<PurchaseOrderFormScreen> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseOrderFormProvider>().loadCatalogsAndDraft();
    });
  }

  @override
  void dispose() {
    _documentNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate(BuildContext context) async {
    final provider = context.read<PurchaseOrderFormProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          provider.dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Fecha de Entrega o Vencimiento',
    );
    if (picked != null) {
      provider.setDueDate(picked);
    }
  }

  Future<void> _pickDocumentDate(BuildContext context) async {
    final provider = context.read<PurchaseOrderFormProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.documentDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Fecha del Documento FÃ­sico',
    );
    if (picked != null) {
      provider.setDocumentDate(picked);
    }
  }

  Future<void> _showAddProductSheet(BuildContext context) async {
    final provider = context.read<PurchaseOrderFormProvider>();

    // Validar que se haya seleccionado un proveedor primero
    if (provider.selectedSupplierId == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un proveedor antes de agregar productos.',
        type: SnackbarType.warning,
      );
      return;
    }

    // Validar que se haya seleccionado un almacÃ©n de destino
    if (provider.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un almacÃ©n de destino antes de agregar productos.',
        type: SnackbarType.warning,
      );
      return;
    }

    final newItem = await showModalBottomSheet<InventoryEntryItemEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) =>
              AddEntryProductSheet(warehouseId: provider.selectedWarehouseId),
    );

    if (newItem != null && context.mounted) {
      provider.addItem(newItem);
    }
  }

  Future<void> _handleSave() async {
    final provider = context.read<PurchaseOrderFormProvider>();
    final success = await provider.saveOrder(
      documentNumber: _documentNumberCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
    );

    if (success && mounted) {
      AppSnackbar.show(
        context,
        message: 'Orden generada con Ã©xito',
        type: SnackbarType.success,
      );
      Navigator.pop(context, true);
    } else if (mounted && provider.errorMessage.isNotEmpty) {
      AppSnackbar.show(
        context,
        message: provider.errorMessage,
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
              'Â¿EstÃ¡s seguro de que quieres limpiar la orden actual? PerderÃ¡s todos los Ã­tems agregados.',
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
      context.read<PurchaseOrderFormProvider>().clearDraft();
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
    return Consumer<PurchaseOrderFormProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const AdminLayout(
            title: 'Nueva Orden',
            showBackButton: true,
            showProfileButton: false,
            showDrawerButton: false,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            if (provider.items.isEmpty) {
              provider.clearDraft();
              Navigator.pop(context, result);
              return;
            }

            final action = await showDialog<String>(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text('Ã“rden en progreso'),
                    content: const Text(
                      'Tienes productos en la Ã³rden actual. Â¿QuÃ© deseas hacer al salir?',
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
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
              provider.clearDraft();
              Navigator.pop(context, result);
            } else if (action == 'draft') {
              Navigator.pop(context, result);
            }
          },
          child: AdminLayout(
            title: 'Nueva Orden de Compra',
            showBackButton: true,
            showProfileButton: false,
            showDrawerButton: false,
            body:
                provider.isSaving
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 900;

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Izquierda: Datos, Pago, Documento
                              Expanded(
                                flex: 5,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                  ),
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      children: [
                                        _buildHeaderData(provider),
                                        const SizedBox(height: 24),
                                        _buildPaymentData(provider),
                                        const SizedBox(height: 24),
                                        _buildDocumentData(provider),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Derecha: Productos y BotÃ³n Guardar
                              Expanded(
                                flex: 4,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(24.0),
                                        child: _buildProductsData(provider),
                                      ),
                                    ),
                                    _buildStickySaveButton(provider),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        // MÃ³vil
                        return Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHeaderData(provider),
                                    const SizedBox(height: 16),
                                    _buildProductsData(provider),
                                    const SizedBox(height: 16),
                                    _buildPaymentData(provider),
                                    const SizedBox(height: 16),
                                    _buildDocumentData(provider),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ),
                            _buildStickySaveButton(provider),
                          ],
                        );
                      },
                    ),
          ),
        );
      },
    );
  }

  Widget _buildStickySaveButton(PurchaseOrderFormProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                onPressed: provider.items.isEmpty ? null : _handleSave,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'Generar Orden',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }

  Widget _buildHeaderData(PurchaseOrderFormProvider provider) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.storefront_rounded,
            title: 'Datos de la Orden',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: provider.selectedSupplierId,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: _dropdownDecoration(
              'Proveedor (Obligatorio)',
              icon: Icons.local_shipping_rounded,
            ),
            items:
                provider.suppliers
                    .map(
                      (s) => DropdownMenuItem(
                        value: s['id'] as String,
                        child: Text(
                          s['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: provider.setSupplier,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: provider.selectedWarehouseId,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: _dropdownDecoration(
              'AlmacÃ©n Destino (Obligatorio)',
              icon: Icons.warehouse_rounded,
            ),
            items:
                provider.warehouses
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
            onChanged: provider.setWarehouse,
          ),
          const SizedBox(height: 16),
          _DatePickerField(
            label: 'Fecha Vencimiento (Opcional)',
            value: provider.dueDate,
            onPick: () => _pickDueDate(context),
            onClear: () => provider.setDueDate(null),
            icon: Icons.event_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsData(PurchaseOrderFormProvider provider) {
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
                  title: 'Productos a Pedir',
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _showAddProductSheet(context),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Agregar'),
                  ),
                  if (provider.items.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: 'MÃ¡s opciones',
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onSelected: (value) {
                        if (value == 'clear') _handleClearDraft();
                      },
                      itemBuilder:
                          (_) => [
                            const PopupMenuItem(
                              value: 'clear',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_sweep_rounded,
                                    color: AppColors.danger,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Descartar todo',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ],
                              ),
                            ),
                          ],
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (provider.items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_shopping_cart_rounded,
                    size: 52,
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Tu orden estÃ¡ vacÃ­a',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Agrega los productos que necesitas pedir a tu proveedor',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => _showAddProductSheet(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar primer producto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.items.length,
              itemBuilder: (context, index) {
                return POFormItemTile(
                  item: provider.items[index],
                  onUpdateQuantity:
                      (newQty) => provider.updateItemQuantity(index, newQty),
                  onRemove: () => provider.removeItem(index),
                );
              },
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            child:
                provider.items.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: POFormSummaryCard(items: provider.items),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentData(PurchaseOrderFormProvider provider) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.payments_rounded,
            title: 'Condiciones de Pago',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: provider.paymentMode,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: _dropdownDecoration(
              'Modo de Pago',
              icon: Icons.money_rounded,
            ),
            items: const [
              DropdownMenuItem(
                value: 'EFECTIVO',
                child: Text(
                  'Efectivo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DropdownMenuItem(
                value: 'TARJETA',
                child: Text(
                  'Tarjeta / Transferencia',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DropdownMenuItem(
                value: 'CREDITO',
                child: Text(
                  'LÃ­nea de CrÃ©dito',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                provider.setPaymentMode(v);
                if (v == 'CREDITO') {
                  provider.setPaymentStatus('PENDING');
                  provider.setAccount(null);
                }
              }
            },
          ),
          const SizedBox(height: 16),
          if (provider.paymentMode != 'CREDITO') ...[
            DropdownButtonFormField<String>(
              initialValue: provider.paymentStatus,
              icon: const Icon(Icons.expand_more_rounded),
              decoration: _dropdownDecoration(
                'Estado del Pago',
                icon: Icons.hourglass_top_rounded,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'PENDING',
                  child: Text(
                    'Pago Pendiente',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DropdownMenuItem(
                  value: 'PAID',
                  child: Text(
                    'Pago Realizado / Adelantado',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
              onChanged: (v) {
                if (v != null) provider.setPaymentStatus(v);
              },
            ),
            if (provider.paymentStatus == 'PAID') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: provider.selectedAccountId,
                isExpanded: true,
                icon: const Icon(Icons.expand_more_rounded),
                decoration: _dropdownDecoration(
                  'Cuenta Origen',
                  icon: Icons.account_balance_wallet_rounded,
                ),
                items:
                    provider.accounts.map((acc) {
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
                onChanged: provider.setAccount,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentData(PurchaseOrderFormProvider provider) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.receipt_long_rounded,
            title: 'Documento (Opcional)',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: provider.documentType,
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
                    if (v != null) provider.setDocumentType(v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _documentNumberCtrl,
                  decoration: InputDecoration(
                    labelText: 'NÃºmero / Serie',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DatePickerField(
            label: 'Fecha EmisiÃ³n FÃ­sico',
            value: provider.documentDate,
            onPick: () => _pickDocumentDate(context),
            onClear: () => provider.setDocumentDate(null),
            icon: Icons.edit_calendar_rounded,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notas adicionales',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ UTILS UI â”€â”€

InputDecoration _dropdownDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    filled: true,
    fillColor: AppColors.background,
    prefixIcon:
        icon != null ? Icon(icon, color: AppColors.textMuted, size: 20) : null,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
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

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final IconData icon;

  const _DatePickerField({
    required this.label,
    this.value,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 20),
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
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

