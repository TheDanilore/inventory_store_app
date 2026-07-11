import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_exit_model.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_inventory_exits_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exits_state.dart';

@injectable
class InventoryExitsCubit extends Cubit<InventoryExitsState> {
  final GetInventoryExitsUseCase getExitsUseCase;

  InventoryExitsCubit({
    required this.getExitsUseCase,
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
        dateRange: state.dateRange,
      );

      final dataList = response.data;
      final exits = dataList
          .map((e) => InventoryExitModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final totalRecords = response.count;

      emit(state.copyWith(
        exits: exits,
        totalRecords: totalRecords,
        isLoading: false,
      ));
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        emit(state.copyWith(errorMessage: 'Sin conexión a internet.', isLoading: false));
      } else {
        emit(state.copyWith(errorMessage: 'Error al cargar salidas.', isLoading: false));
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

  void updateDateRange(DateTimeRange? range) {
    emit(state.copyWith(dateRange: range, clearDateRange: range == null));
    loadExits(isRefresh: true);
  }

  void clearFilters() {
    emit(state.copyWith(searchQuery: '', clearDateRange: true));
    loadExits(isRefresh: true);
  }
}
