import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/loyalty/domain/repositories/loyalty_repository.dart';
import 'package:inventory_store_app/features/loyalty/domain/entities/wallet_movement_entity.dart';

@lazySingleton
class GetTodayMiniGamesUC {
  final LoyaltyRepository repository;

  GetTodayMiniGamesUC(this.repository);

  Future<Either<Failure, List<WalletMovementEntity>>> call(String profileId, String currentDayUtcIso) async {
    return await repository.getTodayMiniGames(profileId, currentDayUtcIso);
  }
}
