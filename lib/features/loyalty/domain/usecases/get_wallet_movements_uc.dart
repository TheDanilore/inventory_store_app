import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/loyalty/domain/repositories/loyalty_repository.dart';
import 'package:inventory_store_app/features/loyalty/domain/entities/wallet_movement_entity.dart';

@lazySingleton
class GetWalletMovementsUC {
  final LoyaltyRepository repository;

  GetWalletMovementsUC(this.repository);

  Future<Either<Failure, List<WalletMovementEntity>>> call({
    required String profileId,
    required int limit,
    required int offset,
  }) async {
    return await repository.getWalletMovements(
      profileId: profileId,
      limit: limit,
      offset: offset,
    );
  }
}
