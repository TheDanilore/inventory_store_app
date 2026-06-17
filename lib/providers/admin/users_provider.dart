import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final String role;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> get users => _users;

  // Paginación
  static const int pageSize = 8;
  int _currentPage = 0;
  int get currentPage => _currentPage;
  int _totalCount = 0;
  int get totalPages => _totalCount == 0 ? 1 : (_totalCount / pageSize).ceil();
  int get totalCount => _totalCount;

  // Para evitar llamadas innecesarias si los filtros no cambiaron
  String _lastSearchQuery = '';
  bool _lastOnlyActive = false;

  UsersProvider({required this.role});

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void setPage(int page, String searchQuery, bool onlyActive) {
    if (page < 0 || page >= totalPages || page == _currentPage) return;
    _currentPage = page;
    _loadUsers(searchQuery, onlyActive);
  }

  Future<void> fetchUsers(String searchQuery, bool onlyActive) async {
    // Si cambian los filtros, volvemos a la página 0
    if (_lastSearchQuery != searchQuery || _lastOnlyActive != onlyActive) {
      _currentPage = 0;
    }
    await _loadUsers(searchQuery, onlyActive);
  }

  Future<void> refresh() async {
    _currentPage = 0;
    await _loadUsers(_lastSearchQuery, _lastOnlyActive);
  }

  Future<void> _loadUsers(String searchQuery, bool onlyActive) async {
    _lastSearchQuery = searchQuery;
    _lastOnlyActive = onlyActive;

    _isLoading = true;
    _errorMessage = null;
    // Agendamos el notifyListeners para evitar errores de state si se llama durante el build
    Future.microtask(() => notifyListeners());

    try {
      var query = _supabase.from('profiles_with_email').select('*');

      query = query.eq('role', role);

      if (onlyActive) {
        query = query.eq('is_active', true);
      }

      final term = searchQuery.trim();
      if (term.isNotEmpty) {
        query = query.or(
          'full_name.ilike.%$term%,phone.ilike.%$term%,document_number.ilike.%$term%,email.ilike.%$term%',
        );
      }

      final start = _currentPage * pageSize;
      final end = start + pageSize - 1;

      final response = await query
          .order('created_at', ascending: false)
          .range(start, end)
          .count(CountOption.exact);

      _totalCount = response.count;
      _users = List<Map<String, dynamic>>.from(response.data as List);
    } catch (e) {
      debugPrint('Error loading users: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al cargar usuarios.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleUserStatus(String userId, bool currentStatus) async {
    try {
      await _supabase
          .from('profiles')
          .update({'is_active': !currentStatus})
          .eq('id', userId);

      final index = _users.indexWhere((u) => u['id'] == userId);
      if (index != -1) {
        _users[index] = {..._users[index], 'is_active': !currentStatus};
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error toggling user status: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al cambiar estado.';
      }
      notifyListeners();
      return false;
    }
  }
}
