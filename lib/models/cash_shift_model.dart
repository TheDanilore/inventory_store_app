class CashShiftModel {
  final String id;
  final String accountId;
  final String openedBy;
  final String? closedBy;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingAmount;
  final double? expectedAmount;
  final double? actualAmount;
  final double? differenceAmount;
  final String status;
  final String? notes;

  CashShiftModel({
    required this.id,
    required this.accountId,
    required this.openedBy,
    this.closedBy,
    required this.openedAt,
    this.closedAt,
    this.openingAmount = 0.00,
    this.expectedAmount,
    this.actualAmount,
    this.differenceAmount,
    this.status = 'OPEN',
    this.notes,
  });

  factory CashShiftModel.fromJson(Map<String, dynamic> json) {
    return CashShiftModel(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      openedBy: json['opened_by'] as String,
      closedBy: json['closed_by'] as String?,

      openedAt: DateTime.parse(json['opened_at'] as String).toLocal(),
      closedAt:
          json['closed_at'] != null
              ? DateTime.parse(json['closed_at'] as String).toLocal()
              : null,

      // Parseo seguro de num a double para los montos
      openingAmount: (json['opening_amount'] as num?)?.toDouble() ?? 0.00,
      expectedAmount: (json['expected_amount'] as num?)?.toDouble(),
      actualAmount: (json['actual_amount'] as num?)?.toDouble(),
      differenceAmount: (json['difference_amount'] as num?)?.toDouble(),

      status: json['status'] as String? ?? 'OPEN',
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'account_id': accountId,
      'opened_by': openedBy,
      if (closedBy != null) 'closed_by': closedBy,

      // Enviamos en formato ISO-8601 a Supabase
      'opened_at': openedAt.toUtc().toIso8601String(),
      if (closedAt != null) 'closed_at': closedAt!.toUtc().toIso8601String(),

      'opening_amount': openingAmount,
      if (expectedAmount != null) 'expected_amount': expectedAmount,
      if (actualAmount != null) 'actual_amount': actualAmount,
      if (differenceAmount != null) 'difference_amount': differenceAmount,

      'status': status,
      if (notes != null) 'notes': notes,
    };
  }

  CashShiftModel copyWith({
    String? id,
    String? accountId,
    String? openedBy,
    String? closedBy,
    DateTime? openedAt,
    DateTime? closedAt,
    double? openingAmount,
    double? expectedAmount,
    double? actualAmount,
    double? differenceAmount,
    String? status,
    String? notes,
  }) {
    return CashShiftModel(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      openedBy: openedBy ?? this.openedBy,
      closedBy: closedBy ?? this.closedBy,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      openingAmount: openingAmount ?? this.openingAmount,
      expectedAmount: expectedAmount ?? this.expectedAmount,
      actualAmount: actualAmount ?? this.actualAmount,
      differenceAmount: differenceAmount ?? this.differenceAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}
