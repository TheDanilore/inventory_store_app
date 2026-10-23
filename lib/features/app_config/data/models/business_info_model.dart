import 'package:inventory_store_app/features/app_config/domain/entities/business_info_entity.dart';

class BusinessInfoModel {
  final String? id;
  final String businessName;
  final String taxId;
  final String address;
  final String phone;
  final String logoUrl;
  final bool loyaltyGlobalEnabled;
  final bool loyaltyCustomerVisible;
  final String cashRegisterMode;

  const BusinessInfoModel({
    this.id,
    required this.businessName,
    required this.taxId,
    required this.address,
    required this.phone,
    required this.logoUrl,
    required this.loyaltyGlobalEnabled,
    required this.loyaltyCustomerVisible,
    this.cashRegisterMode = 'COUNTER',
  });

  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1' || v == 't') return true;
      if (v == 'false' || v == '0' || v == 'f') return false;
    }
    return defaultValue;
  }

  factory BusinessInfoModel.fromMap(Map<String, dynamic> map) {
    return BusinessInfoModel(
      id: map['id']?.toString(),
      businessName: map['business_name']?.toString() ?? 'Sin configurar',
      taxId: map['tax_id']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      logoUrl: map['logo_url']?.toString() ?? '',
      loyaltyGlobalEnabled: _parseBool(
        map['loyalty_global_enabled'],
        defaultValue: false,
      ),
      loyaltyCustomerVisible: _parseBool(
        map['loyalty_customer_visible'],
        defaultValue: false,
      ),
      cashRegisterMode: map['cash_register_mode']?.toString() ?? 'COUNTER',
    );
  }

  factory BusinessInfoModel.fromEntity(BusinessInfoEntity entity) {
    return BusinessInfoModel(
      id: entity.id,
      businessName: entity.businessName,
      taxId: entity.taxId,
      address: entity.address,
      phone: entity.phone,
      logoUrl: entity.logoUrl,
      loyaltyGlobalEnabled: entity.loyaltyGlobalEnabled,
      loyaltyCustomerVisible: entity.loyaltyCustomerVisible,
      cashRegisterMode: entity.cashRegisterMode,
    );
  }

  BusinessInfoEntity toEntity() {
    return BusinessInfoEntity(
      id: id,
      businessName: businessName,
      taxId: taxId,
      address: address,
      phone: phone,
      logoUrl: logoUrl,
      loyaltyGlobalEnabled: loyaltyGlobalEnabled,
      loyaltyCustomerVisible: loyaltyCustomerVisible,
      cashRegisterMode: cashRegisterMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'business_name': businessName,
      'tax_id': taxId.isNotEmpty ? taxId : null,
      'address': address.isNotEmpty ? address : null,
      'phone': phone.isNotEmpty ? phone : null,
      'logo_url': logoUrl.isNotEmpty ? logoUrl : null,
      'loyalty_global_enabled': loyaltyGlobalEnabled,
      'loyalty_customer_visible': loyaltyCustomerVisible,
      'cash_register_mode': cashRegisterMode,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  BusinessInfoModel copyWith({
    String? id,
    String? businessName,
    String? taxId,
    String? address,
    String? phone,
    String? logoUrl,
    bool? loyaltyGlobalEnabled,
    bool? loyaltyCustomerVisible,
    String? cashRegisterMode,
  }) {
    return BusinessInfoModel(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      taxId: taxId ?? this.taxId,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logoUrl: logoUrl ?? this.logoUrl,
      loyaltyGlobalEnabled: loyaltyGlobalEnabled ?? this.loyaltyGlobalEnabled,
      loyaltyCustomerVisible:
          loyaltyCustomerVisible ?? this.loyaltyCustomerVisible,
      cashRegisterMode: cashRegisterMode ?? this.cashRegisterMode,
    );
  }
}
