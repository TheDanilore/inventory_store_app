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

  CategoriesRepositoryImpl(this._supabase);

  Either<Failure, T> _handleError<T>(Object e) {
    if (e is PostgrestException) {
      return left(Failure.from('Error de BD: '));
    }
    return left(Failure.from('Ocurrió un error inesperado: '));
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
      return right(model.toEntity());
    } catch (e) {
      return _handleError(e);
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
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(String id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories({
    bool activeOnly = false,
  }) async {
    try {
      var query = _supabase
          .from('categories')
          .select(
            'id, name, description, is_active, created_at, products:products(count)',
          );
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final response = await query.order('name');
      final models =
          List<Map<String, dynamic>>.from(
            response,
          ).map(CategoryModel.fromJson).toList();
      return right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return _handleError(e);
    }
  }
}
