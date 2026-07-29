import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

@injectable
class AddProductReviewUseCase {
  final ProductsRepository repository;

  AddProductReviewUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String productId,
    required String profileId,
    required String userName,
    required int rating,
    String? comment,
  }) {
    return repository.addProductReview(
      productId: productId,
      profileId: profileId,
      userName: userName,
      rating: rating,
      comment: comment,
    );
  }
}
