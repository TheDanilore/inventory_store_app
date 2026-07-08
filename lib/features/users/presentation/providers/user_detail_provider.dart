import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserDetailProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _user;
  Map<String, dynamic>? get user => _user;

  List<Map<String, dynamic>> _recentMovements = [];
  List<Map<String, dynamic>> get recentMovements => _recentMovements;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  // Constructor que recibe la data inicial
  UserDetailProvider({required Map<String, dynamic> initialUser}) {
    _user = Map<String, dynamic>.from(initialUser);
    _loadRecentMovements(initialUser['id']);
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> _loadRecentMovements(String userId) async {
    try {
      final res = await _supabase
          .from('wallet_movements')
          .select('id, points, movement_type, description, created_at')
          .eq('profile_id', userId)
          .order('created_at', ascending: false)
          .limit(5);

      _recentMovements = List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      // Ignorar el error de historial, no es crítico
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> adjustPoints(int amount) async {
    if (amount == 0 || _user == null) return;

    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final String profileId = _user!['id'];
      final int currentBalance = _user!['wallet_balance'] ?? 0;
      final int newBalance = (currentBalance + amount).clamp(0, 9999999);

      // Usar una función RPC o simplemente un update si se confía en el admin
      await _supabase
          .from('profiles')
          .update({'wallet_balance': newBalance})
          .eq('id', profileId);

      await _supabase.from('wallet_movements').insert({
        'profile_id': profileId,
        'points': amount,
        'movement_type': 'MANUAL_BONUS',
        'description':
            amount > 0
                ? 'Abono manual de administrador'
                : 'Descuento manual de administrador',
      });

      _user!['wallet_balance'] = newBalance;
      _successMessage = 'Saldo actualizado correctamente';

      // Recargar historial silenciosamente
      await _loadRecentMovements(profileId);
    } catch (e) {
      debugPrint('Error updating balance: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al actualizar saldo.';
      }
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> reloadUser() async {
    if (_user == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final updated =
          await _supabase
              .from('profiles_with_email')
              .select()
              .eq('id', _user!['id'])
              .single();

      _user = Map<String, dynamic>.from(updated);
      await _loadRecentMovements(_user!['id']);
    } catch (e) {
      debugPrint('Error reloading user: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al recargar usuario.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
