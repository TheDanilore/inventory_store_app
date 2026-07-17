import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cart_repository.dart';

@lazySingleton
class SaveCartUseCase implements UseCase<Unit, Map<String, CartItemEntity>> {
  final CartRepository repository;

  SaveCartUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(Map<String, CartItemEntity> params) async {
    return await repository.saveLocalCart(params);
  }
}
