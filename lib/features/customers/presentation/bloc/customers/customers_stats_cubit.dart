import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_state.dart';

@lazySingleton
class CustomersStatsCubit extends Cubit<CustomersStatsState> {
  final GetGlobalStatsUseCase _getGlobalStatsUseCase;

  CustomersStatsCubit(this._getGlobalStatsUseCase)
    : super(CustomersStatsInitial());

  Future<void> loadStats({bool silent = false}) async {
    // Si ya contamos con estadísticas previas en memoria, no forzamos Shimmer en la UI
    if (state is! CustomersStatsLoaded && !silent) {
      emit(CustomersStatsLoading());
    }
    try {
      final stats = await _getGlobalStatsUseCase();
      emit(CustomersStatsLoaded(stats));
    } catch (e) {
      if (state is! CustomersStatsLoaded) {
        emit(CustomersStatsError(e.toString()));
      }
    }
  }
}
