import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_movement_model.dart';

class KardexMovementModel {
  final InventoryMovementModel movement;
  final String productName;
  final String warehouseName;
  final String attrsText;
  final String? sku;
  final String batchNumber;
  final bool usesBatches;
  final String? imageUrl;

  KardexMovementModel({
    required this.movement,
    required this.productName,
    required this.warehouseName,
    required this.attrsText,
    this.sku,
    required this.batchNumber,
    required this.usesBatches,
    this.imageUrl,
  });

  bool get isReturn => movement.orderId != null && movement.reason.toUpperCase() == 'RETURN';

  bool get isSale => movement.orderId != null && !isReturn;

  bool get isEntry {
    return movement.inventoryEntryId != null ||
        movement.reason.toUpperCase().contains('INGRESO');
  }

  bool get isExit {
    return movement.inventoryExitId != null;
  }

  String get movementType {
    if (isReturn) return 'DEVOLUCIÓN';
    if (isSale) return 'VENTA';
    if (isEntry) return 'INGRESO';
    if (isExit) return 'SALIDA';

    return movement.reason;
  }

  String? get referenceId {
    return movement.orderId ??
        movement.inventoryEntryId ??
        movement.inventoryExitId ??
        movement.physicalInventoryId;
  }

  factory KardexMovementModel.fromSupabaseRow(Map<String, dynamic> row) {
    final movement = InventoryMovementModel.fromJson(row);

    final variantJson = row['product_variants'] as Map<String, dynamic>?;
    final warehouseJson = row['warehouses'] as Map<String, dynamic>?;
    final batchJson = row['warehouse_stock_batches'] as Map<String, dynamic>?;
    final prodJson = variantJson?['products'] as Map<String, dynamic>?;

    final productName = prodJson?['name']?.toString() ?? 'Producto';
    final usesBatches = prodJson?['uses_batches'] == true;
    final batchNumber = batchJson?['batch_number']?.toString() ?? 'DEFAULT';
    final sku = variantJson?['sku']?.toString();

    // Extracción de atributos relacionales
    final vavList =
        variantJson?['variant_attribute_values'] as List<dynamic>? ?? [];
    final List<String> attrValues = [];
    for (var vav in vavList) {
      final av = vav['attribute_values'] as Map<String, dynamic>?;
      if (av != null && av['value'] != null) {
        attrValues.add(av['value'].toString());
      }
    }
    final attrsText = attrValues.isNotEmpty ? attrValues.join(' · ') : 'Única';

    // Extracción de la imagen (Prioridad: Variante -> Producto)
    String? finalImageUrl;
    final variantImages =
        variantJson?['product_images'] as List<dynamic>? ?? [];
    final prodImages = prodJson?['product_images'] as List<dynamic>? ?? [];

    if (variantImages.isNotEmpty) {
      finalImageUrl = variantImages.first['image_url'] as String?;
    } else if (prodImages.isNotEmpty) {
      try {
        final mainImage = prodImages.cast<Map<String, dynamic>>().firstWhere(
          (img) => img['is_main'] == true,
          orElse: () => prodImages.first as Map<String, dynamic>,
        );
        finalImageUrl = mainImage['image_url'] as String?;
      } catch (_) {
        // En caso de que prodImages esté vacío a pesar de la validación
      }
    }

    return KardexMovementModel(
      movement: movement,
      productName: productName,
      warehouseName: warehouseJson?['name']?.toString() ?? 'Sin almacén',
      attrsText: attrsText,
      sku: sku,
      batchNumber: batchNumber,
      usesBatches: usesBatches,
      imageUrl: finalImageUrl,
    );
  }

  KardexMovementEntity toEntity() {
    return KardexMovementEntity(
      id: movement.id,
      date: movement.createdAt ?? DateTime.now(),
      type: movementType,
      reference: referenceId ?? '',
      description: productName,
      quantity: movement.quantity,
      balance: movement.newStock,
      unitCost: movement.unitCost ?? 0.0,
      totalCost: movement.totalCost ?? 0.0,
      variantId: movement.variantId,
      warehouseId: movement.warehouseId,
    );
  }
}
