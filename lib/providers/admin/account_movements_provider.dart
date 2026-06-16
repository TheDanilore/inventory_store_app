import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/account_movement_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountMovementsProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<AccountMovementModel> _movements = [];
  bool _isLoading = false;
  String _errorMessage = '';

  // Pagination
  int _currentPage = 0;
  final int _pageSize = 15;
  int _totalCount = 0;

  // Filters
  String _filterType = 'Todos'; // Todos, INCOME, EXPENSE, TRANSFER
  String _filterAccountId = 'Todas';
  String _searchText = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // Totals for current filter
  double _totalIncome = 0;
  double _totalExpense = 0;

  List<AccountMovementModel> get movements => _movements;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  int get currentPage => _currentPage;
  int get totalPages => _totalCount == 0 ? 1 : (_totalCount / _pageSize).ceil();

  String get filterType => _filterType;
  String get filterAccountId => _filterAccountId;
  String get searchText => _searchText;
  DateTime? get dateFrom => _dateFrom;
  DateTime? get dateTo => _dateTo;

  double get totalIncome => _totalIncome;
  double get totalExpense => _totalExpense;

  void setFilterType(String type) {
    _filterType = type;
    _currentPage = 0;
    fetchMovements();
  }

  void setFilterAccount(String accountId) {
    _filterAccountId = accountId;
    _currentPage = 0;
    fetchMovements();
  }

  void setSearchText(String text) {
    _searchText = text;
    _currentPage = 0;
    fetchMovements();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    _dateFrom = from;
    _dateTo = to;
    _currentPage = 0;
    fetchMovements();
  }

  void setPage(int page) {
    if (page >= 0 && page < totalPages) {
      _currentPage = page;
      fetchMovements();
    }
  }

  Future<void> fetchMovements() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final start = _currentPage * _pageSize;
      final end = start + _pageSize - 1;

      var query = _supabase
          .from('account_movements')
          .select('id, movement_type, amount, description, reference_type, reference_id, created_at, financial_accounts!inner(id, name, type), profiles!inner(full_name)');

      if (_filterType != 'Todos') {
        query = query.eq('movement_type', _filterType);
      }
      if (_filterAccountId != 'Todas') {
        query = query.eq('account_id', _filterAccountId);
      }
      if (_searchText.isNotEmpty) {
        query = query.ilike('description', '%$_searchText%');
      }
      if (_dateFrom != null) {
        query = query.gte('created_at', _dateFrom!.toIso8601String());
      }
      if (_dateTo != null) {
        query = query.lte('created_at', _dateTo!.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(start, end)
          .count(CountOption.exact);

      _totalCount = response.count;
      final data = response.data as List;

      _movements = data.map((e) => AccountMovementModel.fromJson(Map<String, dynamic>.from(e))).toList();

      // We need to calculate global totals for the filtered data without pagination. 
      // If we really want accurate totals, we might need a separate sum query. 
      // For now, if we do a sum query:
      await _fetchTotals();

    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchTotals() async {
    try {
      var query = _supabase.from('account_movements').select('movement_type, amount');
      
      if (_filterType != 'Todos') query = query.eq('movement_type', _filterType);
      if (_filterAccountId != 'Todas') query = query.eq('account_id', _filterAccountId);
      if (_searchText.isNotEmpty) query = query.ilike('description', '%$_searchText%');
      if (_dateFrom != null) query = query.gte('created_at', _dateFrom!.toIso8601String());
      if (_dateTo != null) query = query.lte('created_at', _dateTo!.toIso8601String());

      final res = await query as List;
      _totalIncome = 0;
      _totalExpense = 0;
      for (final item in res) {
        final amt = (item['amount'] as num).toDouble();
        if (item['movement_type'] == 'INCOME') _totalIncome += amt;
        if (item['movement_type'] == 'EXPENSE') _totalExpense += amt;
      }
    } catch (_) {}
  }
}
