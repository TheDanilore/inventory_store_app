import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/cash_shift_model.dart';
import 'package:inventory_store_app/models/financial_account_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CashShiftsProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<CashShiftModel> _shifts = [];
  List<FinancialAccountModel> _cajaAccounts = [];
  Set<String> _openAccountIds = {};

  bool _isLoading = false;
  String _errorMessage = '';

  // Pagination
  int _currentPage = 0;
  final int _pageSize = 15;
  int _totalCount = 0;

  // Filters
  String _filterStatus = 'Todos'; // Todos, OPEN, CLOSED
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _profileFilter;

  List<CashShiftModel> get shifts => _shifts;
  List<FinancialAccountModel> get cajaAccounts => _cajaAccounts;
  Set<String> get openAccountIds => _openAccountIds;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  int get currentPage => _currentPage;
  int get totalPages => _totalCount == 0 ? 1 : (_totalCount / _pageSize).ceil();

  String get filterStatus => _filterStatus;
  DateTime? get dateFrom => _dateFrom;
  DateTime? get dateTo => _dateTo;

  int get openCount => _shifts.where((s) => s.status == 'OPEN').length; // Local count from total? Better if we can do a count query, but for now we'll do local on loaded shifts if we fetch all opens? Actually, if paginated, we need a count query.
  
  // Total Open / Closed overall
  int _totalOpenCount = 0;
  int _totalClosedCount = 0;

  int get totalOpenCount => _totalOpenCount;
  int get totalClosedCount => _totalClosedCount;

  void setFilterStatus(String status) {
    _filterStatus = status;
    _currentPage = 0;
    fetchShifts();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    _dateFrom = from;
    _dateTo = to;
    _currentPage = 0;
    fetchShifts();
  }

  void setPage(int page) {
    if (page >= 0 && page < totalPages) {
      _currentPage = page;
      fetchShifts();
    }
  }

  void setProfileFilter(String? profileId) {
    if (_profileFilter != profileId) {
      _profileFilter = profileId;
      _currentPage = 0;
      fetchShifts();
    }
  }

  Future<void> fetchShifts() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // 1. Fetch Caja accounts
      final accountsRes = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .eq('type', 'CAJA')
          .order('name');
      
      _cajaAccounts = (accountsRes as List)
          .map((e) => FinancialAccountModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // 2. Fetch total open/closed counts
      await _fetchCounts();

      // 3. Fetch shifts with pagination and filters
      final start = _currentPage * _pageSize;
      final end = start + _pageSize - 1;

      var query = _supabase
          .from('cash_shifts')
          .select('''
            id, status, opening_amount, expected_amount, actual_amount,
            difference_amount, notes, opened_at, closed_at, account_id,
            financial_accounts!inner(id, name, type),
            opened_by_profile:profiles!cash_shifts_opened_by_fkey(full_name),
            closed_by_profile:profiles!cash_shifts_closed_by_fkey(full_name)
          ''');

      if (_filterStatus != 'Todos') {
        query = query.eq('status', _filterStatus);
      }
      if (_dateFrom != null) {
        query = query.gte('opened_at', _dateFrom!.toIso8601String());
      }
      if (_dateTo != null) {
        query = query.lte('opened_at', _dateTo!.toIso8601String());
      }
      if (_profileFilter != null) {
        query = query.eq('opened_by', _profileFilter!);
      }

      final response = await query
          .order('status', ascending: false) // OPEN first
          .order('opened_at', ascending: false)
          .range(start, end)
          .count(CountOption.exact);

      _totalCount = response.count;
      final data = response.data as List;
      _shifts = data.map((e) => CashShiftModel.fromJson(Map<String, dynamic>.from(e))).toList();

      // Update open account ids
      final openShiftsRes = await _supabase.from('cash_shifts').select('account_id').eq('status', 'OPEN');
      _openAccountIds = (openShiftsRes as List)
          .map((s) => s['account_id'])
          .whereType<String>()
          .toSet();

    } catch (e) {
      debugPrint('Error loading cash shifts: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al cargar los turnos de caja.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchCounts() async {
    try {
      var openQuery = _supabase.from('cash_shifts').select('id').eq('status', 'OPEN');
      var closedQuery = _supabase.from('cash_shifts').select('id').eq('status', 'CLOSED');

      if (_profileFilter != null) {
        openQuery = openQuery.eq('opened_by', _profileFilter!);
        closedQuery = closedQuery.eq('opened_by', _profileFilter!);
      }

      final openRes = await openQuery.count(CountOption.exact);
      _totalOpenCount = openRes.count;
      
      final closedRes = await closedQuery.count(CountOption.exact);
      _totalClosedCount = closedRes.count;
    } catch (_) {}
  }

  Future<double> calcExpected(String shiftId, String accountId, double openingAmount) async {
    final movRes = await _supabase
        .from('account_movements')
        .select('movement_type, amount')
        .eq('account_id', accountId)
        .eq('shift_id', shiftId);

    final movs = (movRes as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    double income = 0;
    double expense = 0;
    for (final m in movs) {
      final amt = (m['amount'] as num).toDouble();
      if (m['movement_type'] == 'INCOME') income += amt;
      if (m['movement_type'] == 'EXPENSE') expense += amt;
    }
    return openingAmount + income - expense;
  }
}
