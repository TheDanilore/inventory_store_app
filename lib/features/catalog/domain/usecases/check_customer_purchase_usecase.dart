import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

@injectable
class CheckCustomerPurchaseUseCase {
  final ProductsRepository repository;

  CheckCustomerPurchaseUseCase(this.repository);

  Future<Either<Failure, bool>> call({
    required String productId,
    required String profileId,
  }) {
    return repository.checkCustomerPurchase(productId, profileId);
  }
}