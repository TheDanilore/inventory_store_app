class DailyCheckinEntity {
  final String id;
  final String profileId;
  final String checkinDate;
  final int streakDay;
  final int pointsReceived;
  final DateTime createdAt;

  DailyCheckinEntity({
    required this.id,
    required this.profileId,
    required this.checkinDate,
    required this.streakDay,
    required this.pointsReceived,
    required this.createdAt,
  });
}
