import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_time_filter.dart';
import 'package:inventory_store_app/features/dashboard/domain/usecases/get_critical_batches_usecase.dart';
import 'package:inventory_store_app/features/dashboard/domain/usecases/get_inventory_metrics_usecase.dart';
import 'package:inventory_store_app/features/dashboard/domain/usecases/get_sales_metrics_usecase.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_state.dart';

@injectable
class DashboardCubit extends Cubit<DashboardState> {
  final GetInventoryMetricsUseCase getInventoryMetrics;
  final GetSalesMetricsUseCase getSalesMetrics;
  final GetCriticalBatchesUseCase getCriticalBatches;

  DashboardCubit({
    required this.getInventoryMetrics,
    required this.getSalesMetrics,
    required this.getCriticalBatches,
  }) : super(DashboardInitial());

  Future<void> loadDashboardData() async {
    emit(DashboardLoading());

    final inventoryResult = await getInventoryMetrics();
    final salesResult = await getSalesMetrics(filter: SalesTimeFilter.today);
    final batchesResult = await getCriticalBatches(daysThreshold: 30);

    inventoryResult.fold(
      (failure) => emit(DashboardError(failure.message)),
      (inventory) {
        salesResult.fold(
          (failure) => emit(DashboardError(failure.message)),
          (sales) {
            batchesResult.fold(
              (failure) => emit(DashboardError(failure.message)),
              (batches) {
                emit(DashboardLoaded(
                  inventory: inventory,
                  sales: sales,
                  criticalBatches: batches,
                  salesFilter: SalesTimeFilter.today,
                ));
              },
            );
          },
        );
      },
    );
  }

  Future<void> updateSalesFilter(SalesTimeFilter filter) async {
    final currentState = state;
    if (currentState is DashboardLoaded) {
      emit(currentState.copyWith(isSalesLoading: true));
      
      final salesResult = await getSalesMetrics(filter: filter);
      
      salesResult.fold(
        (failure) {
          emit(currentState.copyWith(isSalesLoading: false));
          // Podríamos emitir un error temporal, pero para simplificar
          // solo devolvemos el loading a false.
        },
        (sales) {
          emit(currentState.copyWith(
            sales: sales,
            salesFilter: filter,
            isSalesLoading: false,
          ));
        },
      );
    }
  }
}
