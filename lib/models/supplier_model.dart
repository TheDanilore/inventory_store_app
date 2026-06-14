class SupplierModel {
  final String id;
  final String name;
  final String? taxId;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final bool isActive;
  final int paymentTermsDays;
  final double creditLimit;
  final DateTime? createdAt;

  SupplierModel({
    required this.id,
    required this.name,
    this.taxId,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.isActive = true,
    this.paymentTermsDays = 30,
    this.creditLimit = 0.0,
    this.createdAt,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'] as String,
      name: json['name'] as String,
      taxId: json['tax_id'] as String?,
      contactName: json['contact_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      paymentTermsDays: json['payment_terms_days'] as int? ?? 30,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id, // Se omite si está vacío (para inserts)
      'name': name,
      'tax_id': taxId,
      'contact_name': contactName,
      'phone': phone,
      'email': email,
      'address': address,
      'is_active': isActive,
      'payment_terms_days': paymentTermsDays,
      'credit_limit': creditLimit,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  SupplierModel copyWith({
    String? id,
    String? name,
    String? taxId,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    bool? isActive,
    int? paymentTermsDays,
    double? creditLimit,
    DateTime? createdAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      taxId: taxId ?? this.taxId,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      paymentTermsDays: paymentTermsDays ?? this.paymentTermsDays,
      creditLimit: creditLimit ?? this.creditLimit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
