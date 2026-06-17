import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/inventory_entry_model.dart';
import 'package:inventory_store_app/services/admin/inventory_entries_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryEntriesProvider extends ChangeNotifier {
  final InventoryEntriesService _service = InventoryEntriesService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── ESTADO DE LA LISTA ──
  List<InventoryEntryModel> _entries = [];
  List<InventoryEntryModel> get entries => _entries;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // ── FILTROS ──
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _warehouseFilter = 'Todos';
  String get warehouseFilter => _warehouseFilter;

  DateTimeRange? _dateRange;
  DateTimeRange? get dateRange => _dateRange;

  List<String> _availableWarehouses = ['Todos'];
  List<String> get availableWarehouses => _availableWarehouses;

  // ── PAGINACIÓN CON BOTONES ──
  static const int pageSize = 8;
  int _currentPage = 0; // 0-indexed
  int _totalRecords = 0;

  int get currentPage => _currentPage;
  int get totalPages => (_totalRecords / pageSize).ceil();

  // ── INIT ──
  Future<void> init() async {
    await _loadWarehouses();
    await loadEntries(page: 0);
  }

  Future<void> _loadWarehouses() async {
    try {
      final resp = await _supabase
          .from('warehouses')
          .select('name')
          .eq('is_active', true);
      final whs = (resp as List).map((w) => w['name'] as String).toList();
      _availableWarehouses = ['Todos', ...whs];
    } catch (e) {
      debugPrint('Error cargando almacenes: $e');
    }
  }

  Future<void> loadEntries({required int page}) async {
    _isLoading = true;
    _errorMessage = '';
    _currentPage = page;
    notifyListeners();

    try {
      final start = _currentPage * pageSize;
      final end = start + pageSize - 1;

      final response = await _service.getEntries(
        start: start,
        end: end,
        searchQuery: _searchQuery,
        warehouseFilter: _warehouseFilter,
        dateRange: _dateRange,
      );

      final dataList = response['data'] as List;
      _entries =
          dataList
              .map(
                (e) => InventoryEntryModel.fromJson(e as Map<String, dynamic>),
              )
              .toList();
      _totalRecords = response['count'] as int;
    } catch (e) {
      debugPrint('Error loading inventory entries: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al cargar entradas.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── METODOS DE FILTRO ──
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    loadEntries(page: 0);
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void setWarehouseFilter(String warehouse) {
    if (_warehouseFilter == warehouse) return;
    _warehouseFilter = warehouse;
    loadEntries(page: 0);
  }

  void setDateRange(DateTimeRange? range) {
    _dateRange = range;
    loadEntries(page: 0);
  }

  void clearFilters() {
    _searchQuery = '';
    _warehouseFilter = 'Todos';
    _dateRange = null;
    loadEntries(page: 0);
  }

  // ── PAGINACIÓN MANUAL ──
  void goToPage(int page) {
    if (page < 0 || page >= totalPages || page == _currentPage) return;
    loadEntries(page: page);
  }
}
