import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cart_repository.dart';

class ClearCartParams {
  final String cartType;
  final String? profileId; // Si es null, solo limpia local.
  const ClearCartParams({required this.cartType, this.profileId});
}

@lazySingleton
class ClearCartUseCase extends UseCase<Unit, ClearCartParams> {
  final CartRepository repository;

  ClearCartUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ClearCartParams params) async {
    // Primero limpiar local
    final localResult = await repository.clearLocalCart(params.cartType);

    return localResult.fold((l) => left(l), (r) async {
      if (params.profileId != null) {
        return await repository.clearCloudCart(
          params.cartType,
          params.profileId!,
        );
      }
      return right(unit);
    });
  }
}
