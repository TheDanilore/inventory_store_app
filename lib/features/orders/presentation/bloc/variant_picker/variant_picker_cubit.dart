import 'dart:developer' as developer;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'variant_picker_state.dart';

class VariantPickerCubit extends Cubit<VariantPickerState> {
  final ProductsRepository _repository;

  VariantPickerCubit(this._repository) : super(VariantPickerInitial());

  Future<void> loadData(String productId) async {
    emit(VariantPickerLoading());

    try {
      // Parallelize network requests to avoid N+1 latency
      final results = await Future.wait([
        _repository.loadActiveVariants(productId),
        _repository.loadStockByVariant(productId),
      ]);

      final variantsRes = results[0] as dynamic;
      final stockRes = results[1] as dynamic;

      final variantsData = variantsRes.fold((l) {
        developer.log(
          'Error al descargar variantes desde Repositorio',
          error: l.message,
          name: 'VariantPickerCubit',
        );
        throw Exception(l.message);
      }, (r) => r as List<Map<String, dynamic>>);

      final variants = <ProductVariantModel>[];
      for (final v in variantsData) {
        try {
          variants.add(ProductVariantModel.fromJson(v));
        } catch (e, st) {
          developer.log(
            'Error de serialización JSON en variante (id: ${v['id']})',
            error: e,
            stackTrace: st,
            name: 'VariantPickerCubit',
          );
        }
      }

      final stockByVariant = stockRes.fold((l) {
        developer.log(
          'Advertencia: No se pudo obtener el resumen de stock por variante',
          error: l.message,
          name: 'VariantPickerCubit',
        );
        return <String, int>{};
      }, (r) => r as Map<String, int>);

      emit(
        VariantPickerLoaded(
          variants: variants.map((v) => v.toEntity()).toList(),
          stockByVariant: stockByVariant,
        ),
      );
    } catch (e, st) {
      developer.log(
        'Fallo crítico en loadData de VariantPickerCubit',
        error: e,
        stackTrace: st,
        name: 'VariantPickerCubit',
      );
      final errMsg = e.toString().replaceAll('Exception: ', '');
      final isNetworkError =
          errMsg.toLowerCase().contains('socket') ||
          errMsg.toLowerCase().contains('connection') ||
          errMsg.toLowerCase().contains('network') ||
          errMsg.toLowerCase().contains('red');

      emit(
        VariantPickerError(
          isNetworkError
              ? 'No se pudo contactar al servidor. Verifica tu conexión e intenta nuevamente.'
              : 'Error al cargar variantes: $errMsg',
        ),
      );
    }
  }
}
