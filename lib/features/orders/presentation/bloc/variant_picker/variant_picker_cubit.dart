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

      final variantsData = variantsRes.fold(
        (l) {
          developer.log('Error loading variants', error: l.message, name: 'VariantPickerCubit');
          throw Exception(l.message);
        },
        (r) => r as List<Map<String, dynamic>>,
      );

      final variants = variantsData
          .map((v) => ProductVariantModel.fromJson(v).toEntity())
          .toList();

      final stockByVariant = stockRes.fold(
        (l) {
          developer.log('Error loading stock', error: l.message, name: 'VariantPickerCubit');
          return <String, int>{};
        },
        (r) => r as Map<String, int>,
      );

      emit(VariantPickerLoaded(
        variants: variants,
        stockByVariant: stockByVariant,
      ));
    } catch (e, st) {
      developer.log('Fatal error loading variant data', error: e, stackTrace: st, name: 'VariantPickerCubit');
      emit(const VariantPickerError('No se pudo cargar la información de las variantes. Verifica tu conexión e intenta nuevamente.'));
    }
  }
}
