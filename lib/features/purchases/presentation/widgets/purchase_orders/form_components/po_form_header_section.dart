import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'po_form_section_widgets.dart';

class POFormHeaderSection extends StatelessWidget {
  final List<Map<String, dynamic>> suppliers;
  final List<WarehouseModel> warehouses;
  final String? selectedSupplierId;
  final String? selectedWarehouseId;
  final DateTime? dueDate;
  final ValueChanged<String?> onSupplierChanged;
  final ValueChanged<String?> onWarehouseChanged;
  final VoidCallback onPickDueDate;
  final VoidCallback onClearDueDate;

  const POFormHeaderSection({
    super.key,
    required this.suppliers,
    required this.warehouses,
    required this.selectedSupplierId,
    required this.selectedWarehouseId,
    required this.dueDate,
    required this.onSupplierChanged,
    required this.onWarehouseChanged,
    required this.onPickDueDate,
    required this.onClearDueDate,
  });

  @override
  Widget build(BuildContext context) {
    final validSupplierId =
        suppliers.any((s) => s['id'] == selectedSupplierId)
            ? selectedSupplierId
            : null;
    final validWarehouseId =
        warehouses.any((w) => w.id == selectedWarehouseId)
            ? selectedWarehouseId
            : null;

    return POFormSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const POFormSectionTitle(
            icon: Icons.storefront_rounded,
            title: 'Datos de la Orden',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('supplier_$validSupplierId'),
            initialValue: validSupplierId,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: poFormDropdownDecoration(
              'Proveedor (Obligatorio)',
              icon: Icons.local_shipping_rounded,
            ),
            items:
                suppliers
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
            validator:
                (v) => v == null ? 'Por favor selecciona un proveedor' : null,
            onChanged: onSupplierChanged,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('warehouse_$validWarehouseId'),
            initialValue: validWarehouseId,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: poFormDropdownDecoration(
              'Almacén Destino (Obligatorio)',
              icon: Icons.warehouse_rounded,
            ),
            items:
                warehouses
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
            validator:
                (v) => v == null ? 'Por favor selecciona un almacén' : null,
            onChanged: onWarehouseChanged,
          ),
          const SizedBox(height: 16),
          POFormDatePickerField(
            label: 'Fecha Vencimiento (Opcional)',
            value: dueDate,
            onPick: onPickDueDate,
            onClear: onClearDueDate,
            icon: Icons.event_rounded,
          ),
        ],
      ),
    );
  }
}
