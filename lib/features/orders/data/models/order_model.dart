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
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Extraemos el mapa anidado de perfiles si es que viene en la consulta
    final profilesData =
        json['profiles'] != null && json['profiles'] is Map
            ? Map<String, dynamic>.from(json['profiles'])
            : null;

    return OrderModel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String?,
      totalAmount: (json['total_amount'] as num? ?? 0.00).toDouble(),
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
    };
  }

  double get pendingAmount => totalAmount - amountPaid;
  bool get isCreditOrder =>
      paymentMethod == 'CRÉDITO'; // Ojo con la tilde aquí si lo usas con ella
  bool get isPendingPayment =>
      paymentStatus == 'PENDING' || paymentStatus == 'PARTIAL';

  // CORRECCIÓN: Ahora prioriza el nombre del perfil relacional por encima del nombre manual
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
    );
  }
}
