import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_state.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/watch_pending_orders_count_uc.dart';

@lazySingleton
class SidebarBadgeCubit extends Cubit<SidebarBadgeState> {
  final WatchPendingOrdersCountUc watchPendingOrdersCountUc;
  StreamSubscription? _subscription;
  int? _lastCount;

  SidebarBadgeCubit(this.watchPendingOrdersCountUc)
    : super(const SidebarBadgeLoading()) {
    _initSubscription();
  }

  void _initSubscription() {
    _subscription?.cancel();
    _subscription = watchPendingOrdersCountUc().listen(
      (either) {
        either.fold(
          (failure) {
            LoggerService.w(
              'SidebarBadge error: ${failure.message}',
              tag: 'SidebarBadgeCubit',
            );
            emit(SidebarBadgeError(failure.message, cachedCount: _lastCount));
          },
          (count) {
            _lastCount = count;
            emit(SidebarBadgeLoaded(count));
          },
        );
      },
      onError: (error, st) {
        LoggerService.e(
          'SidebarBadge stream error: $error',
          tag: 'SidebarBadgeCubit',
          error: error,
          stackTrace: st is StackTrace ? st : null,
        );
        emit(SidebarBadgeError(error.toString(), cachedCount: _lastCount));
      },
    );
  }

  void retry() {
    emit(SidebarBadgeLoading(cachedCount: _lastCount));
    _initSubscription();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
