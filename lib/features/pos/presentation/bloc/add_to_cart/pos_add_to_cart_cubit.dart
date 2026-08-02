import 'dart:developer' as developer;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'pos_add_to_cart_state.dart';

class PosAddToCartCubit extends Cubit<PosAddToCartState> {
  final ProductsRepository _repository;

  PosAddToCartCubit(this._repository) : super(PosAddToCartInitial());

  Future<void> loadData(ProductEntity product) async {
    emit(PosAddToCartLoading());

    try {
      // Parallelize network requests to avoid N+1 latency in POS
      final results = await Future.wait([
        _repository.fetchVariantsByProductIds([product.id]),
        _repository.loadStockByVariant(product.id),
      ]);

      final variantMapRes = results[0] as dynamic;
      final stockRes = results[1] as dynamic;

      final variantMap = variantMapRes.fold(
        (l) {
          developer.log(
            'Error al descargar variantes para el POS desde Repositorio',
            error: l.message,
            name: 'PosAddToCartCubit',
          );
          throw Exception(l.message);
        },
        (r) => r as Map<String, List<ProductVariantEntity>>,
      );

      final variants = variantMap[product.id] ?? [];

      final stockByVariant = stockRes.fold(
        (l) {
          developer.log(
            'Advertencia: No se pudo cargar el stock del POS por variante',
            error: l.message,
            name: 'PosAddToCartCubit',
          );
          return <String, int>{};
        },
        (r) => r as Map<String, int>,
      );

      ProductVariantEntity? selectedVariant;
      if (variants.isNotEmpty) {
        selectedVariant = variants.firstWhere(
          (v) => (stockByVariant[v.id] ?? 0) > 0,
          orElse: () => variants.first,
        );
      }

      emit(PosAddToCartLoaded(
        variants: variants,
        stockByVariant: stockByVariant,
        selectedVariant: selectedVariant,
        productEntity: product,
      ));
    } catch (e, st) {
      developer.log(
        'Fallo crítico cargando datos del producto en POS',
        error: e,
        stackTrace: st,
        name: 'PosAddToCartCubit',
      );
      final errMsg = e.toString().replaceAll('Exception: ', '');
      final isNetworkError =
          errMsg.toLowerCase().contains('socket') ||
          errMsg.toLowerCase().contains('connection') ||
          errMsg.toLowerCase().contains('network') ||
          errMsg.toLowerCase().contains('red');

      emit(PosAddToCartError(
        isNetworkError
            ? 'Error de red. Verifica tu conexión a internet e intenta nuevamente.'
            : 'Error al cargar datos del producto para POS: $errMsg',
      ));
    }
  }

  void updateQuantity(int newQuantity) {
    if (state is PosAddToCartLoaded) {
      final currentState = state as PosAddToCartLoaded;
      
      final maxStock = currentState.currentStock;
      final finalQuantity = (currentState.hasStockControl && newQuantity > maxStock)
          ? maxStock
          : newQuantity;
          
      if (finalQuantity > 0) {
        emit(currentState.copyWith(quantity: finalQuantity));
      }
    }
  }

  void selectVariant(ProductVariantEntity variant) {
    if (state is PosAddToCartLoaded) {
      final currentState = state as PosAddToCartLoaded;
      emit(currentState.copyWith(
        selectedVariant: variant,
        quantity: 1, // Reset quantity when changing variant
      ));
    }
  }
}
