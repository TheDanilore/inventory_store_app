class FinancialAccountModel {
  final String id;
  final String name;
  final String type;
  final double balance;
  final bool isActive;
  final DateTime? createdAt;

  FinancialAccountModel({
    required this.id,
    required this.name,
    required this.type,
    this.balance = 0.00,
    this.isActive = true,
    this.createdAt,
  });

  factory FinancialAccountModel.fromJson(Map<String, dynamic> json) {
    return FinancialAccountModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      // Manejo seguro del parseo numérico de Supabase
      balance: (json['balance'] as num?)?.toDouble() ?? 0.00,
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String).toLocal()
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty)
        'id': id, // Omitir si es nuevo (para que Supabase genere el UUID)
      'name': name,
      'type': type,
      'balance': balance,
      'is_active': isActive,
      // No solemos enviar created_at en los inserts/updates a menos que sea estrictamente necesario
    };
  }

  FinancialAccountModel copyWith({
    String? id,
    String? name,
    String? type,
    double? balance,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return FinancialAccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
