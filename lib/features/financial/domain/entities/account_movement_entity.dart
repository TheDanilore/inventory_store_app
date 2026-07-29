/// Entidad inmutable que representa un Movimiento de Cuenta en el dominio.
/// La UI y los casos de uso interactúan exclusivamente con esta clase.
class AccountMovementEntity {
  final String id;
  final String? accountId;
  final String movementType; // Ej: 'INCOME', 'EXPENSE', 'TRANSFER'
  final double amount;
  final String description;
  final String? referenceType;
  final String? referenceId;
  final DateTime createdAt;
  final String? shiftId;

  // Datos desnormalizados de relaciones (read-only, no son FK de escritura)
  final String? accountName;
  final String? accountType;
  final String? createdByName;

  const AccountMovementEntity({
    required this.id,
    this.accountId,
    required this.movementType,
    required this.amount,
    required this.description,
    this.referenceType,
    this.referenceId,
    required this.createdAt,
    this.shiftId,
    this.accountName,
    this.accountType,
    this.createdByName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountMovementEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AccountMovementEntity(id: $id, movementType: $movementType, amount: $amount)';
}
