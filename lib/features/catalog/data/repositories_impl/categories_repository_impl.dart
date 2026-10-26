import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/data/models/category_model.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/categories_repository.dart';

@LazySingleton(as: CategoriesRepository)
class CategoriesRepositoryImpl implements CategoriesRepository {
  final SupabaseClient _supabase;

  // ─── CACHÉ L1 EN MEMORIA (TTL: 15 MINUTOS) ──────────────────────────────
  List<CategoryEntity>? _categoriesCache;
  DateTime? _cacheTimestamp;
  static const Duration _cacheTtl = Duration(minutes: 15);

  void _invalidateCache() {
    _categoriesCache = null;
    _cacheTimestamp = null;
  }

  @override
  List<CategoryEntity>? getCachedCategories({bool activeOnly = false}) {
    if (_categoriesCache != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < _cacheTtl) {
        if (activeOnly) {
          return _categoriesCache!.where((c) => c.isActive).toList();
        }
        return _categoriesCache;
      }
    }
    return null;
  }

  CategoriesRepositoryImpl(this._supabase);

  Either<Failure, T> _handleError<T>(Object e, [StackTrace? st]) {
    LoggerService.e(
      'Error en CategoriesRepositoryImpl',
      tag: 'CATEGORIES_REPO',
      error: e,
      stackTrace: st,
    );
    if (e is PostgrestException) {
      if (e.code == '23503') {
        return left(
          Failure.from(
            'No se puede eliminar: Esta categoría está asociada a productos en el catálogo. Reasígnalos o desactiva la categoría.',
          ),
        );
      }
      return left(Failure.from('Error de BD: ${e.message}'));
    }
    return left(Failure.from('Ocurrió un error inesperado: ${e.toString()}'));
  }

  @override
  Future<Either<Failure, CategoryEntity>> createCategory({
    required String name,
    String? description,
    required bool isActive,
    String? profileId,
  }) async {
    try {
      final response =
          await _supabase
              .from('categories')
              .insert({
                'name': name.trim(),
                'description': description?.trim(),
                'is_active': isActive,
                if (profileId != null) 'created_by': profileId,
              })
              .select()
              .single();
      final model = CategoryModel.fromJson(response);
      _invalidateCache();
      return right(model.toEntity());
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> updateCategory({
    required String id,
    required String name,
    String? description,
    required bool isActive,
    String? profileId,
  }) async {
    try {
      await _supabase
          .from('categories')
          .update({
            'name': name.trim(),
            'description': description?.trim(),
            'is_active': isActive,
            if (profileId != null) 'updated_by': profileId,
          })
          .eq('id', id);
      _invalidateCache();
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(String id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
      _invalidateCache();
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories({
    bool activeOnly = false,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = getCachedCategories(activeOnly: activeOnly);
      if (cached != null) {
        return right(cached);
      }
    }

    try {
      var query = _supabase
          .from('categories')
          .select(
            'id, name, description, is_active, created_at, products:products(count)',
          );
      final response = await query.order('name');
      final models =
          List<Map<String, dynamic>>.from(
            response,
          ).map(CategoryModel.fromJson).toList();
      final allCategories = models.map((m) => m.toEntity()).toList();

      _categoriesCache = allCategories;
      _cacheTimestamp = DateTime.now();

      if (activeOnly) {
        return right(allCategories.where((c) => c.isActive).toList());
      }
      return right(allCategories);
    } catch (e, st) {
      if (_categoriesCache != null) {
        if (activeOnly) {
          return right(_categoriesCache!.where((c) => c.isActive).toList());
        }
        return right(_categoriesCache!);
      }
      return _handleError(e, st);
    }
  }
}
