import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/inventory/data/cache/exit_product_cache.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_exit_product/add_exit_product_state.dart';

/// Cubit para el panel de selección de productos en salidas de inventario.
///
/// ### Estrategia SWR (Stale-While-Revalidate)
/// - Si existe caché → emite los datos instantáneamente sin ningún indicador
///   de carga y luego revalida en segundo plano.
/// - Si no existe caché → emite `isLoading = true` y espera la respuesta de red.
/// - El resultado de la revalidación actualiza la caché y el estado solo si los
///   datos cambiaron (comparación por longitud e IDs).
@injectable
class AddExitProductCubit extends Cubit<AddExitProductState> {
  final ProductsRepository _repository;
  final ExitProductCache _cache;

  int _variantRequestId = 0;
  int _batchRequestId = 0;
  String? _currentProductId;
  String? _currentVariantId;

  AddExitProductCubit(this._repository)
    : _cache = ExitProductCache.instance,
      super(const AddExitProductState());

  // ── Búsqueda de productos ──────────────────────────────────────────────────

  Future<void> searchProducts(String term) async {
    if (term.isEmpty) {
      emit(state.copyWith(searchResults: []));
      return;
    }
    final res = await _repository.searchProductsForEntry(term);
    if (isClosed) return;
    res.fold(
      (l) => emit(state.copyWith(errorMessage: l.message)),
      (r) => emit(state.copyWithNullError(searchResults: r)),
    );
  }

  // ── Variantes + lotes iniciales ────────────────────────────────────────────

  Future<void> loadVariantsAndBatches(
    String productId,
    bool usesBatches,
    String? warehouseId,
  ) async {
    _currentProductId = productId;
    final reqId = ++_variantRequestId;

    final cached = _cache.getVariants(productId);

    if (cached != null) {
      // Si solo tiene 1 variante, intentar recuperar sus lotes de la caché
      List<Map<String, dynamic>> initialBatches = [];
      if (cached.length == 1 && warehouseId != null) {
        initialBatches = _cache.getBatches(cached.first.id, warehouseId) ?? [];
      }

      // Stale-While-Revalidate: servir caché inmediatamente.
      emit(
        state.copyWithNullError(
          isLoadingVariants: false,
          availableVariants: cached,
          availableBatches: initialBatches,
        ),
      );

      // Si tiene una única variante y almacén, revalidar o cargar sus lotes
      if (cached.length == 1 && warehouseId != null) {
        if (initialBatches.isNotEmpty) {
          _revalidateBatches(cached.first.id, warehouseId, initialBatches);
        } else {
          loadBatches(cached.first.id, warehouseId);
        }
      }

      // Revalidar en background sin bloquear la UI.
      _revalidateVariants(productId, usesBatches, warehouseId, cached, reqId);
    } else {
      // Sin caché: mostrar carga normal.
      emit(
        state.copyWithNullError(
          isLoadingVariants: true,
          availableVariants: [],
          availableBatches: [],
        ),
      );
      await _fetchVariants(productId, usesBatches, warehouseId, reqId);
    }
  }

