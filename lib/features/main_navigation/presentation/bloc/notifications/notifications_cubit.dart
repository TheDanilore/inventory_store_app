import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/main_navigation/domain/entities/inventory_alert_rules.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/notifications/notifications_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  static const _readKey = 'notif_read_ids';
  static const _dismissedKey = 'notif_dismissed_ids';

  final InventoryAlertSource _source;
  final InventoryAlertEvaluator _evaluator;
  final SharedPreferences _prefs;
  final Duration refreshEvery;

  Timer? _timer;
  Set<String> _dismissed = {};

  NotificationsCubit({
    required InventoryAlertSource source,
    required SharedPreferences prefs,
    InventoryAlertEvaluator evaluator = const InventoryAlertEvaluator(),
    this.refreshEvery = const Duration(minutes: 10),
  }) : _source = source,
       _prefs = prefs,
       _evaluator = evaluator,
       super(const NotificationsState());

  /// Llamar una vez que el usuario esté autenticado (p. ej. al montar el shell).
  Future<void> start() async {
    _dismissed = (_prefs.getStringList(_dismissedKey) ?? []).toSet();
    emit(
      state.copyWith(readIds: (_prefs.getStringList(_readKey) ?? []).toSet()),
    );
    await refresh();
    _timer?.cancel();
    _timer = Timer.periodic(refreshEvery, (_) => refresh());
  }

  Future<void> refresh() async {
    if (isClosed) return;
    emit(state.copyWith(loading: true));
    try {
      final results = await Future.wait([
        _source.fetchVariants(),
        _source.fetchLots(),
      ]);
      final all = _evaluator.evaluate(
        variants: results[0] as List<StockVariantSnapshot>,
        lots: results[1] as List<LotSnapshot>,
      );
      final visible = all.where((n) => !_dismissed.contains(n.id)).toList();

      // Limpia ids obsoletos para que las preferencias no crezcan sin fin.
      final liveIds = all.map((n) => n.id).toSet();
      _dismissed = _dismissed.intersection(liveIds);
      final read = state.readIds.intersection(liveIds);
      await _prefs.setStringList(_dismissedKey, _dismissed.toList());
      await _prefs.setStringList(_readKey, read.toList());

      if (!isClosed) {
        emit(NotificationsState(items: visible, readIds: read, loading: false));
      }
    } catch (_) {
      // Si falla la consulta (offline, etc.) conservamos lo que ya había.
      if (!isClosed) emit(state.copyWith(loading: false));
    }
  }

  Future<void> markRead(String id) async {
    final read = {...state.readIds, id};
    await _prefs.setStringList(_readKey, read.toList());
    emit(state.copyWith(readIds: read));
  }

  Future<void> markAllRead() async {
    final read = state.items.map((n) => n.id).toSet();
    await _prefs.setStringList(_readKey, read.toList());
    emit(state.copyWith(readIds: read));
  }

  Future<void> dismiss(String id) async {
    _dismissed = {..._dismissed, id};
    await _prefs.setStringList(_dismissedKey, _dismissed.toList());
    emit(state.copyWith(items: state.items.where((n) => n.id != id).toList()));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
