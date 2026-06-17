import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/financial_account_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinancialAccountsProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<FinancialAccountModel> _accounts = [];
  bool _isLoading = false;
  String _errorMessage = '';

  // Pagination (Server side if needed, but since accounts are few, we can fetch all or paginate local. Let's fetch all active or paginated)
  int _currentPage = 0;
  final int _pageSize = 10;
  int _totalCount = 0;

  List<FinancialAccountModel> get accounts => _accounts;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  int get currentPage => _currentPage;
  int get totalPages => _totalCount == 0 ? 1 : (_totalCount / _pageSize).ceil();

  Future<void> fetchAccounts({int page = 0}) async {
    _isLoading = true;
    _errorMessage = '';
    _currentPage = page;
    notifyListeners();

    try {
      final start = page * _pageSize;
      final end = start + _pageSize - 1;

      final response = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance, is_active, created_at')
          .order('is_active', ascending: false)
          .order('name')
          .range(start, end)
          .count(CountOption.exact);

      _totalCount = response.count;
      final data = response.data as List;
      
      _accounts = data.map((e) => FinancialAccountModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('Error loading financial accounts: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al cargar cuentas financieras.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setPage(int page) {
    if (page >= 0 && page < totalPages) {
      fetchAccounts(page: page);
    }
  }

  Future<void> saveAccount({
    required String name,
    required String type,
    required bool isActive,
    double? initialBalance,
    String? accountId,
  }) async {
    if (accountId != null) {
      await _supabase
          .from('financial_accounts')
          .update({
            'name': name,
            'type': type,
            'is_active': isActive,
          })
          .eq('id', accountId);
    } else {
      await _supabase.from('financial_accounts').insert({
        'name': name,
        'type': type,
        'balance': initialBalance ?? 0.0,
        'is_active': isActive,
      });
    }
    await fetchAccounts(page: _currentPage);
  }
}
