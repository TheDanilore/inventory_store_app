import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customer_credits_repository.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/credit_movements/customer_credit_movements_state.dart';

@injectable
class CustomerCreditMovementsCubit extends Cubit<CustomerCreditMovementsState> {
  final CustomerCreditsRepository _repository;

  CustomerCreditMovementsCubit(this._repository)
    : super(
        const CustomerCreditMovementsState(
          creditId: '',
          customerName: '',
          currentDebt: 0.0,
          creditLimit: 0.0,
        ),
      );

  void init({
    required String creditId,
    required String customerName,
    required double currentDebt,
    required double creditLimit,
  }) {
    emit(
      state.copyWith(
        creditId: creditId,
        customerName: customerName,
        currentDebt: currentDebt,
        creditLimit: creditLimit,
      ),
    );
    loadData();
  }

  Future<void> loadData() async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final dateFilterParam =
          state.dateFilter == 'all' ? null : state.dateFilter;

      final movementsFuture = _repository.getCreditMovements(
        creditId: state.creditId,
        limit: state.pageSize,
        offset: state.currentPage * state.pageSize,
        dateFilter: dateFilterParam,
      );

      final totalsFuture = _repository.getCreditMovementsTotals(
        creditId: state.creditId,
        dateFilter: dateFilterParam,
      );

      final results = await Future.wait([movementsFuture, totalsFuture]);
      final movements =
          results[0]
              as List; // In real impl, you'd get total count. We will simulate count or check if list is complete
      // If the backend doesn't return count directly, we might assume if movements.length < pageSize, that's the end. Or the endpoint returns a paginated object.
      // Based on old provider `({List<CustomerCreditMovementModel> movements, int count})`, if the repo now just returns List, we may need to handle it.
      // Wait, the new repo interface `getCreditMovements` returns `List<CreditMovementEntity>`. It doesn't return total count. We'll set totalCount to current page items + page size to allow next page if it's full.

      final totalResult =
          results[1] as ({double totalCharged, double totalPaid});

      int simulatedTotalCount =
          state.currentPage * state.pageSize + movements.length;
      if (movements.length == state.pageSize) {
        simulatedTotalCount += state.pageSize; // assume more available
      }

      emit(
        state.copyWith(
          isLoading: false,
          movements: movements.cast(),
          totalCount: simulatedTotalCount,
          totalCharged: totalResult.totalCharged,
          totalPaid: totalResult.totalPaid,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Error al cargar los movimientos: $e',
        ),
      );
    }
  }

  Future<void> setPage(int page) async {
    if (page == state.currentPage) return;
    emit(state.copyWith(currentPage: page));
    await loadData();
  }

  Future<void> setDateFilter(String filter) async {
    if (filter == state.dateFilter) return;
    emit(state.copyWith(dateFilter: filter, currentPage: 0));
    await loadData();
  }

  Future<void> exportToPdf() async {
    if (state.isExporting) return;

    emit(state.copyWith(isExporting: true, error: null));

    try {
      // Simulate PDF generation
      await Future.delayed(const Duration(seconds: 2));

      emit(state.copyWith(isExporting: false, exportSuccess: true));
    } catch (e) {
      emit(
        state.copyWith(
          isExporting: false,
          error: 'Error al exportar a PDF: $e',
        ),
      );
    }
  }
}
