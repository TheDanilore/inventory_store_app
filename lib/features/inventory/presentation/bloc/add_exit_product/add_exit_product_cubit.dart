import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_exit_product/add_exit_product_state.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';

@injectable
class AddExitProductCubit extends Cubit<AddExitProductState> {
  final ProductsRepository _repository;

  AddExitProductCubit(this._repository) : super(const AddExitProductState());

  Future<void> searchProducts(String term) async {
    if (term.isEmpty) {
      emit(state.copyWith(searchResults: []));
      return;
    }
    final res = await _repository.searchProductsForEntry(term);
    res.fold(
      (l) => emit(state.copyWith(errorMessage: l.message)),
      (r) => emit(state.copyWithNullError(searchResults: r)),
    );
  }

  Future<void> loadVariantsAndBatches(String productId, bool usesBatches, String? warehouseId) async {
    emit(state.copyWithNullError(isLoadingVariants: true, availableVariants: [], availableBatches: []));

    final res = await _repository.loadActiveVariants(productId);
    res.fold(
      (l) => emit(state.copyWith(isLoadingVariants: false, errorMessage: l.message)),
      (r) async {
        final parsedVariants = r.map((v) {
          if (v['variant_attribute_values'] is List) {
            final Map<String, dynamic> flatAttributes = {};
            for (final vav in v['variant_attribute_values'] as List) {
              if (vav is Map && vav['attribute_values'] is Map) {
                final av = vav['attribute_values'] as Map;
                if (av['attributes'] is Map) {
                  final attr = av['attributes'] as Map;
                  if (attr['name'] != null) {
                    flatAttributes[attr['name'].toString()] = av['value']?.toString() ?? '';
                  }
                }
              }
            }
            v['attributes'] = flatAttributes;
          }
          return ProductVariantModel.fromJson(v);
        }).toList();

        parsedVariants.sort((a, b) => a.label.compareTo(b.label));

        List<Map<String, dynamic>> batches = [];
        if (parsedVariants.length == 1 && usesBatches && warehouseId != null) {
          final batchesRes = await _repository.getBatchesForVariant(parsedVariants.first.id, warehouseId);
          batchesRes.fold(
            (bl) => emit(state.copyWith(errorMessage: bl.message)),
            (br) => batches = br,
          );
        } else if (parsedVariants.length == 1 && !usesBatches) {
           // Si no usa lotes, creamos un lote ficticio 'DEFAULT' o lo manejamos después.
           // Pero en la base de datos de exits se necesita lote. El caso de uso devolverá el lote predeterminado si es necesario.
           final batchesRes = await _repository.getBatchesForVariant(parsedVariants.first.id, warehouseId ?? '');
           batchesRes.fold(
            (bl) => emit(state.copyWith(errorMessage: bl.message)),
            (br) => batches = br,
          );
        }

        emit(state.copyWithNullError(
          isLoadingVariants: false,
          availableVariants: parsedVariants,
          availableBatches: batches,
        ));
      }
    );
  }

  Future<void> loadBatches(String variantId, String warehouseId) async {
    emit(state.copyWithNullError(isLoadingBatches: true));
    final res = await _repository.getBatchesForVariant(variantId, warehouseId);
    res.fold(
      (l) => emit(state.copyWith(isLoadingBatches: false, errorMessage: l.message)),
      (r) => emit(state.copyWithNullError(isLoadingBatches: false, availableBatches: r)),
    );
  }
}
