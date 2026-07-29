import 'package:inventory_store_app/features/loyalty/domain/entities/daily_checkin_entity.dart';

class DailyCheckinModel {
  final String id;
  final String profileId;
  final String checkinDate;
  final int streakDay;
  final int pointsReceived;
  final DateTime createdAt;

  DailyCheckinModel({
    required this.id,
    required this.profileId,
    required this.checkinDate,
    required this.streakDay,
    required this.pointsReceived,
    required this.createdAt,
  });

  factory DailyCheckinModel.fromJson(Map<String, dynamic> json) {
    return DailyCheckinModel(
      id: json['id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      checkinDate: json['checkin_date'] as String? ?? '',
      streakDay: (json['streak_day'] as num?)?.toInt() ?? 1,
      pointsReceived: (json['points_received'] as num?)?.toInt() ?? 0,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'].toString())
              : DateTime.now(),
    );
  }

  DailyCheckinEntity toEntity() {
    return DailyCheckinEntity(
      id: id,
      profileId: profileId,
      checkinDate: checkinDate,
      streakDay: streakDay,
      pointsReceived: pointsReceived,
      createdAt: createdAt,
    );
  }
}
