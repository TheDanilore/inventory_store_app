import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/loyalty/domain/repositories/loyalty_repository.dart';


@lazySingleton
class ClaimDailyCheckinUC {
  final LoyaltyRepository repository;

  ClaimDailyCheckinUC(this.repository);

  Future<Either<Failure, void>> call({required String profileId, required String todayDate, required int points, required int streakDay, required String actionByProfileId}) async {
    return await repository.claimDailyCheckin(profileId: profileId, todayDate: todayDate, points: points, streakDay: streakDay, actionByProfileId: actionByProfileId);
  }
}
