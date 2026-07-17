import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cart_repository.dart';

class SyncCartParams {
  final String profileId;
  final Map<String, CartItemEntity> localItems;

  const SyncCartParams({
    required this.profileId,
    required this.localItems,
  });
}

@lazySingleton
class SyncCartUseCase implements UseCase<Map<String, CartItemEntity>, SyncCartParams> {
  final CartRepository repository;

  SyncCartUseCase(this.repository);

  @override
  Future<Either<Failure, Map<String, CartItemEntity>>> call(SyncCartParams params) async {
    return await repository.syncCloudCart(params.profileId, params.localItems);
  }
}
