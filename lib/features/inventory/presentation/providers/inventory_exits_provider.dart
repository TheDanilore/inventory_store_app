import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_exit_model.dart';
import 'package:inventory_store_app/features/inventory/data/repositories/inventory_exits_service.dart';

class InventoryExitsProvider extends ChangeNotifier {
  final InventoryExitsService _service = InventoryExitsService();

  // ── ESTADO DE LA LISTA ──
  List<InventoryExitModel> _exits = [];
  List<InventoryExitModel> get exits => _exits;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── PAGINACIÓN ──
  int _currentPage = 0;
  int _totalRecords = 0;
  final int pageSize = 8;

  int get currentPage => _currentPage;
  int get totalPages =>
      _totalRecords == 0 ? 1 : (_totalRecords / pageSize).ceil();

  // ── FILTROS ──
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  DateTimeRange? _dateRange;
  DateTimeRange? get dateRange => _dateRange;

  // ── MÉTODOS PÚBLICOS ──
  void initLoad() {
    loadExits(isRefresh: true);
  }

  Future<void> loadExits({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 0;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final start = _currentPage * pageSize;
      final end = start + pageSize - 1;

      final response = await _service.getExits(
        start: start,
        end: end,
        searchQuery: _searchQuery,
        dateRange: _dateRange,
      );

      final dataList = response['data'] as List;
      _exits =
          dataList
              .map(
                (e) => InventoryExitModel.fromJson(e as Map<String, dynamic>),
              )
              .toList();
      _totalRecords = response['count'] as int;
    } catch (e) {
      debugPrint('Error loading inventory exits: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al cargar salidas.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void nextPage() {
    if (_currentPage < totalPages - 1) {
      _currentPage++;
      loadExits();
    }
  }

  void previousPage() {
    if (_currentPage > 0) {
      _currentPage--;
      loadExits();
    }
  }

  void changePage(int page) {
    if (page >= 0 && page < totalPages) {
      _currentPage = page;
      loadExits();
    }
  }

  void updateSearch(String query) {
    _searchQuery = query;
    loadExits(isRefresh: true);
  }

  void updateDateRange(DateTimeRange? range) {
    _dateRange = range;
    loadExits(isRefresh: true);
  }

  void clearFilters() {
    _searchQuery = '';
    _dateRange = null;
    loadExits(isRefresh: true);
  }
}
