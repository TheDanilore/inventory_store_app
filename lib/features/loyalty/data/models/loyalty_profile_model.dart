import 'package:inventory_store_app/features/loyalty/domain/entities/loyalty_profile_entity.dart';

class LoyaltyProfileModel {
  final String id;
  final int walletBalance;

  LoyaltyProfileModel({required this.id, required this.walletBalance});

  factory LoyaltyProfileModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyProfileModel(
      id: json['id'] as String,
      walletBalance: (json['wallet_balance'] as num?)?.toInt() ?? 0,
    );
  }

  LoyaltyProfileEntity toEntity() {
    return LoyaltyProfileEntity(id: id, walletBalance: walletBalance);
  }
}
