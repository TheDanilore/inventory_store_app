import 'package:inventory_store_app/features/inventory/domain/entities/stock_batch_entity.dart';
class WarehouseStockBatchModel {
  final String id;
  final String variantId;
  final String warehouseId;
  final String batchNumber; // 'DEFAULT' por defecto según tu SQL
  final DateTime? expiryDate;
  final double availableQuantity;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String productId;

  WarehouseStockBatchModel({
    required this.id,
    required this.variantId,
    required this.warehouseId,
    this.batchNumber = 'DEFAULT',
    this.expiryDate,
    this.availableQuantity = 0.0,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    required this.productId,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory WarehouseStockBatchModel.fromJson(Map<String, dynamic> json) {
    return WarehouseStockBatchModel(
      id: json['id'] as String,
      variantId: json['variant_id'] as String,
      warehouseId: json['warehouse_id'] as String,
      batchNumber: json['batch_number'] as String? ?? 'DEFAULT',
      expiryDate:
          json['expiry_date'] != null
              ? DateTime.parse(json['expiry_date'] as String)
              : null,
      // Conversión segura de campos numéricos (numeric de SQL a double de Dart)
      availableQuantity: (json['available_quantity'] as num? ?? 0).toDouble(),
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      productId: json['product_id'] as String,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa estructurado para insertar/actualizar en SQL
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'variant_id': variantId,
      'warehouse_id': warehouseId,
      'batch_number': batchNumber,
      // Se formatea YYYY-MM-DD para columnas de tipo DATE en SQL
      'expiry_date': expiryDate?.toIso8601String().split('T').first,
      'available_quantity': availableQuantity,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'product_id': productId,
    };
  }

  /// Getter útil para validar en la UI si el lote se encuentra agotado
  bool get isOutOfStock => availableQuantity <= 0;

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  WarehouseStockBatchModel copyWith({
    String? id,
    String? variantId,
    String? warehouseId,
    String? batchNumber,
    DateTime? expiryDate,
    double? availableQuantity,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    String? productId,
  }) {
    return WarehouseStockBatchModel(
      id: id ?? this.id,
      variantId: variantId ?? this.variantId,
      warehouseId: warehouseId ?? this.warehouseId,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      productId: productId ?? this.productId,
    );
  }

  StockBatchEntity toEntity() {
    return StockBatchEntity(
      id: id,
      variantId: variantId,
      warehouseId: warehouseId,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      availableQuantity: availableQuantity,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
      productId: productId,
    );
  }
}
