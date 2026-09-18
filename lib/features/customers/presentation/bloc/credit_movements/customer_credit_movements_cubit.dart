import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
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
    String customerId = '',
  }) {
    emit(
      state.copyWith(
        creditId: creditId,
        customerId: customerId,
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
      final movementTypeParam =
          state.typeFilter == 'ALL' ? null : state.typeFilter;

      final movementsFuture = _repository.getCreditMovements(
        creditId: state.creditId,
        limit: state.pageSize,
        offset: state.currentPage * state.pageSize,
        dateFilter: dateFilterParam,
        movementType: movementTypeParam,
      );

      final totalsFuture = _repository.getCreditMovementsTotals(
        creditId: state.creditId,
        dateFilter: dateFilterParam,
      );

      // Si tenemos customerId, refrescamos el estado actual de la cuenta para mantener el saldo al día
      final accountFuture =
          state.customerId.isNotEmpty
              ? _repository.getCreditAccountByCustomer(state.customerId)
              : Future.value(null);

      final results = await Future.wait([
        movementsFuture,
        totalsFuture,
        accountFuture,
      ]);

      final movementsResult =
          results[0] as ({List<CreditMovementEntity> items, int totalCount});
      final totalResult =
          results[1]
              as ({
                double totalCharged,
                double totalPaid,
                int chargeCount,
                int paymentCount,
              });
      final updatedAccount = results[2] as CustomerCreditEntity?;

      final items = movementsResult.items;

      emit(
        state.copyWith(
          isLoading: false,
          movements: items,
          totalCount: movementsResult.totalCount,
          totalCharged: totalResult.totalCharged,
          totalPaid: totalResult.totalPaid,
          chargeCount: totalResult.chargeCount,
          paymentCount: totalResult.paymentCount,
          currentDebt:
              updatedAccount != null
                  ? updatedAccount.currentDebt
                  : state.currentDebt,
          creditLimit:
              updatedAccount != null
                  ? updatedAccount.creditLimit
                  : state.creditLimit,
        ),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error cargando movimientos de crédito para creditId: ${state.creditId}',
        tag: 'CUSTOMER_CREDIT_MOVEMENTS_CUBIT',
        error: e,
        stackTrace: st,
      );
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Error al cargar los movimientos: $e',
        ),
      );
    }
  }

  Future<void> registerPayment({
    required double amount,
    String? accountId,
    String? orderId,
    String? notes,
    String? shiftId,
  }) async {
    try {
      await _repository.registerPayment(
        customerId: state.customerId,
        creditId: state.creditId,
        amount: amount,
        accountId: accountId,
        orderId: orderId,
        notes: notes,
        shiftId: shiftId,
      );
      // Recargar datos y saldo inmediatamente
      await loadData();
    } catch (e, st) {
      LoggerService.e(
        'Error al registrar abono en CustomerCreditMovementsCubit',
        tag: 'CUSTOMER_CREDIT_MOVEMENTS_CUBIT',
        error: e,
        stackTrace: st,
      );
      rethrow;
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

  Future<void> setTypeFilter(String filter) async {
    if (filter == state.typeFilter) return;
    emit(state.copyWith(typeFilter: filter, currentPage: 0));
    await loadData();
  }

  Future<void> exportToPdf() async {
    if (state.isExporting) return;

    emit(state.copyWith(isExporting: true, error: null));

    try {
      // Simular exportación a PDF
      await Future.delayed(const Duration(seconds: 2));

      emit(state.copyWith(isExporting: false, exportSuccess: true));
    } catch (e, st) {
      LoggerService.e(
        'Error al exportar PDF de movimientos',
        tag: 'CUSTOMER_CREDIT_MOVEMENTS_CUBIT',
        error: e,
        stackTrace: st,
      );
      emit(
        state.copyWith(
          isExporting: false,
          error: 'Error al exportar a PDF: $e',
        ),
      );
    }
  }
}
