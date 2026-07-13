import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/loyalty/domain/entities/loyalty_profile_entity.dart';
import 'package:inventory_store_app/features/loyalty/domain/entities/daily_checkin_entity.dart';
import 'package:inventory_store_app/features/loyalty/domain/entities/wallet_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

abstract class LoyaltyRepository {
  Future<Either<Failure, LoyaltyProfileEntity>> getProfileSummary(String authUserId);
  
  Future<Either<Failure, int>> getWalletBalance(String authUserId);
  
  Future<Either<Failure, DailyCheckinEntity?>> getTodayCheckin(String profileId, String todayDate);
  
  Future<Either<Failure, DailyCheckinEntity?>> getLatestCheckin(String profileId);
  
  Future<Either<Failure, List<WalletMovementEntity>>> getTodayMiniGames(String profileId, String currentDayUtcIso);
  
  Future<Either<Failure, List<WalletMovementEntity>>> getWalletMovements({
    required String profileId,
    required int limit,
    required int offset,
  });
  
  Future<Either<Failure, void>> claimDailyCheckin({
    required String profileId,
    required String todayDate,
    required int points,
    required int streakDay,
    required String actionByProfileId,
  });
  
  Future<Either<Failure, void>> recordMiniGame({
    required String profileId,
    required String movementType,
    required int points,
    required String description,
  });

  Future<Either<Failure, List<CustomerEntity>>> getTopCustomers(int limit);
}
