import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_state.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/watch_pending_orders_count_uc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cubit para el badge de pedidos pendientes con caché L1 (RAM) y L2 (`SharedPreferences`)
/// para renderizado Zero-Shimmer y ciclo de vida `@injectable` seguro entre sesiones.
@injectable
class SidebarBadgeCubit extends Cubit<SidebarBadgeState> {
  static const String _cacheKey = 'sidebar_pending_orders_count_v1';
  static const String _tag = 'SidebarBadgeCubit';

  static int? _l1Count;

  @visibleForTesting
  static void clearMemoryCache() {
    _l1Count = null;
  }

  final WatchPendingOrdersCountUc watchPendingOrdersCountUc;
  SharedPreferences? _prefs;
  StreamSubscription? _subscription;
  int? _lastCount;

  SidebarBadgeCubit(
    this.watchPendingOrdersCountUc, {
    @factoryParam SharedPreferences? prefs,
  }) : _prefs = prefs,
       _lastCount = _l1Count,
       super(
         _l1Count != null
             ? SidebarBadgeLoaded(_l1Count!)
             : const SidebarBadgeLoading(),
       ) {
    if (_l1Count == null) {
      unawaited(_hydrateL2());
    }
    _initSubscription();
  }

  Future<void> _hydrateL2() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (isClosed) return;
      final cached = _prefs?.getInt(_cacheKey);
      if (cached != null && _l1Count == null && state is SidebarBadgeLoading) {
        _lastCount = cached;
        _l1Count = cached;
        emit(SidebarBadgeLoaded(cached));
      }
    } catch (e, st) {
      LoggerService.w(
        'Fallo al leer caché L2 del badge de pedidos',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }
  }

  void _initSubscription() {
    _subscription?.cancel();
    _subscription = watchPendingOrdersCountUc().listen(
      (either) {
        if (isClosed) return;
        either.fold(
          (failure) {
            LoggerService.w(
              'SidebarBadge error: ${failure.message}',
              tag: _tag,
            );
            final fallback = _lastCount ?? _l1Count;
            emit(SidebarBadgeError(failure.message, cachedCount: fallback));
          },
          (count) {
            _lastCount = count;
            _l1Count = count;
            emit(SidebarBadgeLoaded(count));
            unawaited(_persistL2(count));
          },
        );
      },
      onError: (error, st) {
        LoggerService.e(
          'SidebarBadge stream error: $error',
          tag: _tag,
          error: error,
          stackTrace: st is StackTrace ? st : null,
        );
        if (isClosed) return;
        final fallback = _lastCount ?? _l1Count;
        emit(SidebarBadgeError(error.toString(), cachedCount: fallback));
      },
    );
  }

  Future<void> _persistL2(int count) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setInt(_cacheKey, count);
    } catch (e, st) {
      LoggerService.w(
        'Fallo al guardar caché L2 del badge de pedidos',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }
  }

  void retry() {
    if (isClosed) return;
    emit(SidebarBadgeLoading(cachedCount: _lastCount ?? _l1Count));
    _initSubscription();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
