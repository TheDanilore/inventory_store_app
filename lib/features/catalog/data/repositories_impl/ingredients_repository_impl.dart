import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';
import 'package:inventory_store_app/features/catalog/data/models/active_ingredient_model.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/ingredients_repository.dart';

@LazySingleton(as: IngredientsRepository)
class IngredientsRepositoryImpl implements IngredientsRepository {
  final SupabaseClient _supabase;

  IngredientsRepositoryImpl(this._supabase);

  Either<Failure, T> _handleError<T>(Object e, [StackTrace? st]) {
    LoggerService.e(
      'Error en IngredientsRepositoryImpl: $e',
      tag: 'INGREDIENTS_REPO',
      error: e,
      stackTrace: st,
    );
    if (e is PostgrestException) {
      if (e.code == '23503') {
        return left(
          Failure.from(
            'No se puede eliminar: Este componente químico está siendo utilizado en las formulaciones de productos del catálogo. Retíralo de las fichas de los productos antes de eliminarlo.',
          ),
        );
      }
      return left(Failure.from('Error de BD: ${e.message}'));
    }
    return left(
      Failure.from(
        'Ocurrió un error inesperado al procesar la solicitud: ${e.toString()}',
      ),
    );
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
    } catch (e, st) {
      return _handleError(e, st);
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
    } catch (e, st) {
      return _handleError(e, st);
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
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deleteIngredient(String id) async {
    try {
      // 1. Intentar ejecución atómica mediante RPC seguro en Supabase
      try {
        final res = await _supabase.rpc(
          'delete_active_ingredient_safely',
          params: {'p_ingredient_id': id},
        );

        if (res is Map) {
          final success = res['success'] as bool? ?? false;
          final message = res['message'] as String? ?? '';
          if (!success) {
            return left(Failure.from(message));
          }
          return right(null);
        }
      } on PostgrestException catch (rpcError, rpcSt) {
        // Si la RPC aún no ha sido creada en Supabase, pasamos al fallback local
        final isMissingRpc = rpcError.code == 'PGRST202' ||
            rpcError.message.contains('function') &&
                rpcError.message.contains('does not exist');

        if (!isMissingRpc) {
          return _handleError(rpcError, rpcSt);
        }
      }

      // 2. Fallback con verificación relacional previa que extrae los nombres de los productos
      final usages = await _supabase
          .from('product_active_ingredients')
          .select('product_id, products(name)')
          .eq('ingredient_id', id);

      if (usages.isNotEmpty) {
        final productList = (usages as List).map((u) {
          final productMap = u['products'] as Map<String, dynamic>?;
          return productMap?['name'] as String? ?? 'Producto';
        }).take(3).join(', ');

        final count = (usages as List).length;
        final extraText = count > 3 ? ' entre otros' : '';

        return left(
          Failure.from(
            'No se puede eliminar: Este componente está asignado en $count ${count == 1 ? "producto" : "productos"} del catálogo '
            '($productList$extraText). Debes desvincularlo de las fichas de los productos antes de eliminarlo.',
          ),
        );
      }

      await _supabase.from('active_ingredients').delete().eq('id', id);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
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
