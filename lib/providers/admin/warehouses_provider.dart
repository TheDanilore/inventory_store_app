import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class WarehousesProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<WarehouseModel> _warehouses = [];
  List<WarehouseModel> get warehouses => _warehouses;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  int _currentPage = 0;
  int get currentPage => _currentPage;

  int _totalPages = 1;
  int get totalPages => _totalPages;

  int _totalWarehouses = 0;
  int get totalWarehouses => _totalWarehouses;

  static const int _pageSize = 8;
  Timer? _debounceTimer;

  WarehousesProvider() {
    fetchWarehouses();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void onSearchChanged(String query) {
    _searchQuery = query;
    _currentPage = 0;

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      fetchWarehouses();
    });
    
    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    _currentPage = 0;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    fetchWarehouses();
  }

  void setPage(int page) {
    if (page == _currentPage) return;
    _currentPage = page;
    fetchWarehouses();
  }

  Future<void> fetchWarehouses() async {
    _isLoading = true;
    notifyListeners();

    try {
      var selectQuery = _supabase.from('warehouses').select();
      
      if (_searchQuery.isNotEmpty) {
        selectQuery = selectQuery.or('name.ilike.%$_searchQuery%,address.ilike.%$_searchQuery%');
      }

      var countQuery = _supabase.from('warehouses').select('id');
      if (_searchQuery.isNotEmpty) {
        countQuery = countQuery.or('name.ilike.%$_searchQuery%,address.ilike.%$_searchQuery%');
      }
      
      final countRes = await countQuery.count(CountOption.exact);
      _totalWarehouses = countRes.count;
      _totalPages = (_totalWarehouses / _pageSize).ceil();
      if (_totalPages == 0) _totalPages = 1;
      
      if (_currentPage >= _totalPages) {
        _currentPage = _totalPages - 1;
        if (_currentPage < 0) _currentPage = 0;
      }

      final start = _currentPage * _pageSize;
      final end = start + _pageSize - 1;

      final res = await selectQuery
          .order('name', ascending: true)
          .range(start, end);

      _warehouses = (res as List).map((e) => WarehouseModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error en fetchWarehouses: $e');
      _warehouses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveWarehouse(
    BuildContext context, {
    WarehouseModel? existingWarehouse,
    required String name,
    required String address,
    required bool isActive,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    notifyListeners();

    try {
      final authUserId = _supabase.auth.currentUser?.id;
      String? profileId;
      if (authUserId != null) {
        final p = await _supabase
            .from('profiles')
            .select('id')
            .eq('auth_user_id', authUserId)
            .maybeSingle();
        profileId = p?['id'] as String?;
      }

      final payload = {
        'name': name.trim(),
        'address': address.trim().isNotEmpty ? address.trim() : null,
        'is_active': isActive,
      };

      if (existingWarehouse != null) {
        if (profileId != null) payload['updated_by'] = profileId;
        await _supabase
            .from('warehouses')
            .update(payload)
            .eq('id', existingWarehouse.id!);
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: 'Almacén actualizado',
            type: SnackbarType.success,
          );
        }
      } else {
        if (profileId != null) payload['created_by'] = profileId;
        await _supabase.from('warehouses').insert(payload);
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: 'Almacén creado exitosamente',
            type: SnackbarType.success,
          );
        }
      }

      await fetchWarehouses();
      return true;
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: e.toString().contains('warehouses_name_key')
              ? 'Ya existe un almacén con ese nombre'
              : 'Error al guardar: $e',
          type: SnackbarType.error,
        );
      }
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> toggleWarehouseStatus(BuildContext context, WarehouseModel wh, bool isActive) async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      String? profileId;
      if (authUserId != null) {
        final p = await _supabase
            .from('profiles')
            .select('id')
            .eq('auth_user_id', authUserId)
            .maybeSingle();
        profileId = p?['id'] as String?;
      }

      await _supabase.from('warehouses').update({
        'is_active': isActive,
        if (profileId != null) 'updated_by': profileId,
      }).eq('id', wh.id!);

      await fetchWarehouses();
      
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: isActive ? 'Almacén activado' : 'Almacén desactivado',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al cambiar estado: $e',
          type: SnackbarType.error,
        );
      }
    }
  }
}
