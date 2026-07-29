import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/loyalty/domain/repositories/loyalty_repository.dart';
import 'package:inventory_store_app/features/loyalty/domain/entities/daily_checkin_entity.dart';

@lazySingleton
class GetTodayCheckinUC {
  final LoyaltyRepository repository;

  GetTodayCheckinUC(this.repository);

  Future<Either<Failure, DailyCheckinEntity?>> call(
    String profileId,
    String todayDate,
  ) async {
    return await repository.getTodayCheckin(profileId, todayDate);
  }
}
