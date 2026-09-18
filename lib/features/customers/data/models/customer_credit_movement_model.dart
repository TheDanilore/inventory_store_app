import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';

class CustomerCreditMovementModel {
  final String id;
  final String customerCreditId;
  final String? orderId;
  final String movementType; // 'CHARGE' o 'PAYMENT'
  final double amount;
  final String? paymentMethod;
  final String? notes;
  final DateTime? createdAt;
  final String? createdBy;

  final String? createdByName;
  final String? customerName;
  final String? orderPaymentMethod;
  final double? orderTotalAmount;

  final String? orderNumber;

  CustomerCreditMovementModel({
    required this.id,
    required this.customerCreditId,
    this.orderId,
    required this.movementType,
    required this.amount,
    this.paymentMethod,
    this.notes,
    this.createdAt,
    this.createdBy,
    this.createdByName,
    this.customerName,
    this.orderPaymentMethod,
    this.orderTotalAmount,
    this.orderNumber,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory CustomerCreditMovementModel.fromJson(Map<String, dynamic> json) {
    // Mapeo resiliente de responsable (nombre de perfil creador)
    String? createdByName = json['created_by_name'] as String?;
    if (createdByName == null) {
      if (json['profiles'] is Map) {
        createdByName = (json['profiles'] as Map)['full_name'] as String?;
      } else if (json['creator'] is Map) {
        createdByName = (json['creator'] as Map)['full_name'] as String?;
      }
    }

    // Mapeo resiliente de datos de pedido relacionado
    String? customerName = json['customer_name'] as String?;
    String? orderPaymentMethod = json['order_payment_method'] as String?;
    double? orderTotalAmount = (json['order_total_amount'] as num?)?.toDouble();
    String? orderNumber = json['order_number'] as String?;

    if (json['orders'] is Map) {
      final orderMap = json['orders'] as Map;
      customerName ??= orderMap['customer_name'] as String?;
      orderPaymentMethod ??= orderMap['payment_method'] as String?;
      orderTotalAmount ??= (orderMap['total_amount'] as num?)?.toDouble();
      orderNumber ??= orderMap['id']?.toString();
    }

    return CustomerCreditMovementModel(
      id: json['id'] as String,
      customerCreditId: json['customer_credit_id'] as String,
      orderId: json['order_id'] as String?,
      movementType: json['movement_type'] as String,
      // Conversión segura de campos numéricos (numeric de SQL a double de Dart)
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String?,
      notes: json['notes'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String).toLocal()
              : null,
      createdBy: json['created_by'] as String?,
      createdByName: createdByName,
      customerName: customerName,
      orderPaymentMethod: orderPaymentMethod,
      orderTotalAmount: orderTotalAmount,
      orderNumber: orderNumber,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa estructurado para insertar/actualizar en SQL
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_credit_id': customerCreditId,
      'order_id': orderId,
      'movement_type': movementType,
      'amount': amount,
      'payment_method': paymentMethod,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'created_by': createdBy,
      'created_by_name': createdByName,
      'customer_name': customerName,
      'order_payment_method': orderPaymentMethod,
      'order_total_amount': orderTotalAmount,
      'order_number': orderNumber,
    };
  }

  /// Métodos de ayuda semánticos para validar el tipo de movimiento en la UI
  bool get isCharge => movementType == 'CHARGE';
  bool get isPayment => movementType == 'PAYMENT';

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  CustomerCreditMovementModel copyWith({
    String? id,
    String? customerCreditId,
    String? orderId,
    String? movementType,
    double? amount,
    String? paymentMethod,
    String? notes,
    DateTime? createdAt,
    String? createdBy,

    final String? createdByName,
    final String? customerName,
    final String? orderPaymentMethod,
    final double? orderTotalAmount,
    final String? orderNumber,
  }) {
    return CustomerCreditMovementModel(
      id: id ?? this.id,
      customerCreditId: customerCreditId ?? this.customerCreditId,
      orderId: orderId ?? this.orderId,
      movementType: movementType ?? this.movementType,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      customerName: customerName ?? this.customerName,
      orderPaymentMethod: orderPaymentMethod ?? this.orderPaymentMethod,
      orderTotalAmount: orderTotalAmount ?? this.orderTotalAmount,
      orderNumber: orderNumber ?? this.orderNumber,
    );
  }

  CreditMovementEntity toEntity() {
    return CreditMovementEntity(
      id: id,
      customerCreditId: customerCreditId,
      orderId: orderId,
      movementType: movementType,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
      createdAt: createdAt,
      createdBy: createdBy,
      createdByName: createdByName,
      customerName: customerName,
      orderPaymentMethod: orderPaymentMethod,
      orderTotalAmount: orderTotalAmount,
      orderNumber: orderNumber,
    );
  }
}
