import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';
import 'package:inventory_store_app/features/catalog/data/models/active_ingredient_model.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/ingredients_repository.dart';

@LazySingleton(as: IngredientsRepository)
class IngredientsRepositoryImpl implements IngredientsRepository {
  final SupabaseClient _supabase;

  IngredientsRepositoryImpl(this._supabase);

  Either<Failure, T> _handleError<T>(Object e) {
    if (e is PostgrestException) {
      return left(Failure.from('Error de BD: '));
    }
    return left(Failure.from('Ocurrió un error inesperado: '));
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getProductIngredients(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('product_active_ingredients')
          .select(
            'ingredient_id, concentration, unit, active_ingredients(name)',
          )
          .eq('product_id', productId);
      return right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, List<ActiveIngredientEntity>>> searchIngredients(
    String term,
  ) async {
    try {
      final response = await _supabase.rpc(
        'search_ingredients_unaccent',
        params: {'search_term': term},
      );
      final models =
          List<Map<String, dynamic>>.from(
            response,
          ).map(ActiveIngredientModel.fromJson).toList();
      return right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, ActiveIngredientEntity>> createIngredient(
    String name,
  ) async {
    try {
      final response =
          await _supabase
              .from('active_ingredients')
              .insert({'name': name.trim()})
              .select()
              .single();
      return right(ActiveIngredientModel.fromJson(response).toEntity());
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> updateIngredient(String id, String name) async {
    try {
      await _supabase
          .from('active_ingredients')
          .update({'name': name.trim()})
          .eq('id', id);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> deleteIngredient(String id) async {
    try {
      await _supabase.from('active_ingredients').delete().eq('id', id);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, List<ActiveIngredientEntity>>> getIngredients({
    String? searchQuery,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('active_ingredients').select();
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('name', '%${searchQuery.trim()}%');
      }
      final response = await query
          .order('name')
          .range(offset, offset + limit - 1);
      final models =
          List<Map<String, dynamic>>.from(
            response,
          ).map(ActiveIngredientModel.fromJson).toList();
      return right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> clearProductIngredients(
    String productId,
  ) async {
    try {
      await _supabase
          .from('product_active_ingredients')
          .delete()
          .eq('product_id', productId);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> insertProductIngredient(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _supabase.from('product_active_ingredients').insert(payload);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }
}
