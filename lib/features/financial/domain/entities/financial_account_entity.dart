/// Entidad inmutable que representa una Cuenta Financiera en el dominio.
/// La UI y los casos de uso interactúan exclusivamente con esta clase.
class FinancialAccountEntity {
  final String id;
  final String name;
  final String type;
  final double balance;
  final bool isActive;
  final DateTime createdAt;
  final String currencyCode;

  const FinancialAccountEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.isActive,
    required this.createdAt,
    this.currencyCode = 'PEN',
  });

  FinancialAccountEntity copyWith({
    String? id,
    String? name,
    String? type,
    double? balance,
    bool? isActive,
    DateTime? createdAt,
    String? currencyCode,
  }) {
    return FinancialAccountEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinancialAccountEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FinancialAccountEntity(id: $id, name: $name, type: $type, balance: $balance, currency: $currencyCode)';
}
