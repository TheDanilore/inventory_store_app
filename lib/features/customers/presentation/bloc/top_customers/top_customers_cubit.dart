import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_state.dart';

@lazySingleton
class TopCustomersCubit extends Cubit<TopCustomersState> {
  final GetTopCustomersUseCase _getTopCustomersUseCase;

  static const Duration _freshWindow = Duration(minutes: 3);
  static const String _tag = 'TOP_CUSTOMERS_CUBIT';
  DateTime? _lastLoadedAt;

  TopCustomersCubit(this._getTopCustomersUseCase)
    : super(TopCustomersInitial());

  Future<void> ensureLoaded({int limit = 5}) async {
    final current = state;
    if (current is TopCustomersLoaded) {
      final isFresh =
          _lastLoadedAt != null &&
          DateTime.now().difference(_lastLoadedAt!) < _freshWindow;
      if (isFresh) return;
      await loadTopCustomers(limit, true, null, null, true);
      return;
    }

    final cached = _getTopCustomersUseCase.getCached(limit);
    if (cached != null) {
      _lastLoadedAt = DateTime.now();
      if (!isClosed) {
        emit(TopCustomersLoaded(cached.data, isRefreshing: cached.isStale));
      }
      if (cached.isStale) {
        await loadTopCustomers(limit, true, null, null, true);
      }
      return;
    }

    await loadTopCustomers(limit);
  }

  Future<void> loadTopCustomers([
    int limit = 5,
    bool silent = false,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  ]) async {
    final current = state;
    if (current is TopCustomersLoaded) {
      if (!isClosed) {
        emit(
          current.copyWith(isRefreshing: true, clearTransientError: true),
        );
      }
    } else if (!silent) {
      if (!isClosed) emit(TopCustomersLoading());
    }

    final result = await _getTopCustomersUseCase(
      limit,
      startDate: startDate,
      endDate: endDate,
      forceRefresh: forceRefresh,
    );
    if (isClosed) return;

    result.fold(
      (failure) {
        LoggerService.w(
          'Error cargando clientes VIP: ${failure.message}',
          tag: _tag,
        );
        final latest = state;
        if (latest is TopCustomersLoaded) {
          emit(
            latest.copyWith(
              isRefreshing: false,
              transientErrorMessage: failure.message,
            ),
          );
        } else {
          emit(TopCustomersError(failure.message));
        }
      },
      (top) {
        if (startDate == null && endDate == null) {
          _lastLoadedAt = DateTime.now();
        }
        emit(TopCustomersLoaded(top));
      },
    );
  }
}
