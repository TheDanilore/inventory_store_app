import 'package:equatable/equatable.dart';

class BusinessInfoEntity extends Equatable {
  final String? id;
  final String businessName;
  final String taxId;
  final String address;
  final String phone;
  final String logoUrl;
  final bool loyaltyGlobalEnabled;
  final bool loyaltyCustomerVisible;
  final String
  cashRegisterMode; // 'COUNTER' (por mostrador/sucursal) o 'INDIVIDUAL' (por cajero)

  const BusinessInfoEntity({
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

  bool get isCounterMode => cashRegisterMode != 'INDIVIDUAL';

  BusinessInfoEntity copyWith({
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
    return BusinessInfoEntity(
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

  @override
  List<Object?> get props => [
    id,
    businessName,
    taxId,
    address,
    phone,
    logoUrl,
    loyaltyGlobalEnabled,
    loyaltyCustomerVisible,
    cashRegisterMode,
  ];
}
