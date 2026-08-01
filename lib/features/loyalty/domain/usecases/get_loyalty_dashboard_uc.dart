import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/loyalty/domain/repositories/loyalty_repository.dart';

@injectable
class GetLoyaltyDashboardUC {
  final LoyaltyRepository repository;

  GetLoyaltyDashboardUC(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(String profileId) async {
    return await repository.getLoyaltyDashboardData(profileId);
  }
}
