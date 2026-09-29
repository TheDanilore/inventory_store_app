import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouses/warehouse_form_modal.dart';
export 'package:inventory_store_app/features/inventory/presentation/widgets/warehouses/warehouse_form_modal.dart';

/// Envoltorio de compatibilidad hacia atrás que delega en [WarehouseFormModal].
class WarehouseFormSheet extends StatelessWidget {
  final WarehouseEntity? warehouse;
  final bool isDialog;
  final VoidCallback? onSaved;

  const WarehouseFormSheet({
    super.key,
    this.warehouse,
    this.isDialog = false,
    this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return WarehouseFormModal(
      warehouseToEdit: warehouse,
      isDialog: isDialog,
      onSaved: onSaved,
    );
  }
}
