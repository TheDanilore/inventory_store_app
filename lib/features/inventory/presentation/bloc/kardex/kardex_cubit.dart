import 'dart:developer' as developer;
import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_kardex_movements_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/export_kardex_pdf_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_state.dart';

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
    String? productId,
    int? page,
    bool clearDateRange = false,
    bool clearProductId = false,
  }) async {
    try {
      final currentState = state is KardexLoaded ? state as KardexLoaded : null;

      final currentTypeFilter = typeFilter ?? currentState?.typeFilter ?? 'ALL';
      final currentSearchText = searchText ?? currentState?.searchText ?? '';
      final currentProductId =
          clearProductId ? null : (productId ?? currentState?.productId);
      final currentPage = page ?? currentState?.currentPage ?? 0;
      final currentStartDate =
          clearDateRange ? null : (startDate ?? currentState?.startDate);
      final currentEndDate =
          clearDateRange ? null : (endDate ?? currentState?.endDate);

      emit(KardexLoading());

      final result = await getKardexMovements.call(
        startDate: currentStartDate,
        endDate: currentEndDate,
        typeFilter: currentTypeFilter,
        searchText: currentSearchText,
        productId: currentProductId,
        page: currentPage,
        pageSize: pageSize,
      );

      final count = result.totalCount;
      final movements = result.movements;
      final totalPages = count > 0 ? (count / pageSize).ceil() : 1;

      emit(
        KardexLoaded(
          movements: movements,
          startDate: currentStartDate,
          endDate: currentEndDate,
          typeFilter: currentTypeFilter,
          searchText: currentSearchText,
          productId: currentProductId,
          currentPage: currentPage,
          totalCount: count,
          totalPages: totalPages,
          isExporting: false,
        ),
      );
    } catch (e, st) {
      developer.log('Error loading kardex', error: e, stackTrace: st);
      if (e is SocketException || e is TimeoutException) {
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
    if (state is KardexLoaded && (state as KardexLoaded).typeFilter == type) {
      return;
    }
    loadMovements(typeFilter: type, page: 0);
  }

  void setSearchText(String text) {
    if (state is KardexLoaded && (state as KardexLoaded).searchText == text) {
      return;
    }
    // Si el usuario borra la búsqueda o escribe texto libre, limpiamos el productId
    final clearProd = text.isEmpty ||
        (state is KardexLoaded && (state as KardexLoaded).searchText != text);
    loadMovements(
      searchText: text,
      page: 0,
      clearProductId: clearProd,
    );
  }

  void clearProductFilter() {
    loadMovements(
      searchText: '',
      page: 0,
      clearProductId: true,
    );
  }

  void changePage(int newPage) {
    if (state is KardexLoaded) {
      final currentState = state as KardexLoaded;
      if (newPage < 0 ||
          newPage >= currentState.totalPages ||
          newPage == currentState.currentPage) {
        return;
      }
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
        productId: currentState.productId,
      );
      emit(currentState.copyWith(isExporting: false));
    } catch (e, st) {
      developer.log('Error exporting PDF', error: e, stackTrace: st);
      emit(currentState.copyWith(isExporting: false));
      if (e is SocketException || e is TimeoutException) {
        emit(const KardexError('Sin conexión a internet al exportar PDF.'));
      } else {
        emit(const KardexError('Error al exportar PDF.'));
      }
    }
  }
}
