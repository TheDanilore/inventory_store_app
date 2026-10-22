import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';

class OrderModel extends OrderEntity {
  final WarehouseModel? warehouse;

  const OrderModel({
    required super.id,
    super.customerId,
    super.totalAmount,
    super.totalProfit,
    super.paymentMethod,
    super.status,
    super.createdAt,
    super.warehouseId,
    super.pointsUsed,
    super.pointsEarned,
    super.customerName,
    super.paymentStatus,
    super.amountPaid,
    super.dueDate,
    super.createdBy,
    super.updatedBy,
    super.updatedAt,
    this.warehouse,
    super.warehouseName,
    super.discountAmount,
    super.profileFullName,
    super.profilePhone,
    super.documentType = 'NINGUNO',
    super.documentSeries,
    super.documentNumber,
    super.documentDate,
    super.taxAmount = 0.00,
    super.subtotalAmount = 0.00,
    super.paymentReference,
    super.customerDocumentType,
    super.customerDocumentNumber,
    super.customerAddress,
    super.currencyCode = 'PEN',
    super.exchangeRate = 1.0,
    super.totalAmountBase = 0.00,
    super.subtotalAmountBase = 0.00,
    super.taxAmountBase = 0.00,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Extraemos el mapa anidado de perfiles si es que viene en la consulta
    final profilesData =
        json['profiles'] != null && json['profiles'] is Map
            ? Map<String, dynamic>.from(json['profiles'])
            : null;

    final total = (json['total_amount'] as num? ?? 0.00).toDouble();
    final rate = (json['exchange_rate'] as num? ?? 1.0).toDouble();
    final totalBase =
        (json['total_amount_base'] as num?)?.toDouble() ?? (total * rate);

    return OrderModel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String?,
      totalAmount: total,
      totalProfit: (json['total_profit'] as num? ?? 0.00).toDouble(),
      paymentMethod: json['payment_method'] as String? ?? 'EFECTIVO',
      status: json['status'] as String? ?? 'COMPLETED',
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
      warehouseId: json['warehouse_id'] as String?,
      pointsUsed: (json['points_used'] as num? ?? 0).toInt(),
      pointsEarned: (json['points_earned'] as num? ?? 0).toInt(),
      customerName: json['customer_name'] as String? ?? '',
      paymentStatus: json['payment_status'] as String? ?? 'PENDING',
      amountPaid: (json['amount_paid'] as num? ?? 0.00).toDouble(),
      dueDate:
          json['due_date'] != null
              ? DateTime.parse(json['due_date'] as String)
              : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null,
      warehouse:
          json['warehouses'] != null && json['warehouses'] is Map
              ? WarehouseModel.fromJson(
                Map<String, dynamic>.from(json['warehouses']),
              )
              : null,
      discountAmount: (json['discount_amount'] as num? ?? 0.00).toDouble(),

      // Mapeamos los campos del perfil
      profileFullName: profilesData?['full_name'] as String?,
      profilePhone: profilesData?['phone'] as String?,

      // Mapeamos los campos de comprobante y fiscalidad
      documentType: json['document_type'] as String? ?? 'NINGUNO',
      documentSeries: json['document_series'] as String?,
      documentNumber: json['document_number'] as String?,
      documentDate:
          json['document_date'] != null
              ? DateTime.parse(json['document_date'] as String)
              : null,
      taxAmount: (json['tax_amount'] as num? ?? 0.00).toDouble(),
      subtotalAmount: (json['subtotal_amount'] as num? ?? 0.00).toDouble(),
      paymentReference: json['payment_reference'] as String?,
      customerDocumentType: json['customer_document_type'] as String?,
      customerDocumentNumber: json['customer_document_number'] as String?,
      customerAddress: json['customer_address'] as String?,

      // Multimoneda
      currencyCode: (json['currency_code'] as String? ?? 'PEN').toUpperCase(),
      exchangeRate: rate,
      totalAmountBase: totalBase,
      subtotalAmountBase:
          (json['subtotal_amount_base'] as num? ?? (totalBase / 1.18))
              .toDouble(),
      taxAmountBase:
          (json['tax_amount_base'] as num? ?? (totalBase - (totalBase / 1.18)))
              .toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'total_amount': totalAmount,
      'total_profit': totalProfit,
      'payment_method': paymentMethod,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'warehouse_id': warehouseId,
      'points_used': pointsUsed,
      'points_earned': pointsEarned,
      'customer_name': customerName,
      'payment_status': paymentStatus,
      'amount_paid': amountPaid,
      if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'discount_amount': discountAmount,
      'document_type': documentType,
      'document_series': documentSeries,
      'document_number': documentNumber,
      if (documentDate != null)
        'document_date': documentDate!.toIso8601String(),
      'tax_amount': taxAmount,
      'subtotal_amount': subtotalAmount,
      'payment_reference': paymentReference,
      'customer_document_type': customerDocumentType,
      'customer_document_number': customerDocumentNumber,
      'customer_address': customerAddress,
      'currency_code': currencyCode,
      'exchange_rate': exchangeRate,
      'total_amount_base': totalAmountBase,
      'subtotal_amount_base': subtotalAmountBase,
      'tax_amount_base': taxAmountBase,
    };
  }

