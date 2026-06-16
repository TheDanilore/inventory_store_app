import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/supplier_credit_models.dart';
import 'package:inventory_store_app/services/admin/supplier_credits_service.dart';

class SupplierCreditsProvider extends ChangeNotifier {
  final SupplierCreditsService _service = SupplierCreditsService();

  List<SupplierCreditModel> _accounts = [];
  List<SupplierCreditModel> get accounts => _accounts;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isBackgroundLoading = false;
  bool get isBackgroundLoading => _isBackgroundLoading;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _withDebtOnly = false;
  bool get withDebtOnly => _withDebtOnly;

  int _currentPage = 0;
  int get currentPage => _currentPage;

  int _totalPages = 1;
  int get totalPages => _totalPages;
  
  static const int _pageSize = 8;

  // Stats
  double _totalDebt = 0;
  double get totalDebt => _totalDebt;

  int _activeAccounts = 0;
  int get activeAccounts => _activeAccounts;

  int _suspendedAccounts = 0;
  int get suspendedAccounts => _suspendedAccounts;

  int _maxedOutAccounts = 0;
  int get maxedOutAccounts => _maxedOutAccounts;

  int _debtCount = 0;
  int get debtCount => _debtCount;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAccounts({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    } else {
      _isBackgroundLoading = true;
      notifyListeners();
    }

    try {
      final result = await _service.fetchAccountsPaginated(
        page: _currentPage,
        pageSize: _pageSize,
        searchQuery: _searchQuery,
        withDebtOnly: _withDebtOnly,
      );

      _accounts = result.accounts;
      _totalPages = result.count == 0 ? 1 : (result.count / _pageSize).ceil();

      if (_currentPage >= _totalPages && _totalPages > 0) {
        _currentPage = _totalPages - 1;
        // Recursive call without showing full loading to adjust page
        _isBackgroundLoading = false;
        return fetchAccounts(showLoading: false);
      }

      _totalDebt = result.stats['totalDebt'] as double;
      _activeAccounts = result.stats['activeAccounts'] as int;
      _suspendedAccounts = result.stats['suspendedAccounts'] as int;
      _maxedOutAccounts = result.stats['maxedOutAccounts'] as int;
      _debtCount = result.stats['debtCount'] as int;

      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _isBackgroundLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _currentPage = 0;
      fetchAccounts(showLoading: false);
    }
  }

  void setWithDebtOnly(bool value) {
    if (_withDebtOnly != value) {
      _withDebtOnly = value;
      _currentPage = 0;
      fetchAccounts();
    }
  }

  void setPage(int page) {
    if (page >= 0 && page < _totalPages && _currentPage != page) {
      _currentPage = page;
      fetchAccounts();
    }
  }

  Future<void> toggleAccountStatus(String creditId, bool currentStatus) async {
    try {
      await _service.toggleAccountStatus(creditId, currentStatus);
      await fetchAccounts(showLoading: false);
    } catch (e) {
      rethrow;
    }
  }
}
