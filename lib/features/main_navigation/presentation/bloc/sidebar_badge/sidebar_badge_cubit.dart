import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_state.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/watch_pending_orders_count_uc.dart';
import 'package:injectable/injectable.dart';
import 'dart:developer' as developer;

@lazySingleton
class SidebarBadgeCubit extends Cubit<SidebarBadgeState> {
  final WatchPendingOrdersCountUc watchPendingOrdersCountUc;
  StreamSubscription? _subscription;

  SidebarBadgeCubit(this.watchPendingOrdersCountUc) : super(SidebarBadgeLoading()) {
    _initSubscription();
  }

  void _initSubscription() {
    _subscription?.cancel();
    _subscription = watchPendingOrdersCountUc().listen(
      (either) {
        either.fold(
          (failure) {
            developer.log('SidebarBadge error: ${failure.message}');
            emit(SidebarBadgeError(failure.message));
          },
          (count) {
            emit(SidebarBadgeLoaded(count));
          },
        );
      },
      onError: (error) {
        developer.log('SidebarBadge stream error: $error');
        emit(SidebarBadgeError(error.toString()));
      },
    );
  }

  void retry() {
    emit(SidebarBadgeLoading());
    _initSubscription();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
