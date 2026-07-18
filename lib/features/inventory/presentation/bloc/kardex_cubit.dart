import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_kardex_movements_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/export_kardex_pdf_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex_state.dart';

@injectable
class KardexCubit extends Cubit<KardexState> {
  final GetKardexMovementsUseCase getKardexMovements;
  final ExportKardexPdfUseCase exportKardexPdf;
  static const int pageSize = 12;

  KardexCubit({required this.getKardexMovements, required this.exportKardexPdf})
    : super(KardexInitial());

  Future<void> loadMovements({
    DateTime? startDate,
    DateTime? endDate,
    String? typeFilter,
    String? searchText,
    int? page,
    bool clearDateRange = false,
  }) async {
    try {
      final currentState = state is KardexLoaded ? state as KardexLoaded : null;

      final currentTypeFilter = typeFilter ?? currentState?.typeFilter ?? 'ALL';
      final currentSearchText = searchText ?? currentState?.searchText ?? '';
      final currentPage = page ?? currentState?.currentPage ?? 0;
      final currentStartDate =
          clearDateRange ? null : (startDate ?? currentState?.startDate);
      final currentEndDate =
          clearDateRange ? null : (endDate ?? currentState?.endDate);

      emit(KardexLoading());

      final count = await getKardexMovements.count(
        startDate: currentStartDate,
        endDate: currentEndDate,
        typeFilter: currentTypeFilter,
        searchText: currentSearchText,
      );

      final totalPages = (count / pageSize).ceil();

      final movements = await getKardexMovements.call(
        startDate: currentStartDate,
        endDate: currentEndDate,
        typeFilter: currentTypeFilter,
        searchText: currentSearchText,
        page: currentPage,
        pageSize: pageSize,
      );

      emit(
        KardexLoaded(
          movements: movements,
          startDate: currentStartDate,
          endDate: currentEndDate,
          typeFilter: currentTypeFilter,
          searchText: currentSearchText,
          currentPage: currentPage,
          totalCount: count,
          totalPages: totalPages,
          isExporting: false,
        ),
      );
    } catch (e) {
      debugPrint('Error loading kardex: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        emit(const KardexError('Sin conexión a internet.'));
      } else {
        emit(const KardexError('Error al cargar kardex.'));
      }
    }
  }

  void setDateRange(DateTime? startDate, DateTime? endDate) {
    loadMovements(
      startDate: startDate,
      endDate: endDate,
      page: 0,
      clearDateRange: startDate == null && endDate == null,
    );
  }

  void setTypeFilter(String type) {
    if (state is KardexLoaded && (state as KardexLoaded).typeFilter == type)
      return;
    loadMovements(typeFilter: type, page: 0);
  }

  void setSearchText(String text) {
    if (state is KardexLoaded && (state as KardexLoaded).searchText == text)
      return;
    loadMovements(searchText: text, page: 0);
  }

  void changePage(int newPage) {
    if (state is KardexLoaded) {
      final currentState = state as KardexLoaded;
      if (newPage < 0 ||
          newPage >= currentState.totalPages ||
          newPage == currentState.currentPage)
        return;
      loadMovements(page: newPage);
    }
  }

  Future<void> exportToPdf() async {
    if (state is! KardexLoaded) return;
    final currentState = state as KardexLoaded;

    if (currentState.isExporting) return;

    emit(currentState.copyWith(isExporting: true));

    try {
      await exportKardexPdf.call(
        startDate: currentState.startDate,
        endDate: currentState.endDate,
        typeFilter: currentState.typeFilter,
        searchText: currentState.searchText,
      );
      emit(currentState.copyWith(isExporting: false));
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      final errStr = e.toString().toLowerCase();
      emit(currentState.copyWith(isExporting: false));
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        emit(const KardexError('Sin conexión a internet al exportar PDF.'));
      } else {
        emit(const KardexError('Error al exportar PDF.'));
      }
    }
  }
}
