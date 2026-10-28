import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/inventory/data/cache/entry_product_cache.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_entry_product/add_entry_product_state.dart';

@injectable
class AddEntryProductCubit extends Cubit<AddEntryProductState> {
  final ProductsRepository _repository;
  final EntryProductCache _cache;
  int _searchRequestId = 0;
  int _variantRequestId = 0;

  AddEntryProductCubit(this._repository)
    : _cache = EntryProductCache.instance,
      super(const AddEntryProductState());

  /// Búsqueda optimizada de productos con caché en memoria y prevención de race conditions.
  Future<Iterable<ProductModel>> searchProducts(String term) async {
    final clean = term.trim();
    if (clean.isEmpty) {
      emit(state.copyWith(searchResults: const []));
      return const Iterable<ProductModel>.empty();
    }

    // 1. Hit de Caché en memoria (Respuesta instantánea: 0ms, 0 egress)
    final cached = _cache.getSearchResults(clean);
    if (cached != null) {
      return cached;
    }

    final reqId = ++_searchRequestId;
    final res = await _repository.searchProductsForEntry(clean);
    if (isClosed || reqId != _searchRequestId) {
      return const Iterable<ProductModel>.empty();
    }

    return res.fold(
      (l) {
        LoggerService.e(
          'Error buscando productos para entrada',
          error: l.message,
          tag: 'AddEntryProductCubit',
        );
        emit(state.copyWith(errorMessage: l.message));
        return const Iterable<ProductModel>.empty();
      },
      (r) {
        final products = r.map((p) => ProductModel.fromJson(p)).toList();
        _cache.putSearchResults(clean, products);
        return products;
      },
    );
  }

  /// Carga de variantes y lotes iniciales aplicando Stale-While-Revalidate (SWR).
  Future<void> loadVariantsAndBatches(
    String productId,
    bool usesBatches,
    String? warehouseId,
  ) async {
    final reqId = ++_variantRequestId;

    // 1. Revisar caché en memoria
    final cachedVariants = _cache.getVariants(productId);

    if (cachedVariants != null) {
      List<Map<String, dynamic>> cachedBatches = [];
      if (cachedVariants.length == 1 && warehouseId != null) {
        cachedBatches =
            _cache.getBatches(cachedVariants.first.id, warehouseId) ?? [];
      }

      // SWR: Emitir caché de inmediato sin parpadeo de carga
      emit(
        state.copyWithNullError(
          isLoadingVariants: false,
          availableVariants: cachedVariants,
          availableBatches: cachedBatches,
        ),
      );

      // Si falta lote o requiere verificación
      if (cachedVariants.length == 1 && warehouseId != null) {
        if (cachedBatches.isNotEmpty) {
          _revalidateBatches(
            cachedVariants.first.id,
            warehouseId,
            cachedBatches,
          );
        } else {
          loadBatches(cachedVariants.first.id, warehouseId);
        }
      }

      // Revalidar variantes silenciosamente en background
      _revalidateVariants(
        productId,
        usesBatches,
        warehouseId,
        cachedVariants,
        reqId,
      );
      return;
    }

    // 2. Cold Start (sin caché): mostrar spinner controlado
    emit(
      state.copyWithNullError(
        isLoadingVariants: true,
        availableVariants: [],
        availableBatches: [],
      ),
    );

    await _fetchVariants(productId, usesBatches, warehouseId, reqId);
  }

  Future<void> _fetchVariants(
    String productId,
    bool usesBatches,
    String? warehouseId,
    int reqId,
  ) async {
    final res = await _repository.loadActiveVariants(productId);
    if (isClosed || reqId != _variantRequestId) return;

    res.fold(
      (l) {
        LoggerService.e(
          'Error cargando variantes',
          error: l.message,
          tag: 'AddEntryProductCubit',
        );
        emit(state.copyWith(isLoadingVariants: false, errorMessage: l.message));
      },
      (r) async {
        final parsedVariants =
            r.map((v) => ProductVariantModel.fromJson(v)).toList()
              ..sort((a, b) => a.label.compareTo(b.label));

        _cache.putVariants(productId, parsedVariants);

        List<Map<String, dynamic>> batches = [];
        if (parsedVariants.length == 1 && usesBatches && warehouseId != null) {
          final batchesRes = await _repository.getBatchesForVariant(
            parsedVariants.first.id,
            warehouseId,
          );
          batchesRes.fold(
            (bl) => emit(state.copyWith(errorMessage: bl.message)),
            (br) {
              batches = br;
              _cache.putBatches(parsedVariants.first.id, warehouseId, br);
            },
          );
        }

        if (isClosed || reqId != _variantRequestId) return;

        emit(
          state.copyWithNullError(
            isLoadingVariants: false,
            availableVariants: parsedVariants,
            availableBatches: batches,
          ),
        );
      },
    );
  }

  Future<void> _revalidateVariants(
    String productId,
    bool usesBatches,
    String? warehouseId,
    List<ProductVariantModel> current,
    int reqId,
  ) async {
    final res = await _repository.loadActiveVariants(productId);
    if (isClosed || reqId != _variantRequestId) return;

    res.fold((_) => null, (r) async {
      final fresh =
          r.map((v) => ProductVariantModel.fromJson(v)).toList()
            ..sort((a, b) => a.label.compareTo(b.label));

      _cache.putVariants(productId, fresh);

      // Si difiere de lo que ya tenemos en pantalla, refrescar silenciosamente
      if (!_areVariantsEqual(current, fresh)) {
        emit(state.copyWithNullError(availableVariants: fresh));
      }
    });
  }

  /// Carga de lotes para una variante específica aplicando SWR.
  Future<void> loadBatches(String variantId, String warehouseId) async {
    final cached = _cache.getBatches(variantId, warehouseId);
    if (cached != null) {
      emit(
        state.copyWithNullError(
          isLoadingBatches: false,
          availableBatches: cached,
        ),
      );
      _revalidateBatches(variantId, warehouseId, cached);
      return;
    }

    emit(state.copyWithNullError(isLoadingBatches: true));
    final res = await _repository.getBatchesForVariant(variantId, warehouseId);
    if (isClosed) return;

    res.fold(
      (l) => emit(
        state.copyWith(isLoadingBatches: false, errorMessage: l.message),
      ),
      (r) {
        _cache.putBatches(variantId, warehouseId, r);
        emit(
          state.copyWithNullError(isLoadingBatches: false, availableBatches: r),
        );
      },
    );
  }

  Future<void> _revalidateBatches(
    String variantId,
    String warehouseId,
    List<Map<String, dynamic>> current,
  ) async {
    final res = await _repository.getBatchesForVariant(variantId, warehouseId);
    if (isClosed) return;

    res.fold((_) => null, (fresh) {
      _cache.putBatches(variantId, warehouseId, fresh);
      if (!_areBatchesEqual(current, fresh)) {
        emit(state.copyWithNullError(availableBatches: fresh));
      }
    });
  }

  bool _areVariantsEqual(
    List<ProductVariantModel> a,
    List<ProductVariantModel> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].label != b[i].label) return false;
    }
    return true;
  }

  bool _areBatchesEqual(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['id'] != b[i]['id'] ||
          a[i]['available_quantity'] != b[i]['available_quantity']) {
        return false;
      }
    }
    return true;
  }

  void clearErrors() {
    if (state.errorMessage != null) {
      emit(state.copyWithNullError());
    }
  }
}
