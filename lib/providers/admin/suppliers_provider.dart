import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/supplier_model.dart';

class SuppliersProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<SupplierModel> _suppliers = [];
  List<SupplierModel> get suppliers => _suppliers;

  // Búsqueda
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // Paginación
  static const int pageSize = 8;
  int _currentPage = 0;
  int get currentPage => _currentPage;
  int _totalCount = 0;
  int get totalPages => _totalCount == 0 ? 1 : (_totalCount / pageSize).ceil();

  SuppliersProvider() {
    _loadSuppliers();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _currentPage = 0;
    _loadSuppliers();
  }

  void setPage(int page) {
    if (page < 0 || page >= totalPages || page == _currentPage) return;
    _currentPage = page;
    _loadSuppliers();
  }

  Future<void> refresh() async {
    _currentPage = 0;
    await _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      var query = _supabase.from('suppliers').select('*');

      final term = _searchQuery.trim();
      if (term.isNotEmpty) {
        // En Supabase or() permite buscar por varios campos
        query = query.or(
          'name.ilike.%$term%,tax_id.ilike.%$term%,contact_name.ilike.%$term%',
        );
      }

      final start = _currentPage * pageSize;
      final end = start + pageSize - 1;

      final response = await query
          .order('name', ascending: true)
          .range(start, end)
          .count(CountOption.exact);

      _totalCount = response.count;
      _suppliers =
          (response.data as List)
              .map((e) => SupplierModel.fromJson(e))
              .toList();
    } catch (e) {
      _errorMessage = 'Error al cargar proveedores: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleSupplierStatus(SupplierModel supplier) async {
    try {
      await _supabase
          .from('suppliers')
          .update({'is_active': !supplier.isActive})
          .eq('id', supplier.id);

      // Actualizar localmente para no hacer un reload entero
      final index = _suppliers.indexWhere((s) => s.id == supplier.id);
      if (index != -1) {
        _suppliers[index] = supplier.copyWith(isActive: !supplier.isActive);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error al cambiar estado: $e';
      notifyListeners();
      rethrow;
    }
  }
}
