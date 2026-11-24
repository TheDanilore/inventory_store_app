import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_state.dart';

@lazySingleton
class CustomersStatsCubit extends Cubit<CustomersStatsState> {
  final GetGlobalStatsUseCase _getGlobalStatsUseCase;

  static const Duration _freshWindow = Duration(minutes: 2);
  static const String _tag = 'CUSTOMERS_STATS_CUBIT';
  DateTime? _lastLoadedAt;

  CustomersStatsCubit(this._getGlobalStatsUseCase)
    : super(CustomersStatsInitial());

  Future<void> ensureLoaded() async {
    final current = state;
    if (current is CustomersStatsLoaded) {
      final isFresh =
          _lastLoadedAt != null &&
          DateTime.now().difference(_lastLoadedAt!) < _freshWindow;
      if (isFresh) return;
      await loadStats(silent: true, forceRefresh: true);
      return;
    }

    final cached = _getGlobalStatsUseCase.getCached();
    if (cached != null) {
      _lastLoadedAt = DateTime.now();
      if (!isClosed) {
        emit(CustomersStatsLoaded(cached.data, isRefreshing: cached.isStale));
      }
      if (cached.isStale) {
        await loadStats(silent: true, forceRefresh: true);
      }
      return;
    }

    await loadStats();
  }

  Future<void> loadStats({bool silent = false, bool forceRefresh = false}) async {
    final current = state;
    if (current is CustomersStatsLoaded) {
      if (!isClosed) {
        emit(
          current.copyWith(isRefreshing: true, clearTransientError: true),
        );
      }
    } else if (!silent) {
      if (!isClosed) emit(CustomersStatsLoading());
    }

    final result = await _getGlobalStatsUseCase(forceRefresh: forceRefresh);
    if (isClosed) return;

    result.fold(
      (failure) {
        LoggerService.w(
          'Error cargando estadísticas globales de clientes: ${failure.message}',
          tag: _tag,
        );
        final latest = state;
        if (latest is CustomersStatsLoaded) {
          emit(
            latest.copyWith(
              isRefreshing: false,
              transientErrorMessage: failure.message,
            ),
          );
        } else {
          emit(CustomersStatsError(failure.message));
        }
      },
      (stats) {
        _lastLoadedAt = DateTime.now();
        emit(CustomersStatsLoaded(stats));
      },
    );
  }
}
