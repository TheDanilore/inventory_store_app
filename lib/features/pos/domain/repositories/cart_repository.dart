import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';

abstract class CartRepository {
  /// Carga el carrito desde el almacenamiento local.
  Future<Either<Failure, Map<String, CartItemEntity>>> loadLocalCart(String cartType);

  /// Guarda el carrito en el almacenamiento local.
  Future<Either<Failure, Unit>> saveLocalCart(String cartType, Map<String, CartItemEntity> items);

  /// Limpia el carrito local.
  Future<Either<Failure, Unit>> clearLocalCart(String cartType);

  /// Sincroniza el carrito con la base de datos en la nube.
  Future<Either<Failure, Map<String, CartItemEntity>>> syncCloudCart(
      String cartType, String profileId, Map<String, CartItemEntity> localItems);

  /// Limpia el carrito en la nube.
  Future<Either<Failure, Unit>> clearCloudCart(String cartType, String profileId);
}