  Future<void> _fetchVariants(
    String productId,
    bool usesBatches,
    String? warehouseId,
    int reqId,
  ) async {
    final res = await _repository.loadActiveVariants(productId);
    if (isClosed ||
        reqId != _variantRequestId ||
        _currentProductId != productId)
      return;
    res.fold(
      (l) {
        developer.log('Error loading variants', error: l.message);
        emit(state.copyWith(isLoadingVariants: false, errorMessage: l.message));
      },
      (r) async {
        final parsed = _parseAndSortVariants(r);
        _cache.putVariants(productId, parsed);

        List<Map<String, dynamic>> batches = [];
        if (parsed.length == 1 && warehouseId != null) {
          batches = await _fetchBatchesRaw(parsed.first.id, warehouseId);
        }

        if (isClosed ||
            reqId != _variantRequestId ||
            _currentProductId != productId)
          return;
        emit(
          state.copyWithNullError(
            isLoadingVariants: false,
            availableVariants: parsed,
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
    List<ProductVariantModel> stale,
    int reqId,
  ) async {
    if (isClosed ||
        reqId != _variantRequestId ||
        _currentProductId != productId)
      return;
    final res = await _repository.loadActiveVariants(productId);
    if (isClosed ||
        reqId != _variantRequestId ||
        _currentProductId != productId)
      return;
    res.fold(
      (l) => developer.log(
        'Revalidation failed for variants $productId',
        error: l.message,
      ),
      (r) async {
        final fresh = _parseAndSortVariants(r);
        _cache.putVariants(productId, fresh);

        // Actualizar UI solo si los datos cambiaron.
        if (_variantsChanged(stale, fresh)) {
          if (isClosed ||
              reqId != _variantRequestId ||
              _currentProductId != productId)
            return;
          List<Map<String, dynamic>> batches = [];
          if (fresh.length == 1 && warehouseId != null) {
            batches = await _fetchBatchesRaw(fresh.first.id, warehouseId);
          }
          if (isClosed ||
              reqId != _variantRequestId ||
              _currentProductId != productId)
            return;
          emit(
            state.copyWithNullError(
              availableVariants: fresh,
              availableBatches: batches,
            ),
          );
        }
      },
    );
  }

  // ── Lotes ──────────────────────────────────────────────────────────────────

  Future<void> loadBatches(String variantId, String warehouseId) async {
    _currentVariantId = variantId;
    final reqId = ++_batchRequestId;

    final cached = _cache.getBatches(variantId, warehouseId);

    if (cached != null) {
      // Servir caché al instante (sin isLoadingBatches = true).
      emit(
        state.copyWithNullError(
          isLoadingBatches: false,
          availableBatches: cached,
        ),
      );
      // Revalidar silenciosamente.
      _revalidateBatches(variantId, warehouseId, cached, reqId);
    } else {
      emit(state.copyWithNullError(isLoadingBatches: true));
      final fresh = await _fetchBatchesRaw(variantId, warehouseId);
      if (isClosed ||
          reqId != _batchRequestId ||
          _currentVariantId != variantId)
        return;
      emit(
        state.copyWithNullError(
          isLoadingBatches: false,
          availableBatches: fresh,
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBatchesRaw(
    String variantId,
    String warehouseId,
  ) async {
    final res = await _repository.getBatchesForVariant(variantId, warehouseId);
    return res.fold(
      (l) {
        developer.log('Error fetching batches $variantId', error: l.message);
        if (!isClosed) {
          emit(
            state.copyWith(isLoadingBatches: false, errorMessage: l.message),
          );
        }
        return <Map<String, dynamic>>[];
      },
      (r) {
        _cache.putBatches(variantId, warehouseId, r);
        return r;
      },
    );
  }

  Future<void> _revalidateBatches(
    String variantId,
    String warehouseId,
    List<Map<String, dynamic>> stale, [
    int? reqId,
  ]) async {
    if (isClosed) return;
    if (reqId != null &&
        (reqId != _batchRequestId || _currentVariantId != variantId))
      return;
    final res = await _repository.getBatchesForVariant(variantId, warehouseId);
    if (isClosed) return;
    if (reqId != null &&
        (reqId != _batchRequestId || _currentVariantId != variantId))
      return;
    res.fold(
      (l) => developer.log(
        'Revalidation failed for batches $variantId',
        error: l.message,
      ),
      (r) {
        _cache.putBatches(variantId, warehouseId, r);
        if (_batchesChanged(stale, r)) {
          if (isClosed) return;
          if (reqId != null &&
              (reqId != _batchRequestId || _currentVariantId != variantId))
            return;
          if (_currentVariantId == null || _currentVariantId == variantId) {
            emit(state.copyWithNullError(availableBatches: r));
          }
        }
      },
    );
  }

  // ── Utilidades ─────────────────────────────────────────────────────────────

  List<ProductVariantModel> _parseAndSortVariants(
    List<Map<String, dynamic>> raw,
  ) {
    final parsed = raw.map(ProductVariantModel.fromJson).toList();
    parsed.sort((a, b) => a.label.compareTo(b.label));
    return parsed;
  }

  bool _variantsChanged(
    List<ProductVariantModel> a,
    List<ProductVariantModel> b,
  ) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return true;
    }
    return false;
  }

  bool _batchesChanged(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      final ka = (a[i]['id'] ?? a[i]['batch_number'] ?? '').toString();
      final kb = (b[i]['id'] ?? b[i]['batch_number'] ?? '').toString();
      if (ka != kb) return true;
      // Comparar también el stock disponible para detectar cambios reales.
      final qa = (a[i]['available_quantity'] as num?)?.toDouble() ?? 0.0;
      final qb = (b[i]['available_quantity'] as num?)?.toDouble() ?? 0.0;
      if ((qa - qb).abs() > 1e-9) return true;
    }
    return false;
  }
}
