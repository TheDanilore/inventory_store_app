import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/form/components/entry_form_section_card.dart';

/// Tarjeta de datos principales (Almacén destino y Proveedor).
class EntryFormMainDataCard extends StatelessWidget {
  final InventoryEntryFormState state;
  final InventoryEntryFormCubit cubit;
  final String? prefillSupplierName;

  const EntryFormMainDataCard({
    super.key,
    required this.state,
    required this.cubit,
    this.prefillSupplierName,
  });

  @override
  Widget build(BuildContext context) {
    final selectedWhIdRaw = state.selectedWarehouseId;
    final hasWhInList = state.warehouses.any((w) => w.id == selectedWhIdRaw);

    final warehouseItems = <DropdownMenuItem<String>>[
      if (selectedWhIdRaw != null && !hasWhInList)
        DropdownMenuItem<String>(
          value: selectedWhIdRaw,
          child: Text(
            'Almacén de la Orden${!hasWhInList ? ' (inactivo)' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ...state.warehouses.map(
        (w) => DropdownMenuItem(
          value: w.id,
          child: Text(
            w.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ];

    final selectedSupId = state.selectedSupplierId;
    final hasSupInList = state.suppliers.any((s) => s.id == selectedSupId);

    final supplierItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Ninguno (Ajuste/Directo)'),
      ),
      if (selectedSupId != null && !hasSupInList)
        DropdownMenuItem<String?>(
          value: selectedSupId,
          child: Text(
            prefillSupplierName ?? 'Proveedor de Orden',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ...state.suppliers.map(
        (s) => DropdownMenuItem<String?>(
          value: s.id,
          child: Text(
            s.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ];

    return EntryFormSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EntryFormSectionTitle(
            icon: Icons.storefront_rounded,
            title: 'Datos principales',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('wh_${selectedWhIdRaw}_${state.warehouses.length}'),
            initialValue: selectedWhIdRaw,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: entryFormDropdownDecoration(
              'Almacén Destino',
              icon: Icons.warehouse_rounded,
            ),
            hint: const Text(
              'Seleccione almacén destino',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            items: warehouseItems,
            onChanged: cubit.setWarehouse,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Debe seleccionar un almacén destino';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            key: ValueKey('sup_${selectedSupId}_${state.suppliers.length}'),
            initialValue: selectedSupId,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: entryFormDropdownDecoration(
              'Proveedor (Opcional)',
              icon: Icons.local_shipping_rounded,
            ),
            hint: const Text(
              'Seleccione proveedor (opcional)',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            items: supplierItems,
            onChanged: cubit.setSupplier,
            validator: (val) {
              if (state.paymentMode == 'CRÉDITO' &&
                  (val == null || val.isEmpty)) {
                return 'Debe seleccionar un proveedor para compras al crédito';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
