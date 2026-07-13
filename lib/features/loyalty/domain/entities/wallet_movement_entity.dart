class WalletMovementEntity {
  final String id;
  final String profileId;
  final String movementType;
  final int points;
  final String? description;
  final DateTime createdAt;

  WalletMovementEntity({
    required this.id,
    required this.profileId,
    required this.movementType,
    required this.points,
    this.description,
    required this.createdAt,
  });
}
