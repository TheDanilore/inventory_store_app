import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/customer_credit_models.dart';
import 'package:inventory_store_app/services/admin/customer_credits_service.dart';

class CustomerCreditsProvider extends ChangeNotifier {
  final _service = CustomerCreditsService();

  static const int pageSize = 8;

  List<CreditAccountModel> _accounts = [];
  int _totalAccounts = 0;
  bool _isLoading = false;
  String _errorMessage = '';

  int _currentPage = 0;
  String _searchQuery = '';
  bool _withDebtOnly = false;

  // Métricas
  double _totalDebt = 0;
  int _activeAccounts = 0;
  int _suspendedAccounts = 0;
  int _maxedOutAccounts = 0;

  // Getters
  List<CreditAccountModel> get accounts => _accounts;
  int get totalAccounts => _totalAccounts;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  int get currentPage => _currentPage;
  int get totalPages =>
      _totalAccounts == 0 ? 1 : (_totalAccounts / pageSize).ceil();

  String get searchQuery => _searchQuery;
  bool get withDebtOnly => _withDebtOnly;

  double get totalDebt => _totalDebt;
  int get activeAccounts => _activeAccounts;
  int get suspendedAccounts => _suspendedAccounts;
  int get maxedOutAccounts => _maxedOutAccounts;

  void init() {
    _currentPage = 0;
    _searchQuery = '';
    _withDebtOnly = false;
    fetchPage();
  }

  Future<void> fetchPage() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final res = await _service.fetchAccountsPaginated(
        page: _currentPage,
        pageSize: pageSize,
        searchQuery: _searchQuery,
        withDebtOnly: _withDebtOnly,
      );

      _accounts = res.accounts;
      _totalAccounts = res.count;

      _totalDebt = res.stats['totalDebt'] as double;
      _activeAccounts = res.stats['activeAccounts'] as int;
      _suspendedAccounts = res.stats['suspendedAccounts'] as int;
      _maxedOutAccounts = res.stats['maxedOutAccounts'] as int;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setPage(int page) {
    if (page >= 0 && page < totalPages) {
      _currentPage = page;
      fetchPage();
    }
  }

  void setSearch(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _currentPage = 0;
      fetchPage();
    }
  }

  void setTab(int index) {
    bool nextDebtOnly = index == 1;
    if (_withDebtOnly != nextDebtOnly) {
      _withDebtOnly = nextDebtOnly;
      _currentPage = 0;
      fetchPage();
    }
  }

  // Suspender/Reactivar
  Future<void> toggleAccountStatus(CreditAccountModel account) async {
    try {
      await _service.toggleAccountStatus(account.creditId, account.isActive);
      await fetchPage(); // Refrescar para ver el nuevo estado
    } catch (e) {
      rethrow;
    }
  }
}
