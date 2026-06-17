import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class CategoriesProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => _categories;

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

  int _totalCategories = 0;
  int get totalCategories => _totalCategories;

  static const int _pageSize = 8;
  Timer? _debounceTimer;

  CategoriesProvider() {
    fetchCategories();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void onSearchChanged(String query) {
    _searchQuery = query;
    _currentPage = 0; // Regresar a pag 1

    // Cancelar el timer anterior si el usuario sigue escribiendo
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    // Iniciar nuevo timer
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      fetchCategories();
    });
    
    // Podemos notificar para que aparezca el loading opcionalmente, 
    // pero el debounce ya hará el fetch que setea isLoading.
    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    _currentPage = 0;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    fetchCategories();
  }

  void setPage(int page) {
    if (page == _currentPage) return;
    _currentPage = page;
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Count option para saber total.
      // Para contar productos relacionados sin traer el arreglo:
      // 'id, name, description, is_active, products(count)'
      // Mejor traemos '*, products(count)'. No, count no cuenta products si hay filtro en productos.
      // Para contar productos relacionados sin traer el arreglo:
      // 'id, name, description, is_active, products(count)'
      
      var selectQuery = _supabase
          .from('categories')
          .select('id, name, description, is_active, products(count)');
      
      // Aplicar filtro
      if (_searchQuery.isNotEmpty) {
        selectQuery = selectQuery.ilike('name', '%$_searchQuery%');
      }

      // Obtener el conteo total para la paginación con el mismo filtro
      var countQuery = _supabase.from('categories').select('id');
      if (_searchQuery.isNotEmpty) {
        countQuery = countQuery.ilike('name', '%$_searchQuery%');
      }
      
      final countRes = await countQuery.count(CountOption.exact);
      _totalCategories = countRes.count;
      _totalPages = (_totalCategories / _pageSize).ceil();
      if (_totalPages == 0) _totalPages = 1;
      
      if (_currentPage >= _totalPages) {
        _currentPage = _totalPages - 1;
        if (_currentPage < 0) _currentPage = 0;
      }

      // Aplicar paginación
      final start = _currentPage * _pageSize;
      final end = start + _pageSize - 1;

      final response = await selectQuery
          .order('name', ascending: true)
          .range(start, end);

      _categories = (response as List).map((e) => CategoryModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error en fetchCategories: $e');
      _categories = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleStatus(BuildContext context, CategoryModel cat, bool isActive) async {
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

      await _supabase
          .from('categories')
          .update({
            'is_active': isActive,
            if (profileId != null) 'updated_by': profileId,
          })
          .eq('id', cat.id!);

      // Actualizar localmente para no hacer refetch completo si no es necesario
      final index = _categories.indexWhere((c) => c.id == cat.id);
      if (index != -1) {
        _categories[index] = CategoryModel(
          id: cat.id,
          name: cat.name,
          description: cat.description,
          isActive: isActive,
          createdAt: cat.createdAt,
          productsCount: cat.productsCount,
        );
        notifyListeners();
      }

      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: isActive ? 'Categoría activada' : 'Categoría desactivada',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      debugPrint('Error toggling category status: $e');
      if (context.mounted) {
        final errStr = e.toString().toLowerCase();
        String msg = 'Error al cambiar estado.';
        if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
          msg = 'Sin conexión a internet.';
        }
        AppSnackbar.show(
          context,
          message: msg,
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<bool> saveCategory(
    BuildContext context, {
    CategoryModel? existingCategory,
    required String name,
    required String description,
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

      if (existingCategory == null) {
        await _supabase.from('categories').insert({
          'name': name.trim(),
          'description': description.trim().isNotEmpty ? description.trim() : null,
          'is_active': isActive,
          if (profileId != null) 'created_by': profileId,
        });
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: 'Categoría creada',
            type: SnackbarType.success,
          );
        }
      } else {
        await _supabase
            .from('categories')
            .update({
              'name': name.trim(),
              'description': description.trim().isNotEmpty ? description.trim() : null,
              'is_active': isActive,
              if (profileId != null) 'updated_by': profileId,
            })
            .eq('id', existingCategory.id!);
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: 'Categoría actualizada',
            type: SnackbarType.success,
          );
        }
      }

      // Refrescar lista después de guardar
      await fetchCategories();
      return true;
    } catch (e) {
      debugPrint('Error saving category: $e');
      if (context.mounted) {
        final errStr = e.toString().toLowerCase();
        String msg = 'Error inesperado al guardar la categoría.';
        if (errStr.contains('categories_name_key')) {
          msg = 'Ya existe una categoría con ese nombre.';
        } else if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
          msg = 'Sin conexión a internet.';
        }
        AppSnackbar.show(
          context,
          message: msg,
          type: SnackbarType.error,
        );
      }
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
