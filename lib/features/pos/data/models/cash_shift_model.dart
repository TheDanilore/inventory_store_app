class CashShiftModel {
  final String id;
  final String status; // 'OPEN' o 'CLOSED'
  final double openingAmount;
  final double? expectedAmount;
  final double? actualAmount;
  final double? differenceAmount;
  final String? notes;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? accountId;

  // 1. Propiedades para almacenar las relaciones mapeadas por Supabase
  final Map<String, dynamic>? financialAccount;
  final Map<String, dynamic>? openedByProfile;
  final Map<String, dynamic>? closedByProfile;

  CashShiftModel({
    required this.id,
    required this.status,
    required this.openingAmount,
    this.expectedAmount,
    this.actualAmount,
    this.differenceAmount,
    this.notes,
    required this.openedAt,
    this.closedAt,
    this.accountId,
    this.financialAccount,
    this.openedByProfile,
    this.closedByProfile,
  });

  // 2. Getters útiles para mostrar los nombres en tu interfaz de usuario
  String get accountName =>
      financialAccount?['name'] as String? ?? 'Sin cuenta';
  String get accountType => financialAccount?['type'] as String? ?? '';
  String get openedByName =>
      openedByProfile?['full_name'] as String? ?? 'Desconocido';
  String? get closedByName => closedByProfile?['full_name'] as String?;

  /// 3. Constructor fromJson compatible con los alias de la consulta
  factory CashShiftModel.fromJson(Map<String, dynamic> map) {
    return CashShiftModel(
      id: map['id'] as String? ?? '',
      status: map['status'] as String? ?? 'CLOSED',
      // Mapeo numérico ultra seguro para evitar errores double/int
      openingAmount: (map['opening_amount'] as num?)?.toDouble() ?? 0.0,
      expectedAmount: (map['expected_amount'] as num?)?.toDouble(),
      actualAmount: (map['actual_amount'] as num?)?.toDouble(),
      differenceAmount: (map['difference_amount'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      openedAt:
          map['opened_at'] != null
              ? DateTime.parse(map['opened_at'] as String)
              : DateTime.now(),
      closedAt:
          map['closed_at'] != null
              ? DateTime.parse(map['closed_at'] as String)
              : null,
      accountId: map['account_id'] as String?,

      // Captura de las relaciones utilizando los nombres exactos y alias de la query
      financialAccount: map['financial_accounts'] as Map<String, dynamic>?,
      openedByProfile: map['opened_by_profile'] as Map<String, dynamic>?,
      closedByProfile: map['closed_by_profile'] as Map<String, dynamic>?,
    );
  }

  /// Opcional: Para enviar los datos de vuelta a Supabase al abrir/cerrar caja
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'opening_amount': openingAmount,
      'expected_amount': expectedAmount,
      'actual_amount': actualAmount,
      'difference_amount': differenceAmount,
      'notes': notes,
      'opened_at': openedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'account_id': accountId,
    };
  }
}
