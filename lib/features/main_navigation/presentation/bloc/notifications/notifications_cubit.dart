import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/main_navigation/domain/entities/app_notification.dart';
import 'package:inventory_store_app/features/main_navigation/domain/entities/inventory_alert_rules.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/notifications/notifications_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cubit de notificaciones de inventario con caché L1 (RAM) y L2 (`SharedPreferences`),
/// TTL mínimo anti-refetch, deduplicación in-flight y preservación ante fallos de red.
class NotificationsCubit extends Cubit<NotificationsState> {
  static const _readKey = 'notif_read_ids';
  static const _dismissedKey = 'notif_dismissed_ids';
  static const _cachedItemsKey = 'notif_cached_items_v1';
  static const _lastFetchKey = 'notif_last_fetch_v1';
  static const int _maxCachedItems = 50;
  static const String _tag = 'NotificationsCubit';

  // Caché L1 en memoria para renderizado en Frame 0 (Zero-Shimmer) entre recreaciones.
  static List<AppNotification>? _l1Items;
  static Set<String>? _l1ReadIds;
  static Set<String>? _l1Dismissed;
  static DateTime? _l1LastUpdatedAt;

  @visibleForTesting
  static void clearMemoryCache() {
    _l1Items = null;
    _l1ReadIds = null;
    _l1Dismissed = null;
    _l1LastUpdatedAt = null;
  }

  final InventoryAlertSource _source;
  final InventoryAlertEvaluator _evaluator;
  SharedPreferences? _prefs;
  final Duration refreshEvery;
  final Duration minFreshTtl;

  Timer? _timer;
  Future<void>? _inFlight;
  Set<String> _dismissed = Set<String>.from(_l1Dismissed ?? const {});

  NotificationsCubit({
    required InventoryAlertSource source,
    SharedPreferences? prefs,
    InventoryAlertEvaluator evaluator = const InventoryAlertEvaluator(),
    this.refreshEvery = const Duration(minutes: 10),
    this.minFreshTtl = const Duration(minutes: 2),
  }) : _source = source,
       _prefs = prefs,
       _evaluator = evaluator,
       super(_initialStateFromL1());

  static NotificationsState _initialStateFromL1() {
    if (_l1Items != null || _l1LastUpdatedAt != null) {
      return NotificationsState(
        items: List<AppNotification>.unmodifiable(_l1Items ?? const []),
        readIds: Set<String>.unmodifiable(_l1ReadIds ?? const {}),
        lastUpdatedAt: _l1LastUpdatedAt,
      );
    }
    return const NotificationsState();
  }

  /// Hidrata desde L1/L2 sin bloquear con shimmer y programa refresco periódico.
  Future<void> start() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (isClosed) return;

      _dismissed = (_prefs?.getStringList(_dismissedKey) ?? const []).toSet();
      _l1Dismissed = _dismissed;

      final persistedRead =
          (_prefs?.getStringList(_readKey) ?? const []).toSet();
      _l1ReadIds = persistedRead;

