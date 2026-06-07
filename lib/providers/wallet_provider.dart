import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider global que mantiene el saldo de monedas del usuario autenticado.
/// Usa Realtime de Supabase para actualizarse automáticamente.
class WalletProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  int? _balance;
  bool _isLoading = false;
  bool _disposed = false;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  int? get balance => _balance;
  bool get isLoading => _isLoading;
  bool get hasBalance => _balance != null;

  WalletProvider() {
    _init();

    _supabase.auth.onAuthStateChange.listen((event) {
      if (_disposed) return;
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed) {
        _init();
      } else if (event.event == AuthChangeEvent.signedOut) {
        _clear();
      }
    });
  }

  void _init() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _clear();
      return;
    }

    if (_disposed) return;
    _isLoading = true;
    notifyListeners();

    _sub?.cancel();

    _sub = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('auth_user_id', user.id)
        .listen(
          (rows) {
            if (_disposed) return;
            if (rows.isNotEmpty) {
              _balance = (rows.first['wallet_balance'] as num?)?.toInt() ?? 0;
            }
            _isLoading = false;
            notifyListeners();
          },
          onError: (_) {
            if (_disposed) return;
            _balance = _balance ?? 0;
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  void _clear() {
    _sub?.cancel();
    _sub = null;
    _balance = null;
    _isLoading = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final row = await _supabase
          .from('profiles')
          .select('wallet_balance')
          .eq('auth_user_id', user.id)
          .single();

      if (_disposed) return;
      _balance = (row['wallet_balance'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refrescando saldo: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}