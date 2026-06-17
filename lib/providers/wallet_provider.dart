import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/services/customer/wallet_service.dart';

/// Provider global que mantiene el saldo de monedas del usuario autenticado.
class WalletProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final WalletService _service = WalletService();

  int? _balance;
  bool _isLoading = false;
  bool _disposed = false;
  String? _error;
  
  StreamSubscription<AuthState>? _authSub;

  int? get balance => _balance;
  bool get isLoading => _isLoading;
  bool get hasBalance => _balance != null;
  String? get error => _error;

  WalletProvider() {
    _init();

    _authSub = _supabase.auth.onAuthStateChange.listen((event) {
      if (_disposed) return;
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed) {
        _init();
      } else if (event.event == AuthChangeEvent.signedOut) {
        _clear();
      }
    });
  }

  Future<void> _init() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _clear();
      return;
    }

    if (_disposed) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final balance = await _service.fetchBalance(user.id);
      if (_disposed) return;
      _balance = balance;
    } catch (e) {
      if (_disposed) return;
      _error = 'No se pudo cargar el saldo: $e';
      _balance = _balance ?? 0;
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _clear() {
    _balance = null;
    _isLoading = false;
    _error = null;
    if (!_disposed) notifyListeners();
  }

  /// Permite incrementar o decrementar el saldo localmente (ej. tras ganar un minijuego)
  /// para no hacer peticiones extras a la base de datos de inmediato.
  void addLocalBalance(int amount) {
    if (_balance != null) {
      _balance = _balance! + amount;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final balance = await _service.fetchBalance(user.id);
      if (_disposed) return;
      _balance = balance;
    } catch (e) {
      if (_disposed) return;
      _error = 'Error refrescando saldo: $e';
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    super.dispose();
  }

  /// Procesa una recompensa de minijuego, maneja errores y actualiza el saldo local.
  Future<void> processGameReward({
    required int points,
    required String movementType,
    required String description,
  }) async {
    if (points <= 0) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _error = 'Debes iniciar sesión para guardar puntos.';
      if (!_disposed) notifyListeners();
      throw Exception('No authenticated user');
    }

    try {
      // Intentamos recuperar el profile_id si no lo tenemos a mano
      // Muchos juegos pasan el profileId por parámetro, pero al usar provider, el provider puede averiguarlo.
      final profileResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('auth_user_id', user.id)
          .single();
          
      final profileId = profileResponse['id'] as String;

      await _service.addReward(
        profileId: profileId,
        points: points,
        movementType: movementType,
        description: description,
      );

      // Si fue exitoso, sumamos el balance local
      addLocalBalance(points);
      
    } catch (e) {
      _error = 'No se pudieron guardar los puntos: $e';
      if (!_disposed) notifyListeners();
      // Relanzamos el error por si la pantalla necesita mostrar un snackbar
      throw Exception('Error saving reward: $e');
    }
  }
}
