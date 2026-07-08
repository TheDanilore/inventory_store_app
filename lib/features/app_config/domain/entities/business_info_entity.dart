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

  const BusinessInfoEntity({
    this.id,
    required this.businessName,
    required this.taxId,
    required this.address,
    required this.phone,
    required this.logoUrl,
    required this.loyaltyGlobalEnabled,
    required this.loyaltyCustomerVisible,
  });

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
      ];
}
