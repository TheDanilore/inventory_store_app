class CreditMovementModel {
  final String id;
  final String creditId;
  final String? orderId;
  final String movementType; // 'CHARGE' o 'PAYMENT'
  final double amount;
  final String? paymentMethod;
  final String? notes;
  final DateTime? createdAt;
  final String? createdBy;

  CreditMovementModel({
    required this.id,
    required this.creditId,
    this.orderId,
    required this.movementType,
    required this.amount,
    this.paymentMethod,
    this.notes,
    this.createdAt,
    this.createdBy,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory CreditMovementModel.fromJson(Map<String, dynamic> json) {
    return CreditMovementModel(
      id: json['id'] as String,
      creditId: json['credit_id'] as String,
      orderId: json['order_id'] as String?,
      movementType: json['movement_type'] as String,
      // Conversión segura de campos numéricos (numeric de SQL a double de Dart)
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      createdBy: json['created_by'] as String?,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa estructurado para insertar/actualizar en SQL
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'credit_id': creditId,
      'order_id': orderId,
      'movement_type': movementType,
      'amount': amount,
      'payment_method': paymentMethod,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'created_by': createdBy,
    };
  }

  /// Métodos de ayuda semánticos para validar el tipo de movimiento en la UI
  bool get isCharge => movementType == 'CHARGE';
  bool get isPayment => movementType == 'PAYMENT';

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  CreditMovementModel copyWith({
    String? id,
    String? creditId,
    String? orderId,
    String? movementType,
    double? amount,
    String? paymentMethod,
    String? notes,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return CreditMovementModel(
      id: id ?? this.id,
      creditId: creditId ?? this.creditId,
      orderId: orderId ?? this.orderId,
      movementType: movementType ?? this.movementType,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
