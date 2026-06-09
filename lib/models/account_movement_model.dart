class AccountMovementModel {
  final String id;
  final String accountId;
  final String movementType; // Ej: 'ingreso', 'egreso'
  final double amount;
  final String description;
  final String? referenceType; // Opcional
  final String? referenceId; // Opcional
  final String? cbuserId; // Opcional (created_by)
  final DateTime createdAt;
  final String? shiftId; // Opcional (Turno de caja)

  AccountMovementModel({
    required this.id,
    required this.accountId,
    required this.movementType,
    required this.amount,
    required this.description,
    this.referenceType,
    this.referenceId,
    this.cbuserId,
    required this.createdAt,
    this.shiftId,
  });

  /// Crea una instancia del modelo desde el JSON enviado por Supabase
  factory AccountMovementModel.fromJson(Map<String, dynamic> json) {
    return AccountMovementModel(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      movementType: json['movement_type'] as String? ?? '',
      // Mapeo seguro de numérico a double en Dart
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      cbuserId: json['created_by'] as String?,
      // Mapeo seguro de timestamp a DateTime
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
      shiftId: json['shift_id'] as String?,
    );
  }

  /// Convierte el modelo a un JSON listo para insertar o actualizar en Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'movement_type': movementType,
      'amount': amount,
      'description': description,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'created_by': cbuserId,
      'created_at': createdAt.toIso8601String(),
      'shift_id': shiftId,
    };
  }
}
