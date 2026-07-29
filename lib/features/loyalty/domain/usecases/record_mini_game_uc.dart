import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/loyalty/domain/repositories/loyalty_repository.dart';

@lazySingleton
class RecordMiniGameUC {
  final LoyaltyRepository repository;

  RecordMiniGameUC(this.repository);

  Future<Either<Failure, void>> call({
    required String profileId,
    required String movementType,
    required int points,
    required String description,
  }) async {
    return await repository.recordMiniGame(
      profileId: profileId,
      movementType: movementType,
      points: points,
      description: description,
    );
  }
}