      if (_l1Items == null) {
        final l2Items = _readCachedItemsL2();
        final l2UpdatedAt = _readLastFetchL2();
        if (l2Items != null || l2UpdatedAt != null) {
          final visibleL2 =
              (l2Items ?? const <AppNotification>[])
                  .where((n) => !_dismissed.contains(n.id))
                  .toList();
          _l1Items = visibleL2;
          _l1LastUpdatedAt = l2UpdatedAt;

          emit(
            state.copyWith(
              items: List<AppNotification>.unmodifiable(visibleL2),
              readIds: Set<String>.unmodifiable(persistedRead),
              lastUpdatedAt: l2UpdatedAt,
            ),
          );
        } else {
          emit(
            state.copyWith(readIds: Set<String>.unmodifiable(persistedRead)),
          );
        }
      }
    } catch (e, st) {
      LoggerService.w(
        'Error al hidratar caché L2 de notificaciones',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }

    if (isClosed) return;

    final isFresh =
        state.lastUpdatedAt != null &&
        DateTime.now().difference(state.lastUpdatedAt!) < minFreshTtl;
    if (!isFresh) {
      await refresh();
    }

    if (isClosed) return;
    _timer?.cancel();
    _timer = Timer.periodic(refreshEvery, (_) => refresh());
  }

  /// Refresca las alertas respetando [minFreshTtl] salvo cuando [force] es true.
  Future<void> refresh({bool force = false}) {
    if (isClosed) return Future.value();

    if (!force && state.lastUpdatedAt != null) {
      final age = DateTime.now().difference(state.lastUpdatedAt!);
      if (age < minFreshTtl) {
        return Future.value();
      }
    }

    if (_inFlight != null && !force) {
      return _inFlight!;
    }

    final future = _performRefresh();
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
    return future;
  }

  Future<void> _performRefresh() async {
    if (isClosed) return;
    emit(state.copyWith(loading: true, clearError: true));

    try {
      final results = await Future.wait([
        _source.fetchVariants(),
        _source.fetchLots(),
      ]);

      if (isClosed) return;

      final all = _evaluator.evaluate(
        variants: results[0] as List<StockVariantSnapshot>,
        lots: results[1] as List<LotSnapshot>,
      );
      final visible = List<AppNotification>.unmodifiable(
        all.where((n) => !_dismissed.contains(n.id)),
      );

      // Limpia ids obsoletos solo tras una respuesta remota exitosa.
      final liveIds = all.map((n) => n.id).toSet();
      _dismissed = _dismissed.intersection(liveIds);
      final read = Set<String>.unmodifiable(
        state.readIds.intersection(liveIds),
      );
      final now = DateTime.now();

      _l1Items = visible;
      _l1ReadIds = read;
      _l1Dismissed = _dismissed;
      _l1LastUpdatedAt = now;

      await _persistStateL2(items: visible, readIds: read, lastUpdatedAt: now);

      if (!isClosed) {
        emit(
          NotificationsState(
            items: visible,
            readIds: read,
            loading: false,
            lastUpdatedAt: now,
          ),
        );
      }
    } on AppException catch (e, st) {
      LoggerService.w(
        'Fallo controlado al refrescar notificaciones: ${e.message}',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      if (!isClosed) {
        emit(state.copyWith(loading: false, errorMessage: e.message));
      }
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado al refrescar notificaciones',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            loading: false,
            errorMessage: 'No se pudieron actualizar las notificaciones.',
          ),
        );
      }
    }
  }

  Future<void> markRead(String id) async {
    final read = Set<String>.unmodifiable({...state.readIds, id});
    _l1ReadIds = read;
    if (!isClosed) {
      emit(state.copyWith(readIds: read));
    }
    try {
      await _prefs?.setStringList(_readKey, read.toList());
    } catch (e, st) {
      LoggerService.w(
        'Error guardando notificación leída',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> markAllRead() async {
    final read = Set<String>.unmodifiable(state.items.map((n) => n.id));
    _l1ReadIds = read;
    if (!isClosed) {
      emit(state.copyWith(readIds: read));
    }
    try {
      await _prefs?.setStringList(_readKey, read.toList());
    } catch (e, st) {
      LoggerService.w(
        'Error guardando todas las notificaciones leídas',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> dismiss(String id) async {
    _dismissed = {..._dismissed, id};
    _l1Dismissed = _dismissed;
    final remaining = List<AppNotification>.unmodifiable(
      state.items.where((n) => n.id != id),
    );
    _l1Items = remaining;
    if (!isClosed) {
      emit(state.copyWith(items: remaining));
    }
    try {
      await _prefs?.setStringList(_dismissedKey, _dismissed.toList());
      await _persistCachedItemsL2(remaining);
    } catch (e, st) {
      LoggerService.w(
        'Error descartando notificación',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }
  }

  List<AppNotification>? _readCachedItemsL2() {
    final raw = _prefs?.getString(_cachedItemsKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    return decoded
        .whereType<Map>()
        .map((m) => AppNotification.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  DateTime? _readLastFetchL2() {
    final raw = _prefs?.getString(_lastFetchKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _persistStateL2({
    required List<AppNotification> items,
    required Set<String> readIds,
    required DateTime lastUpdatedAt,
  }) async {
    try {
      await _prefs?.setStringList(_dismissedKey, _dismissed.toList());
      await _prefs?.setStringList(_readKey, readIds.toList());
      await _prefs?.setString(_lastFetchKey, lastUpdatedAt.toIso8601String());
      await _persistCachedItemsL2(items);
    } catch (e, st) {
      LoggerService.w(
        'Error persistiendo caché L2 de notificaciones',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _persistCachedItemsL2(List<AppNotification> items) async {
    final bounded = items.take(_maxCachedItems).map((n) => n.toJson()).toList();
    await _prefs?.setString(_cachedItemsKey, jsonEncode(bounded));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
