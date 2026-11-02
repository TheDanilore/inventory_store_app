import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';

class AccountFormWarehouseSelector extends StatelessWidget {
  final String? selectedWarehouseId;
  final List<WarehouseEntity> warehouses;
  final bool isLoading;
  final ValueChanged<String?> onWarehouseChanged;

  const AccountFormWarehouseSelector({
    super.key,
    required this.selectedWarehouseId,
    required this.warehouses,
    required this.isLoading,
    required this.onWarehouseChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final field = dark ? AppColors.darkBackground : AppColors.surface;
    final line = AppColors.brdSubtle(context);
    final title = AppColors.txtPrimary(context);
    final muted = AppColors.txtSecondary(context);

    if (isLoading && warehouses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 3),
      );
    }

    if (warehouses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No hay tiendas activas registradas. Crea una antes de agregar una caja física.',
                style: TextStyle(fontSize: 12.5, color: title),
              ),
            ),
          ],
        ),
      );
    }

    final effectiveValue =
        selectedWarehouseId != null &&
                warehouses.any((w) => w.id == selectedWarehouseId)
            ? selectedWarehouseId
            : warehouses.first.id;

    return DropdownButtonFormField<String>(
      initialValue: effectiveValue,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: 'Selecciona la tienda',
        hintStyle: TextStyle(
          fontSize: 13.5,
          color: AppColors.txtMuted(context),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        filled: true,
        fillColor: field,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        prefixIcon: const Icon(
          Icons.storefront_rounded,
          color: AppColors.teal,
          size: 20,
        ),
        helperText: 'Cada tienda maneja su propio cajón y turnos.',
        helperStyle: TextStyle(fontSize: 11.5, color: muted),
      ),
      items: [
        for (final w in warehouses)
          DropdownMenuItem<String>(
            value: w.id,
            child: Text(
              w.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      onChanged: onWarehouseChanged,
    );
  }
}