  double get pendingAmount => totalAmount - amountPaid;
  bool get isCreditOrder => paymentMethod == 'CRÉDITO';
  bool get isPendingPayment =>
      paymentStatus == 'PENDING' || paymentStatus == 'PARTIAL';

  @override
  String get displayCustomerName {
    if (profileFullName != null && profileFullName!.trim().isNotEmpty) {
      return profileFullName!;
    }
    if (customerName.trim().isNotEmpty) {
      return customerName;
    }
    return 'Cliente General';
  }

  @override
  String get warehouseName => warehouse?.name ?? 'Almacén Desconocido';

  @override
  OrderModel copyWith({
    String? warehouseName,
    String? id,
    String? customerId,
    double? totalAmount,
    double? totalProfit,
    String? paymentMethod,
    String? status,
    DateTime? createdAt,
    String? warehouseId,
    int? pointsUsed,
    int? pointsEarned,
    String? customerName,
    String? paymentStatus,
    double? amountPaid,
    DateTime? dueDate,
    String? createdBy,
    String? updatedBy,
    DateTime? updatedAt,
    WarehouseModel? warehouse,
    double? discountAmount,
    String? profileFullName,
    String? profilePhone,
    String? documentType,
    String? documentSeries,
    String? documentNumber,
    DateTime? documentDate,
    double? taxAmount,
    double? subtotalAmount,
    String? paymentReference,
    String? customerDocumentType,
    String? customerDocumentNumber,
    String? customerAddress,
    String? currencyCode,
    double? exchangeRate,
    double? totalAmountBase,
    double? subtotalAmountBase,
    double? taxAmountBase,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      totalAmount: totalAmount ?? this.totalAmount,
      totalProfit: totalProfit ?? this.totalProfit,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      warehouseId: warehouseId ?? this.warehouseId,
      pointsUsed: pointsUsed ?? this.pointsUsed,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      customerName: customerName ?? this.customerName,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amountPaid: amountPaid ?? this.amountPaid,
      dueDate: dueDate ?? this.dueDate,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      warehouse: warehouse ?? this.warehouse,
      warehouseName: warehouseName ?? this.warehouseName,
      discountAmount: discountAmount ?? this.discountAmount,
      profileFullName: profileFullName ?? this.profileFullName,
      profilePhone: profilePhone ?? this.profilePhone,
      documentType: documentType ?? this.documentType,
      documentSeries: documentSeries ?? this.documentSeries,
      documentNumber: documentNumber ?? this.documentNumber,
      documentDate: documentDate ?? this.documentDate,
      taxAmount: taxAmount ?? this.taxAmount,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      paymentReference: paymentReference ?? this.paymentReference,
      customerDocumentType: customerDocumentType ?? this.customerDocumentType,
      customerDocumentNumber:
          customerDocumentNumber ?? this.customerDocumentNumber,
      customerAddress: customerAddress ?? this.customerAddress,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      totalAmountBase: totalAmountBase ?? this.totalAmountBase,
      subtotalAmountBase: subtotalAmountBase ?? this.subtotalAmountBase,
      taxAmountBase: taxAmountBase ?? this.taxAmountBase,
    );
  }
}
