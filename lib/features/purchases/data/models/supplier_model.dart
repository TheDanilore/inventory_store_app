import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';

class SupplierModel extends SupplierEntity {
  const SupplierModel({
    required super.id,
    required super.name,
    super.taxId,
    super.contactName,
    super.phone,
    super.email,
    super.address,
    super.isActive = true,
    super.createdAt,
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
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'tax_id': taxId,
      'contact_name': contactName,
      'phone': phone,
      'email': email,
      'address': address,
      'is_active': isActive,
    };
  }

  @override
  SupplierModel copyWith({
    String? id,
    String? name,
    String? taxId,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    bool? isActive,
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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SupplierStatsModel {
  const SupplierStatsModel._();

  static SupplierStatsEntity fromJson(Map<String, dynamic> json) {
    return SupplierStatsEntity(
      totalSuppliers: (json['totalSuppliers'] as num?)?.toInt() ?? 0,
      activeSuppliers: (json['activeSuppliers'] as num?)?.toInt() ?? 0,
      inactiveSuppliers: (json['inactiveSuppliers'] as num?)?.toInt() ?? 0,
      withTaxIdCount: (json['withTaxIdCount'] as num?)?.toInt() ?? 0,
    );
  }
}
