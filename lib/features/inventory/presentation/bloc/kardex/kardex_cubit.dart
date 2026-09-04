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
    String? variantId,
    String? variantName,
    String? batchId,
    String? batchNumber,
    int? page,
    bool clearDateRange = false,
    bool clearProductId = false,
    bool clearVariantId = false,
    bool clearBatchId = false,
  }) async {
    try {
      final currentState = state is KardexLoaded ? state as KardexLoaded : null;

      final currentTypeFilter = typeFilter ?? currentState?.typeFilter ?? 'ALL';
      final currentSearchText = searchText ?? currentState?.searchText ?? '';
      final currentProductId =
          clearProductId ? null : (productId ?? currentState?.productId);
      final currentVariantId =
          (clearProductId || clearVariantId) ? null : (variantId ?? currentState?.variantId);
      final currentVariantName =
          (clearProductId || clearVariantId) ? null : (variantName ?? currentState?.variantName);
      final currentBatchId =
          (clearProductId || clearVariantId || clearBatchId) ? null : (batchId ?? currentState?.batchId);
      final currentBatchNumber =
          (clearProductId || clearVariantId || clearBatchId) ? null : (batchNumber ?? currentState?.batchNumber);
      final currentPage = page ?? currentState?.currentPage ?? 0;
      final currentStartDate =
          clearDateRange ? null : (startDate ?? currentState?.startDate);
      final currentEndDate =
          clearDateRange ? null : (endDate ?? currentState?.endDate);

      if (currentState != null) {
        emit(
          currentState.copyWith(
            typeFilter: currentTypeFilter,
            searchText: currentSearchText,
            productId: currentProductId,
            variantId: currentVariantId,
            variantName: currentVariantName,
            batchId: currentBatchId,
            batchNumber: currentBatchNumber,
            currentPage: currentPage,
            startDate: currentStartDate,
            endDate: currentEndDate,
            isSearching: true,
          ),
        );
      } else {
        emit(KardexLoading());
      }

      final result = await getKardexMovements.call(
        startDate: currentStartDate,
        endDate: currentEndDate,
        typeFilter: currentTypeFilter,
        searchText: currentSearchText,
        productId: currentProductId,
        variantId: currentVariantId,
        batchId: currentBatchId,
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
          variantId: currentVariantId,
          variantName: currentVariantName,
          batchId: currentBatchId,
          batchNumber: currentBatchNumber,
          currentPage: currentPage,
          totalCount: count,
          totalPages: totalPages,
          isExporting: false,
          isSearching: false,
        ),
      );
    } catch (e, st) {
      developer.log('Error loading kardex', error: e, stackTrace: st);
      if (state is KardexLoaded) {
        emit((state as KardexLoaded).copyWith(isSearching: false));
      } else {
        if (e is SocketException || e is TimeoutException) {
          emit(const KardexError('Sin conexión a internet.'));
        } else {
          emit(const KardexError('Error al cargar kardex.'));
        }
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
    // Si el usuario borra la búsqueda o escribe texto libre, limpiamos el productId, variantId y batchId
    final clearProd = text.isEmpty ||
        (state is KardexLoaded && (state as KardexLoaded).searchText != text);
    loadMovements(
      searchText: text,
      page: 0,
      clearProductId: clearProd,
      clearVariantId: clearProd,
      clearBatchId: clearProd,
    );
  }

  void clearProductFilter() {
    loadMovements(
      searchText: '',
      page: 0,
      clearProductId: true,
      clearVariantId: true,
      clearBatchId: true,
    );
  }

  void clearVariantFilter() {
    loadMovements(
      page: 0,
      clearVariantId: true,
      clearBatchId: true,
    );
  }

  void clearBatchFilter() {
    loadMovements(
      page: 0,
      clearBatchId: true,
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
        variantId: currentState.variantId,
        batchId: currentState.batchId,
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
