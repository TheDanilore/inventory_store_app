import 'package:injectable/injectable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_movement_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credit_movements_repository.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_supplier_credit_movements_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/generate_supplier_credit_movements_pdf_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credit_movements/supplier_credit_movements_state.dart';
import 'package:printing/printing.dart';

@injectable
class SupplierCreditMovementsCubit extends Cubit<SupplierCreditMovementsState> {
  final FetchSupplierCreditMovementsUseCase fetchMovementsUseCase;
  final GenerateSupplierCreditMovementsPdfUseCase generatePdfUseCase;
  final String creditId;
  final String supplierName;

  static const int pageSize = 8;

  SupplierCreditMovementsCubit({
    required this.fetchMovementsUseCase,
    required this.generatePdfUseCase,
    @factoryParam required this.creditId,
    @factoryParam required this.supplierName,
  }) : super(SupplierCreditMovementsInitial()) {
    loadMovements();
  }

  Future<void> loadMovements({
    MovementDateFilter? dateFilter,
    int? page,
    bool refresh = false,
  }) async {
    final currentState = state;
    MovementDateFilter currentFilter = MovementDateFilter.allTime;
    int currentPage = 0;
    List<SupplierCreditMovementEntity> currentMovements = [];
    int currentTotalCount = 0;
    double currentCharged = 0.0;
    double currentPaid = 0.0;

    if (currentState is SupplierCreditMovementsLoaded) {
      currentFilter = dateFilter ?? currentState.dateFilter;
      currentPage = page ?? (refresh ? 0 : currentState.currentPage);
      currentMovements = refresh ? [] : currentState.movements;
      currentTotalCount = currentState.totalCount;
      currentCharged = currentState.totalCharged;
      currentPaid = currentState.totalPaid;
    } else if (currentState is SupplierCreditMovementsLoading) {
      currentFilter = dateFilter ?? currentState.dateFilter;
      currentPage = page ?? (refresh ? 0 : currentState.currentPage);
      currentMovements = refresh ? [] : currentState.currentMovements;
      currentTotalCount = currentState.totalCount;
      currentCharged = currentState.totalCharged;
      currentPaid = currentState.totalPaid;
    } else if (currentState is SupplierCreditMovementsError) {
      currentFilter = dateFilter ?? currentState.dateFilter;
      currentPage = page ?? (refresh ? 0 : currentState.currentPage);
      currentMovements = refresh ? [] : currentState.currentMovements;
      currentTotalCount = currentState.totalCount;
      currentCharged = currentState.totalCharged;
      currentPaid = currentState.totalPaid;
    } else {
      currentFilter = dateFilter ?? MovementDateFilter.allTime;
      currentPage = page ?? 0;
    }

    emit(
      SupplierCreditMovementsLoading(
        currentMovements: currentMovements,
        dateFilter: currentFilter,
        currentPage: currentPage,
        totalCount: currentTotalCount,
        totalCharged: currentCharged,
        totalPaid: currentPaid,
      ),
    );

    final result = await fetchMovementsUseCase(
      creditId: creditId,
      page: currentPage,
      pageSize: pageSize,
      dateFilter: currentFilter,
    );

    result.fold(
      (failure) {
        String msg = 'Error al cargar movimientos.';
        final errStr = failure.message.toLowerCase();
        if (errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup')) {
          msg = 'Sin conexión a internet.';
        }
        emit(
          SupplierCreditMovementsError(
            message: msg,
            currentMovements: currentMovements,
            dateFilter: currentFilter,
            currentPage: currentPage,
            totalCount: currentTotalCount,
            totalCharged: currentCharged,
            totalPaid: currentPaid,
          ),
        );
      },
      (data) {
        emit(
          SupplierCreditMovementsLoaded(
            movements: data.movements,
            dateFilter: currentFilter,
            currentPage: currentPage,
            totalCount: data.totalCount,
            totalCharged: data.totalCharged,
            totalPaid: data.totalPaid,
          ),
        );
      },
    );
  }

  void setDateFilter(MovementDateFilter filter) {
    loadMovements(dateFilter: filter, page: 0, refresh: true);
  }

  void setPage(int page) {
    loadMovements(page: page);
  }

  Future<void> exportToPdf() async {
    final currentState = state;
    if (currentState is! SupplierCreditMovementsLoaded) return;

    emit(currentState.copyWith(isExporting: true));

    // Notice we fetch all the items bypassing the pagination inside the repo internally, or we fetch again by requesting all.
    // The previous implementation made a custom query to fetch all without pagination limit.
    // We can do it by requesting with a large pageSize just for the pdf, or handle it properly.
    // To keep it simple, we'll fetch with pageSize: 100000 for PDF just like we used to.
    final fetchResult = await fetchMovementsUseCase(
      creditId: creditId,
      page: 0,
      pageSize: 100000,
      dateFilter: currentState.dateFilter,
    );

    await fetchResult.fold(
      (failure) async {
        emit(currentState.copyWith(isExporting: false));
        emit(
          SupplierCreditMovementsError(
            message: 'Error al exportar PDF: ${failure.message}',
            currentMovements: currentState.movements,
            dateFilter: currentState.dateFilter,
            currentPage: currentState.currentPage,
            totalCount: currentState.totalCount,
            totalCharged: currentState.totalCharged,
            totalPaid: currentState.totalPaid,
          ),
        );
      },
      (data) async {
        final pdfResult = await generatePdfUseCase(
          supplierName: supplierName,
          allMovementsForPdf: data.movements,
        );

        pdfResult.fold(
          (failure) {
            emit(currentState.copyWith(isExporting: false));
            emit(
              SupplierCreditMovementsError(
                message: 'Error al generar PDF: ${failure.message}',
                currentMovements: currentState.movements,
                dateFilter: currentState.dateFilter,
                currentPage: currentState.currentPage,
                totalCount: currentState.totalCount,
                totalCharged: currentState.totalCharged,
                totalPaid: currentState.totalPaid,
              ),
            );
          },
          (pdfBytes) async {
            emit(currentState.copyWith(isExporting: false));
            await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
          },
        );
      },
    );
  }

  void clearError() {
    final currentState = state;
    if (currentState is SupplierCreditMovementsError) {
      emit(
        SupplierCreditMovementsLoaded(
          movements: currentState.currentMovements,
          dateFilter: currentState.dateFilter,
          currentPage: currentState.currentPage,
          totalCount: currentState.totalCount,
          totalCharged: currentState.totalCharged,
          totalPaid: currentState.totalPaid,
        ),
      );
    }
  }
}
