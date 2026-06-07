import 'package:inventory_store_app/models/warehouse_model.dart';

class OrderModel {
  final String id;
  final String? customerId;
  final double totalAmount;
  final double totalProfit;
  final String paymentMethod; // 'EFECTIVO', 'TARJETA', 'CREDITO', etc.
  final String status; // 'COMPLETED', 'PENDING', 'CANCELLED', etc.
  final DateTime? createdAt;
  final String? warehouseId;
  final int pointsUsed;
  final int pointsEarned;
  final String customerName;
  final String paymentStatus; // 'PAID', 'PENDING', 'PARTIAL'
  final double amountPaid;
  final DateTime? dueDate;
  final String? createdBy;

  OrderModel({
    required this.id,
    this.customerId,
    this.totalAmount = 0.00,
    this.totalProfit = 0.00,
    this.paymentMethod = 'EFECTIVO',
    this.status = 'COMPLETED',
    this.createdAt,
    this.warehouseId,
    this.pointsUsed = 0,
    this.pointsEarned = 0,
    this.customerName = '',
    this.paymentStatus = 'PAID',
    this.amountPaid = 0.00,
    this.dueDate,
    this.createdBy,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory OrderModel.fromJson(Map<String, dynamic> json) {
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
      paymentStatus: json['payment_status'] as String? ?? 'PAID',
      amountPaid: (json['amount_paid'] as num? ?? 0.00).toDouble(),
      dueDate:
          json['due_date'] != null
              ? DateTime.parse(json['due_date'] as String)
              : null,
      createdBy: json['created_by'] as String?,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa estructurado para insertar/actualizar en SQL
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
    };
  }

  /// Getters de ayuda para control financiero rápido en el POS
  double get pendingAmount => totalAmount - amountPaid;
  bool get isCreditOrder => paymentMethod == 'CREDITO';
  bool get isPendingPayment =>
      paymentStatus == 'PENDING' || paymentStatus == 'PARTIAL';

  get displayCustomerName => customerName.isNotEmpty ? customerName : 'Cliente General';

  get warehouseName => WarehouseModel.warehouseNames[warehouseId] ?? 'Almacén Desconocido';

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  OrderModel copyWith({
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
    );
  }
}
