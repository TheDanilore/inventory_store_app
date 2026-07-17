import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cart_repository.dart';

@lazySingleton
class LoadCartUseCase implements UseCase<Map<String, CartItemEntity>, NoParams> {
  final CartRepository repository;

  LoadCartUseCase(this.repository);

  @override
  Future<Either<Failure, Map<String, CartItemEntity>>> call(NoParams params) async {
    return await repository.loadLocalCart();
  }
}
