import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_entity.dart';

class InventoryEntryModel {
  final String id;
  final String warehouseId;
  final String? supplierId;
  final String? purchaseOrderId;
  final String? notes;
  final double totalAmount;
  final String documentType;
  final String? documentNumber;
  final DateTime? documentDate;
  final String? createdBy;
  final DateTime? createdAt;

  // Campos adicionales útiles al hacer JOIN con otras tablas
  final String? warehouseName;
  final String? supplierName;
  final int itemCount;
  final double totalQuantity;
  final String? paymentMode;
  final String? status;

  // Multimoneda
  final String currencyCode;
  final double exchangeRate;
  final double totalAmountBase;

  InventoryEntryModel({
    required this.id,
    required this.warehouseId,
    this.supplierId,
    this.purchaseOrderId,
    this.notes,
    this.totalAmount = 0.0,
    this.documentType = 'NINGUNO',
    this.documentNumber,
    this.documentDate,
    this.createdBy,
    this.createdAt,
    this.warehouseName,
    this.supplierName,
    this.itemCount = 0,
    this.totalQuantity = 0.0,
    this.paymentMode,
    this.status,
    this.currencyCode = 'PEN',
    this.exchangeRate = 1.0,
    this.totalAmountBase = 0.0,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory InventoryEntryModel.fromJson(Map<String, dynamic> json) {
    final wh = json['warehouses'] as Map<String, dynamic>?;
    final sup = json['suppliers'] as Map<String, dynamic>?;
    final itemsList = json['inventory_entry_items'] as List?;

    final double totalQty =
        itemsList?.fold<double>(
          0.0,
          (sum, item) => sum + ((item['quantity'] as num?)?.toDouble() ?? 0.0),
        ) ??
        ((json['total_quantity'] as num?)?.toDouble() ?? 0.0);

    final total = (json['total_amount'] as num?)?.toDouble() ?? 0.0;
    final rate = (json['exchange_rate'] as num?)?.toDouble() ?? 1.0;
    final totalBase =
        (json['total_amount_base'] as num?)?.toDouble() ?? (total * rate);

    return InventoryEntryModel(
      id: json['id'] as String,
      warehouseId: json['warehouse_id'] as String? ?? '',
      supplierId: json['supplier_id'] as String?,
      purchaseOrderId: json['purchase_order_id'] as String?,
      notes: json['notes'] as String?,
      totalAmount: total,
      documentType: json['document_type'] as String? ?? 'NINGUNO',
      documentNumber: json['document_number'] as String?,
      documentDate:
          json['document_date'] != null
              ? DateTime.tryParse(json['document_date'] as String)
              : null,
      createdBy: json['created_by'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String)
              : null,
      warehouseName: wh?['name'] as String?,
      supplierName: sup?['name'] as String?,
      itemCount: itemsList?.length ?? (json['item_count'] as int? ?? 0),
      totalQuantity: totalQty,
      paymentMode: json['payment_mode'] as String?,
      status: json['status'] as String?,
      currencyCode: (json['currency_code'] as String? ?? 'PEN').toUpperCase(),
      exchangeRate: rate,
      totalAmountBase: totalBase,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa estructurado para insertar/actualizar en SQL
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'warehouse_id': warehouseId,
      if (supplierId != null) 'supplier_id': supplierId,
      if (purchaseOrderId != null) 'purchase_order_id': purchaseOrderId,
      'notes': notes,
      'total_amount': totalAmount,
      'document_type': documentType,
      'document_number': documentNumber,
      if (documentDate != null)
        'document_date': documentDate!.toIso8601String().split('T').first,
      if (paymentMode != null) 'payment_mode': paymentMode,
      if (status != null) 'status': status,
      'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'currency_code': currencyCode,
      'exchange_rate': exchangeRate,
      'total_amount_base': totalAmountBase,
    };
  }

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  InventoryEntryModel copyWith({
    String? id,
    String? warehouseId,
    String? supplierId,
    String? purchaseOrderId,
    String? notes,
    double? totalAmount,
    String? documentType,
    String? documentNumber,
    DateTime? documentDate,
    String? createdBy,
    DateTime? createdAt,
    String? warehouseName,
    String? supplierName,
    int? itemCount,
    double? totalQuantity,
    String? paymentMode,
    String? status,
    String? currencyCode,
    double? exchangeRate,
    double? totalAmountBase,
  }) {
    return InventoryEntryModel(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      supplierId: supplierId ?? this.supplierId,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      notes: notes ?? this.notes,
      totalAmount: totalAmount ?? this.totalAmount,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      documentDate: documentDate ?? this.documentDate,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      warehouseName: warehouseName ?? this.warehouseName,
      supplierName: supplierName ?? this.supplierName,
      itemCount: itemCount ?? this.itemCount,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      paymentMode: paymentMode ?? this.paymentMode,
      status: status ?? this.status,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      totalAmountBase: totalAmountBase ?? this.totalAmountBase,
    );
  }

  factory InventoryEntryModel.fromEntity(InventoryEntryEntity entity) {
    return InventoryEntryModel(
      id: entity.id,
      warehouseId: entity.warehouseId,
      supplierId: entity.supplierId,
      purchaseOrderId: entity.purchaseOrderId,
      notes: entity.notes,
      totalAmount: entity.totalAmount,
      documentType: entity.documentType,
      documentNumber: entity.documentNumber,
      documentDate: entity.documentDate,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
      warehouseName: entity.warehouseName,
      supplierName: entity.supplierName,
      itemCount: entity.itemCount,
      totalQuantity: entity.totalQuantity,
      paymentMode: entity.paymentMode,
      status: entity.status,
      currencyCode: entity.currencyCode,
      exchangeRate: entity.exchangeRate,
      totalAmountBase: entity.totalAmountBase,
    );
  }

  InventoryEntryEntity toEntity() {
    return InventoryEntryEntity(
      id: id,
      warehouseId: warehouseId,
      supplierId: supplierId,
      purchaseOrderId: purchaseOrderId,
      notes: notes,
      totalAmount: totalAmount,
      documentType: documentType,
      documentNumber: documentNumber,
      documentDate: documentDate,
      createdBy: createdBy,
      createdAt: createdAt,
      warehouseName: warehouseName,
      supplierName: supplierName,
      itemCount: itemCount,
      totalQuantity: totalQuantity,
      paymentMode: paymentMode,
      status: status,
      currencyCode: currencyCode,
      exchangeRate: exchangeRate,
      totalAmountBase: totalAmountBase,
    );
  }
}
