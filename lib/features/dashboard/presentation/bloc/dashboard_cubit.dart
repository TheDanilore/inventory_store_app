import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/inventory_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_time_filter.dart';
import 'package:inventory_store_app/features/dashboard/domain/usecases/get_critical_batches_usecase.dart';
import 'package:inventory_store_app/features/dashboard/domain/usecases/get_inventory_metrics_usecase.dart';
import 'package:inventory_store_app/features/dashboard/domain/usecases/get_sales_metrics_usecase.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_state.dart';

@lazySingleton
class DashboardCubit extends Cubit<DashboardState> {
  final GetInventoryMetricsUseCase getInventoryMetrics;
  final GetSalesMetricsUseCase getSalesMetrics;
  final GetCriticalBatchesUseCase getCriticalBatches;
  final GetTopCustomersUseCase getTopCustomers;

  int _currentFilterLoadId = 0;

  DashboardCubit({
    required this.getInventoryMetrics,
    required this.getSalesMetrics,
    required this.getCriticalBatches,
    required this.getTopCustomers,
  }) : super(DashboardInitial());

  Future<void> loadDashboardData({
    bool forceRefresh = false,
    bool background = false,
  }) async {
    final currentState = state;
    if (!background || currentState is! DashboardLoaded) {
      emit(DashboardLoading());
    }

    final activeFilter =
        currentState is DashboardLoaded ? currentState.salesFilter : SalesTimeFilter.today;
    final activeStartDate =
        currentState is DashboardLoaded ? currentState.customStartDate : null;
    final activeEndDate =
        currentState is DashboardLoaded ? currentState.customEndDate : null;

    try {
      // Carga paralela de alto rendimiento
      final results = await Future.wait([
        getInventoryMetrics(forceRefresh: forceRefresh),
        getSalesMetrics(
          filter: activeFilter,
          customStartDate: activeStartDate,
          customEndDate: activeEndDate,
          forceRefresh: forceRefresh,
        ),
        getCriticalBatches(daysThreshold: 30, forceRefresh: forceRefresh),
        _fetchTopCustomers(limit: 5),
      ]);

      final inventoryResult =
          results[0] as Either<Failure, InventoryMetricsEntity>;
      final salesResult = results[1] as Either<Failure, SalesMetricsEntity>;
      final batchesResult =
          results[2] as Either<Failure, List<Map<String, dynamic>>>;
      final topCustomers = results[3] as List<CustomerEntity>;

      inventoryResult.fold((failure) => emit(DashboardError(failure.message)), (
        inventory,
      ) {
        salesResult.fold((failure) => emit(DashboardError(failure.message)), (
          sales,
        ) {
          batchesResult.fold(
            (failure) => emit(DashboardError(failure.message)),
            (batches) {
              emit(
                DashboardLoaded(
                  inventory: inventory,
                  sales: sales,
                  criticalBatches: batches,
                  topCustomers: topCustomers,
                  salesFilter: activeFilter,
                  customStartDate: activeStartDate,
                  customEndDate: activeEndDate,
                  isSalesLoading: false,
                ),
              );
            },
          );
        });
      });
    } catch (e, stack) {
      LoggerService.e(
        'Error cargando dashboard',
        tag: 'DASHBOARD_CUBIT',
        error: e,
        stackTrace: stack,
      );
      emit(DashboardError('Error inesperado al cargar el dashboard: $e'));
    }
  }

  Future<List<CustomerEntity>> _fetchTopCustomers({int limit = 5}) async {
    try {
      return await getTopCustomers(limit);
    } catch (e, stack) {
      LoggerService.e(
        'Error cargando top clientes para dashboard',
        tag: 'DASHBOARD_CUBIT',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  Future<void> updateSalesFilter(
    SalesTimeFilter filter, {
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool forceRefresh = false,
  }) async {
    final currentState = state;
    if (currentState is DashboardLoaded) {
      final loadId = ++_currentFilterLoadId;

      emit(
        currentState.copyWith(
          isSalesLoading: true,
          salesFilter: filter,
          customStartDate: customStartDate,
          customEndDate: customEndDate,
        ),
      );

      final salesResult = await getSalesMetrics(
        filter: filter,
        customStartDate: customStartDate,
        customEndDate: customEndDate,
        forceRefresh: forceRefresh,
      );

      // Mutex anti-race-conditions: descartar si hay una petición más reciente
      if (loadId != _currentFilterLoadId) return;

      salesResult.fold(
        (failure) {
          LoggerService.e(
            'Error al actualizar filtro de ventas en dashboard: ${failure.message}',
            tag: 'DASHBOARD_CUBIT',
          );
          if (loadId == _currentFilterLoadId) {
            emit(currentState.copyWith(isSalesLoading: false));
          }
        },
        (sales) {
          if (loadId == _currentFilterLoadId) {
            emit(
              currentState.copyWith(
                sales: sales,
                salesFilter: filter,
                customStartDate: customStartDate,
                customEndDate: customEndDate,
                isSalesLoading: false,
              ),
            );
          }
        },
      );
    }
  }

  Future<void> refresh() async {
    await loadDashboardData(forceRefresh: true);
  }
}
