import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class ActiveIngredientsProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> get ingredients => _ingredients;

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

  int _totalIngredients = 0;
  int get totalIngredients => _totalIngredients;

  static const int _pageSize = 12;
  Timer? _debounceTimer;

  ActiveIngredientsProvider() {
    fetchIngredients();
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
      fetchIngredients();
    });
    
    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    _currentPage = 0;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    fetchIngredients();
  }

  void setPage(int page) {
    if (page == _currentPage) return;
    _currentPage = page;
    fetchIngredients();
  }

  Future<void> fetchIngredients() async {
    _isLoading = true;
    notifyListeners();

    try {
      var selectQuery = _supabase.from('active_ingredients').select();
      
      if (_searchQuery.isNotEmpty) {
        selectQuery = selectQuery.ilike('name', '%$_searchQuery%');
      }

      var countQuery = _supabase.from('active_ingredients').select('id');
      if (_searchQuery.isNotEmpty) {
        countQuery = countQuery.ilike('name', '%$_searchQuery%');
      }
      
      final countRes = await countQuery.count(CountOption.exact);
      _totalIngredients = countRes.count;
      _totalPages = (_totalIngredients / _pageSize).ceil();
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

      _ingredients = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error en fetchIngredients: $e');
      _ingredients = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveIngredient(
    BuildContext context, {
    Map<String, dynamic>? existingIngredient,
    required String name,
    required String description,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    notifyListeners();

    try {
      final payload = {
        'name': name.trim(),
        'description': description.trim().isNotEmpty ? description.trim() : null,
      };

      if (existingIngredient != null) {
        await _supabase
            .from('active_ingredients')
            .update(payload)
            .eq('id', existingIngredient['id']);
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: 'Componente actualizado',
            type: SnackbarType.success,
          );
        }
      } else {
        await _supabase.from('active_ingredients').insert(payload);
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: 'Componente creado',
            type: SnackbarType.success,
          );
        }
      }

      await fetchIngredients();
      return true;
    } catch (e) {
      debugPrint('Error saving active ingredient: $e');
      if (context.mounted) {
        final errStr = e.toString().toLowerCase();
        String msg = 'Error inesperado al guardar.';
        if (errStr.contains('active_ingredients_name_key')) {
          msg = 'Ya existe un componente con ese nombre.';
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

  Future<void> deleteIngredient(BuildContext context, String id, String name) async {
    if (_isSaving) return;

    _isSaving = true;
    notifyListeners();

    try {
      await _supabase.from('active_ingredients').delete().eq('id', id);
      await fetchIngredients();
      
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'Componente eliminado',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      debugPrint('Error deleting active ingredient: $e');
      if (context.mounted) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('foreign key violation') || errStr.contains('violates foreign key constraint')) {
          AppSnackbar.show(
            context,
            message: 'No puedes borrar "$name" porque hay productos que usan este componente.',
            type: SnackbarType.error,
            duration: const Duration(seconds: 4),
          );
        } else {
          String msg = 'Error al borrar el componente.';
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
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
