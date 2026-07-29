import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/loyalty/domain/entities/loyalty_profile_entity.dart';
import 'package:inventory_store_app/features/loyalty/domain/repositories/loyalty_repository.dart';

@lazySingleton
class GetLoyaltyProfileUC {
  final LoyaltyRepository repository;

  GetLoyaltyProfileUC(this.repository);

  Future<Either<Failure, LoyaltyProfileEntity>> call(String authUserId) async {
    return await repository.getProfileSummary(authUserId);
  }
}
