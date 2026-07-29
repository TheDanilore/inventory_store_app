import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/loyalty/domain/repositories/loyalty_repository.dart';

@lazySingleton
class GetWalletBalanceUC {
  final LoyaltyRepository repository;

  GetWalletBalanceUC(this.repository);

  Future<Either<Failure, int>> call(String authUserId) async {
    return await repository.getWalletBalance(authUserId);
  }
}
