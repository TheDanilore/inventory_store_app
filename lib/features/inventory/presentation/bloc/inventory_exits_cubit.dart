import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_exit_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_inventory_exits_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exits_state.dart';

import 'package:inventory_store_app/features/inventory/domain/usecases/get_exit_items_usecase.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_exit_item_model.dart';

@injectable
class InventoryExitsCubit extends Cubit<InventoryExitsState> {
  final GetInventoryExitsUseCase getExitsUseCase;
  final GetExitItemsUseCase getItemsUseCase;

  InventoryExitsCubit({
    required this.getExitsUseCase,
    required this.getItemsUseCase,
  }) : super(const InventoryExitsState());

  void initLoad() {
    loadExits(isRefresh: true);
  }

  Future<void> loadExits({bool isRefresh = false}) async {
    if (isRefresh) {
      emit(state.copyWith(currentPage: 0));
    }

    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      final response = await getExitsUseCase.call(
        start: (state.currentPage - 1) * state.pageSize,
        end: (state.currentPage * state.pageSize) - 1,
        searchQuery: state.searchQuery,
        startDate: state.startDate,
        endDate: state.endDate,
      );

      final dataList = response.data;
      final exits = List<InventoryExitEntity>.from(dataList);
      final totalRecords = response.count;

      emit(
        state.copyWith(
          exits: exits,
          totalRecords: totalRecords,
          isLoading: false,
        ),
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        emit(
          state.copyWith(
            errorMessage: 'Sin conexión a internet.',
            isLoading: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            errorMessage: 'Error al cargar salidas.',
            isLoading: false,
          ),
        );
      }
    }
  }

  void nextPage() {
    if (state.currentPage < state.totalPages - 1) {
      emit(state.copyWith(currentPage: state.currentPage + 1));
      loadExits();
    }
  }

  void previousPage() {
    if (state.currentPage > 0) {
      emit(state.copyWith(currentPage: state.currentPage - 1));
      loadExits();
    }
  }

  void changePage(int page) {
    if (page >= 0 && page < state.totalPages) {
      emit(state.copyWith(currentPage: page));
      loadExits();
    }
  }

  void updateSearch(String query) {
    emit(state.copyWith(searchQuery: query));
    loadExits(isRefresh: true);
  }

  void updateDateRange(DateTime? startDate, DateTime? endDate) {
    emit(
      state.copyWith(
        startDate: startDate,
        endDate: endDate,
        clearDateRange: startDate == null && endDate == null,
      ),
    );
    loadExits(isRefresh: true);
  }

  void clearFilters() {
    emit(state.copyWith(searchQuery: '', clearDateRange: true));
    loadExits(isRefresh: true);
  }

  Future<List<InventoryExitItemModel>> loadExitItems(String exitId) async {
    try {
      final itemsList = await getItemsUseCase.call(exitId);
      return itemsList.map((r) {
        final prod = r['products'] as Map<String, dynamic>?;
        final variant = r['product_variants'] as Map<String, dynamic>?;
        final variantId = r['variant_id'] as String?;

        final vavList =
            variant?['variant_attribute_values'] as List<dynamic>? ?? [];
        final List<String> attrValues = [];
        for (var vav in vavList) {
          final av = vav['attribute_values'] as Map<String, dynamic>?;
          if (av != null && av['value'] != null) {
            attrValues.add(av['value'].toString());
          }
        }
        final attrsText = attrValues.join(' · ');

        final bool usesBatches = prod?['uses_batches'] == true;

        String? finalImageUrl;
        final imagesList = prod?['product_images'] as List<dynamic>? ?? [];
        if (imagesList.isNotEmpty) {
          final variantImage = imagesList
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (img) => img['variant_id'] == variantId,
                orElse: () => <String, dynamic>{},
              );
          if (variantImage.isNotEmpty && variantImage['image_url'] != null) {
            finalImageUrl = variantImage['image_url'] as String;
          } else {
            final mainImage = imagesList
                .cast<Map<String, dynamic>>()
                .firstWhere(
                  (img) => img['is_main'] == true,
                  orElse: () => imagesList.first as Map<String, dynamic>,
                );
            finalImageUrl = mainImage['image_url'] as String?;
          }
        }

        return InventoryExitItemModel(
          id: r['id'] as String? ?? '',
          exitId: exitId,
          productId: prod?['id'] as String? ?? '',
          variantId: variantId ?? '',
          productName: prod?['name'] as String? ?? '—',
          variantAttrs: attrsText.isNotEmpty ? attrsText : 'Única',
          quantity: (r['quantity'] as num).toDouble(),
          unitCost: (r['unit_cost'] as num).toDouble(),
          batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
          usesBatches: usesBatches,
          imageUrl: finalImageUrl,
          sku: variant?['sku'] as String?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
