import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/inventory_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_overview.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_time_filter.dart';
import 'package:inventory_store_app/features/dashboard/domain/repositories/dashboard_repository.dart';
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
  final DashboardRepository dashboardRepository;

  int _currentFilterLoadId = 0;

  DashboardCubit({
    required this.getInventoryMetrics,
    required this.getSalesMetrics,
    required this.getCriticalBatches,
    required this.getTopCustomers,
    required this.dashboardRepository,
  }) : super(DashboardInitial());

  Future<void> loadDashboardData({
    bool forceRefresh = false,
    bool background = false,
  }) async {
    final currentState = state;
    final hasExistingData = currentState is DashboardLoaded;

    if (hasExistingData) {
      emit(currentState.copyWith(isBackgroundLoading: true));
    } else {
      emit(DashboardLoading());
    }

    final activeFilter =
        currentState is DashboardLoaded
            ? currentState.salesFilter
            : SalesTimeFilter.today;
    final activeStartDate =
        currentState is DashboardLoaded ? currentState.customStartDate : null;
    final activeEndDate =
        currentState is DashboardLoaded ? currentState.customEndDate : null;
    final activeWarehouseId =
        currentState is DashboardLoaded
            ? currentState.selectedWarehouseId
            : null;
    final activeWarehouseName =
        currentState is DashboardLoaded
            ? currentState.selectedWarehouseName
            : null;

    try {
      // Carga paralela de alto rendimiento
      final results = await Future.wait([
        getInventoryMetrics(
          forceRefresh: forceRefresh,
          warehouseId: activeWarehouseId,
        ),
        getSalesMetrics(
          filter: activeFilter,
          customStartDate: activeStartDate,
          customEndDate: activeEndDate,
          forceRefresh: forceRefresh,
          warehouseId: activeWarehouseId,
        ),
        getCriticalBatches(
          daysThreshold: 30,
          forceRefresh: forceRefresh,
          warehouseId: activeWarehouseId,
        ),
        _fetchTopCustomers(limit: 5),
        _fetchOverview(
          activeFilter,
          activeStartDate,
          activeEndDate,
          warehouseId: activeWarehouseId,
        ),
      ]);

      final inventoryResult =
          results[0] as Either<Failure, InventoryMetricsEntity>;
      final salesResult = results[1] as Either<Failure, SalesMetricsEntity>;
      final batchesResult =
          results[2] as Either<Failure, List<Map<String, dynamic>>>;
      final topCustomers = results[3] as List<CustomerEntity>;
      final overviewResult = results[4] as Either<Failure, SalesOverview>;

      if (hasExistingData) {
        // Enfoque Stale-While-Revalidate: si ya hay datos previos en pantalla,
        // nunca destruir la UI si uno de los endpoints falla en segundo plano.
        final inventory = inventoryResult.getOrElse((failure) {
          LoggerService.w(
            'Fallo al actualizar métricas de inventario en background: ${failure.message}',
            tag: 'DASHBOARD_CUBIT',
          );
          return currentState.inventory;
        });

        final sales = salesResult.getOrElse((failure) {
          LoggerService.w(
            'Fallo al actualizar métricas de ventas en background: ${failure.message}',
            tag: 'DASHBOARD_CUBIT',
          );
          return currentState.sales;
        });

        final batches = batchesResult.getOrElse((failure) {
          LoggerService.w(
            'Fallo al actualizar lotes críticos en background: ${failure.message}',
            tag: 'DASHBOARD_CUBIT',
          );
          return currentState.criticalBatches;
        });

        final overview = overviewResult.fold<SalesOverview?>((failure) {
          LoggerService.w(
            'Fallo al actualizar resumen de ventas en background: ${failure.message}',
            tag: 'DASHBOARD_CUBIT',
          );
          return currentState.overview;
        }, (o) => o);

        final finalTopCustomers =
            topCustomers.isNotEmpty ? topCustomers : currentState.topCustomers;

        emit(
          DashboardLoaded(
            inventory: inventory,
            sales: sales,
            overview: overview,
            criticalBatches: batches,
            topCustomers: finalTopCustomers,
            salesFilter: activeFilter,
            customStartDate: activeStartDate,
            customEndDate: activeEndDate,
            selectedWarehouseId: activeWarehouseId,
            selectedWarehouseName: activeWarehouseName,
            isSalesLoading: false,
            isBackgroundLoading: false,
          ),
        );
      } else {
        // Carga inicial sin datos previos en memoria:
        inventoryResult.fold(
          (failure) => emit(DashboardError(failure.message)),
          (inventory) {
            salesResult.fold(
              (failure) => emit(DashboardError(failure.message)),
              (sales) {
                batchesResult.fold(
                  (failure) => emit(DashboardError(failure.message)),
                  (batches) {
                    emit(
                      DashboardLoaded(
                        inventory: inventory,
                        sales: sales,
                        // Si el overview falla no se tumba el dashboard:
                        // solo se ocultan sus tarjetas.
                        overview: overviewResult.fold<SalesOverview?>(
                          (_) => null,
                          (o) => o,
                        ),
                        criticalBatches: batches,
                        topCustomers: topCustomers,
                        salesFilter: activeFilter,
                        customStartDate: activeStartDate,
                        customEndDate: activeEndDate,
                        selectedWarehouseId: activeWarehouseId,
                        selectedWarehouseName: activeWarehouseName,
                        isSalesLoading: false,
                        isBackgroundLoading: false,
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      }
    } catch (e, stack) {
      LoggerService.e(
        'Error cargando dashboard',
        tag: 'DASHBOARD_CUBIT',
        error: e,
        stackTrace: stack,
      );
      if (hasExistingData) {
        emit(currentState.copyWith(isBackgroundLoading: false));
      } else {
        emit(DashboardError('Error inesperado al cargar el dashboard: $e'));
      }
    }
  }

  /// Mismo rango que usa `getSalesMetrics` para cada filtro (null/null = todo).
  ({DateTime? from, DateTime? to}) _rangeFor(
    SalesTimeFilter filter,
    DateTime? customStart,
    DateTime? customEnd,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (filter) {
      case SalesTimeFilter.today:
        return (from: today, to: today);
      case SalesTimeFilter.thisWeek:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return (from: monday, to: monday.add(const Duration(days: 6)));
      case SalesTimeFilter.thisMonth:
        return (
          from: DateTime(now.year, now.month, 1),
          to: DateTime(now.year, now.month + 1, 0),
        );
      case SalesTimeFilter.custom:
        return (from: customStart, to: customEnd);
      case SalesTimeFilter.allTime:
        return (from: null, to: null);
    }
  }

  Future<Either<Failure, SalesOverview>> _fetchOverview(
    SalesTimeFilter filter,
    DateTime? customStart,
    DateTime? customEnd, {
    String? warehouseId,
  }) {
    final r = _rangeFor(filter, customStart, customEnd);
    return dashboardRepository.getSalesOverview(
      from: r.from,
      to: r.to,
      warehouseId: warehouseId,
    );
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

  Future<void> updateWarehouseFilter({
    String? warehouseId,
    String? warehouseName,
  }) async {
    final currentState = state;
    if (currentState is DashboardLoaded) {
      if (currentState.selectedWarehouseId == warehouseId) return;

      emit(
        currentState.copyWith(
          selectedWarehouseId: warehouseId,
          selectedWarehouseName: warehouseName,
          clearWarehouse: warehouseId == null,
          isBackgroundLoading: true,
          isSalesLoading: true,
        ),
      );

      final activeFilter = currentState.salesFilter;
      final activeStartDate = currentState.customStartDate;
      final activeEndDate = currentState.customEndDate;

      try {
        final results = await Future.wait([
          getInventoryMetrics(forceRefresh: true, warehouseId: warehouseId),
          getSalesMetrics(
            filter: activeFilter,
            customStartDate: activeStartDate,
            customEndDate: activeEndDate,
            forceRefresh: true,
            warehouseId: warehouseId,
          ),
          getCriticalBatches(
            daysThreshold: 30,
            forceRefresh: true,
            warehouseId: warehouseId,
          ),
          _fetchOverview(
            activeFilter,
            activeStartDate,
            activeEndDate,
            warehouseId: warehouseId,
          ),
        ]);

        final inventoryResult =
            results[0] as Either<Failure, InventoryMetricsEntity>;
        final salesResult = results[1] as Either<Failure, SalesMetricsEntity>;
        final batchesResult =
            results[2] as Either<Failure, List<Map<String, dynamic>>>;
        final overviewResult = results[3] as Either<Failure, SalesOverview>;

        final inventory = inventoryResult.getOrElse(
          (_) => currentState.inventory,
        );
        final sales = salesResult.getOrElse((_) => currentState.sales);
        final batches = batchesResult.getOrElse(
          (_) => currentState.criticalBatches,
        );
        final overview = overviewResult.fold<SalesOverview?>(
          (_) => null,
          (o) => o,
        );

        emit(
          currentState.copyWith(
            selectedWarehouseId: warehouseId,
            selectedWarehouseName: warehouseName,
            clearWarehouse: warehouseId == null,
            inventory: inventory,
            sales: sales,
            overview: overview,
            clearOverview: overview == null,
            criticalBatches: batches,
            isSalesLoading: false,
            isBackgroundLoading: false,
          ),
        );
      } catch (e, stack) {
        LoggerService.e(
          'Error actualizando filtro de almacén en dashboard',
          tag: 'DASHBOARD_CUBIT',
          error: e,
          stackTrace: stack,
        );
        emit(
          currentState.copyWith(
            isSalesLoading: false,
            isBackgroundLoading: false,
          ),
        );
      }
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
      final activeWarehouseId = currentState.selectedWarehouseId;

      emit(
        currentState.copyWith(
          isSalesLoading: true,
          salesFilter: filter,
          customStartDate: customStartDate,
          customEndDate: customEndDate,
        ),
      );

      final (salesResult, overviewResult) =
          await (
            getSalesMetrics(
              filter: filter,
              customStartDate: customStartDate,
              customEndDate: customEndDate,
              forceRefresh: forceRefresh,
              warehouseId: activeWarehouseId,
            ),
            _fetchOverview(
              filter,
              customStartDate,
              customEndDate,
              warehouseId: activeWarehouseId,
            ),
          ).wait;

      // Mutex anti-race-conditions: descartar si hay una petición más reciente
      if (loadId != _currentFilterLoadId) return;

      // Si el overview falla se limpia: mostrar el del rango anterior sería
      // un dato incoherente con el filtro elegido.
      final overview = overviewResult.fold<SalesOverview?>((failure) {
        LoggerService.w(
          'Error al actualizar resumen de ventas: ${failure.message}',
          tag: 'DASHBOARD_CUBIT',
        );
        return null;
      }, (o) => o);

      salesResult.fold(
        (failure) {
          LoggerService.e(
            'Error al actualizar filtro de ventas en dashboard: ${failure.message}',
            tag: 'DASHBOARD_CUBIT',
          );
          if (loadId == _currentFilterLoadId) {
            emit(
              currentState.copyWith(
                isSalesLoading: false,
                overview: overview,
                clearOverview: overview == null,
              ),
            );
          }
        },
        (sales) {
          if (loadId == _currentFilterLoadId) {
            emit(
              currentState.copyWith(
                sales: sales,
                overview: overview,
                clearOverview: overview == null,
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
    final hasLoaded = state is DashboardLoaded;
    await loadDashboardData(forceRefresh: true, background: hasLoaded);
  }
}
