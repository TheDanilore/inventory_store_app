import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/data/cache/credit_movements_cache.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customer_credits_repository.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/credit_movements/customer_credit_movements_state.dart';

@injectable
class CustomerCreditMovementsCubit extends Cubit<CustomerCreditMovementsState> {
  final CustomerCreditsRepository _repository;
  final CreditMovementsCache _cache = CreditMovementsCache();

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
    // 1. STALE-WHILE-REVALIDATE: Verificar si ya existen datos en caché para este crédito
    final cached = _cache.get(
      creditId: creditId,
      dateFilter: state.dateFilter,
      typeFilter: state.typeFilter,
      page: state.currentPage,
    );

    if (cached != null) {
      // CERO SHIMMER: Emitir datos cacheados inmediatamente (0 ms)
      emit(
        state.copyWith(
          creditId: creditId,
          customerId: customerId,
          customerName: customerName,
          currentDebt: cached.currentDebt ?? currentDebt,
          creditLimit: cached.creditLimit ?? creditLimit,
          movements: cached.items,
          totalCount: cached.totalCount,
          totalCharged: cached.totalCharged,
          totalPaid: cached.totalPaid,
          chargeCount: cached.chargeCount,
          paymentCount: cached.paymentCount,
          isLoading: false,
          isRevalidating: true, // Sincroniza en background sin bloquear la UI
          error: null,
        ),
      );
    } else {
      // Primera vez: emitir estado inicial con loading
      emit(
        state.copyWith(
          creditId: creditId,
          customerId: customerId,
          customerName: customerName,
          currentDebt: currentDebt,
          creditLimit: creditLimit,
          isLoading: true,
          isRevalidating: false,
        ),
      );
    }

    // 2. Revalidar con el servidor en segundo plano
    loadData(forceRefresh: false);
  }

  Future<void> loadData({
    bool forceRefresh = false,
    bool fetchOnlyMovements = false,
  }) async {
    // Si ya tenemos movimientos en pantalla, NO ponemos isLoading en true (evita shimmer)
    // En su lugar, activamos isRevalidating para mostrar un feedback sutil
    if (state.movements.isEmpty) {
      emit(state.copyWith(isLoading: true, error: null));
    } else {
      emit(state.copyWith(isRevalidating: true, error: null));
    }

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

      // Si solo cambiamos de página, los totales generales y el saldo no han cambiado
      final totalsFuture =
          fetchOnlyMovements
              ? Future.value((
                totalCharged: state.totalCharged,
                totalPaid: state.totalPaid,
                chargeCount: state.chargeCount,
                paymentCount: state.paymentCount,
              ))
              : _repository.getCreditMovementsTotals(
                creditId: state.creditId,
                dateFilter: dateFilterParam,
              );

      final accountFuture =
          (!fetchOnlyMovements && state.customerId.isNotEmpty)
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
      final newCurrentDebt =
          updatedAccount != null
              ? updatedAccount.currentDebt
              : state.currentDebt;
      final newCreditLimit =
          updatedAccount != null
              ? updatedAccount.creditLimit
              : state.creditLimit;

      // 3. Actualizar memoria caché
      _cache.put(
        creditId: state.creditId,
        dateFilter: state.dateFilter,
        typeFilter: state.typeFilter,
        page: state.currentPage,
        entry: CreditMovementsCacheEntry(
          items: items,
          totalCount: movementsResult.totalCount,
          totalCharged: totalResult.totalCharged,
          totalPaid: totalResult.totalPaid,
          chargeCount: totalResult.chargeCount,
          paymentCount: totalResult.paymentCount,
          currentDebt: newCurrentDebt,
          creditLimit: newCreditLimit,
        ),
      );

      emit(
        state.copyWith(
          isLoading: false,
          isRevalidating: false,
          movements: items,
          totalCount: movementsResult.totalCount,
          totalCharged: totalResult.totalCharged,
          totalPaid: totalResult.totalPaid,
          chargeCount: totalResult.chargeCount,
          paymentCount: totalResult.paymentCount,
          currentDebt: newCurrentDebt,
          creditLimit: newCreditLimit,
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
          isRevalidating: false,
          // Si ya teníamos datos mostrados desde el caché, no arruinamos la vista con pantalla de error
          error:
              state.movements.isEmpty
                  ? 'Error al cargar los movimientos: $e'
                  : null,
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
      // Invalida el caché local de este crédito para que refleje el nuevo saldo
      _cache.invalidate(state.creditId);
      // Recargar datos y saldo inmediatamente
      await loadData(forceRefresh: true);
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

    // Si la nueva página ya está en caché, mostrarla al instante
    final cached = _cache.get(
      creditId: state.creditId,
      dateFilter: state.dateFilter,
      typeFilter: state.typeFilter,
      page: page,
    );

    if (cached != null) {
      emit(
        state.copyWith(
          currentPage: page,
          movements: cached.items,
          totalCount: cached.totalCount,
          isLoading: false,
          isRevalidating: true,
        ),
      );
    } else {
      emit(state.copyWith(currentPage: page, isLoading: true));
    }

    // Solo pedimos movimientos de la página (no totales ni balance)
    await loadData(fetchOnlyMovements: true);
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
}
