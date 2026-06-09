class AccountMovementModel {
  final String id;
  final String?
  accountId; // Puede ser nulo si no viene en el select de la query
  final String movementType; // Ej: 'ingreso', 'egreso'
  final double amount;
  final String description;
  final String? referenceType;
  final String? referenceId;
  final DateTime createdAt;
  final String? shiftId;

  // 1. Agrega estas dos propiedades para capturar los datos anidados
  final Map<String, dynamic>? financialAccount;
  final Map<String, dynamic>? profile;

  AccountMovementModel({
    required this.id,
    this.accountId,
    required this.movementType,
    required this.amount,
    required this.description,
    this.referenceType,
    this.referenceId,
    required this.createdAt,
    this.shiftId,
    this.financialAccount,
    this.profile,
  });

  // 2. Agrega estos Getters para que funcionen tus filtros en la interfaz
  String? get accountName => financialAccount?['name'] as String?;
  String? get accountType => financialAccount?['type'] as String?;
  String? get userFullName => profile?['full_name'] as String?;
  // Busca el nombre del usuario en el objeto anidado de la relación 'profiles'
  String get createdByName =>
      profile?['full_name'] as String? ?? 'Sistema / Desconocido';

  /// 3. Constructor fromJson actualizado y seguro contra errores de casteo
  factory AccountMovementModel.fromJson(Map<String, dynamic> map) {
    return AccountMovementModel(
      id: map['id'] as String? ?? '',
      accountId: map['account_id'] as String?,
      movementType: map['movement_type'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      referenceType: map['reference_type'] as String?,
      referenceId: map['reference_id'] as String?,
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : DateTime.now(),
      shiftId: map['shift_id'] as String?,

      // Mapeo seguro de los objetos anidados
      financialAccount: map['financial_accounts'] as Map<String, dynamic>?,
      profile: map['profiles'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'movement_type': movementType,
      'amount': amount,
      'description': description,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'created_at': createdAt.toIso8601String(),
      'shift_id': shiftId,
      'financial_accounts': financialAccount,
      'profiles': profile,
    };
  }
}
