import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cart_repository.dart';

class SaveCartParams {
  final String cartType;
  final Map<String, CartItemEntity> items;
  const SaveCartParams({required this.cartType, required this.items});
}

@lazySingleton
class SaveCartUseCase implements UseCase<Unit, SaveCartParams> {
  final CartRepository repository;

  SaveCartUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SaveCartParams params) async {
    return await repository.saveLocalCart(params.cartType, params.items);
  }
}
