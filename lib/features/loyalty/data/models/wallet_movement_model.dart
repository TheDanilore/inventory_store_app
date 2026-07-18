import 'package:inventory_store_app/features/loyalty/domain/entities/wallet_movement_entity.dart';

class WalletMovementModel {
  final String id;
  final String profileId;
  final String movementType;
  final int points;
  final String? description;
  final DateTime createdAt;

  WalletMovementModel({
    required this.id,
    required this.profileId,
    required this.movementType,
    required this.points,
    this.description,
    required this.createdAt,
  });

  factory WalletMovementModel.fromJson(Map<String, dynamic> json) {
    return WalletMovementModel(
      id: json['id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      movementType: json['movement_type'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'].toString())
              : DateTime.now(),
    );
  }

  WalletMovementEntity toEntity() {
    return WalletMovementEntity(
      id: id,
      profileId: profileId,
      movementType: movementType,
      points: points,
      description: description,
      createdAt: createdAt,
    );
  }
}
