import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_ucs.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers_stats_state.dart';

@injectable
class CustomersStatsCubit extends Cubit<CustomersStatsState> {
  final GetGlobalStatsUseCase _getGlobalStatsUseCase;

  CustomersStatsCubit(this._getGlobalStatsUseCase) : super(CustomersStatsInitial());

  Future<void> loadStats() async {
    emit(CustomersStatsLoading());
    try {
      final stats = await _getGlobalStatsUseCase();
      emit(CustomersStatsLoaded(stats));
    } catch (e) {
      emit(CustomersStatsError(e.toString()));
    }
  }
}
