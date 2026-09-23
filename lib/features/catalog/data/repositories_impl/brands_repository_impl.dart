import 'dart:developer' as developer;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';
import 'package:inventory_store_app/features/catalog/data/models/brand_model.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/brands_repository.dart';

@LazySingleton(as: BrandsRepository)
class BrandsRepositoryImpl implements BrandsRepository {
  final SupabaseClient _supabase;

  BrandsRepositoryImpl(this._supabase);

  Either<Failure, T> _handleError<T>(Object e, [StackTrace? st]) {
    developer.log('BrandsRepositoryImpl Error', error: e, stackTrace: st);
    if (e is PostgrestException) {
      if (e.code == '23503') {
        return left(
          Failure.from(
            'No se puede eliminar: Esta marca está asociada a productos en el catálogo. Reasígnalos o desactiva la marca.',
          ),
        );
      }
      if (e.code == '23505') {
        return left(
          Failure.from(
            'Ya existe una marca registrada con ese nombre.',
          ),
        );
      }
      return left(Failure.from('Error de BD: ${e.message}'));
    }
    return left(Failure.from('Ocurrió un error inesperado: ${e.toString()}'));
  }

  @override
  Future<Either<Failure, BrandEntity>> createBrand({
    required String name,
    String? description,
    String? logoUrl,
    String? website,
    required bool isActive,
    String? profileId,
  }) async {
    try {
      final response =
          await _supabase
              .from('brands')
              .insert({
                'name': name.trim(),
                'description': description?.trim(),
                'logo_url': logoUrl?.trim(),
                'website': website?.trim(),
                'is_active': isActive,
                if (profileId != null) 'created_by': profileId,
              })
              .select()
              .single();
      final model = BrandModel.fromJson(response);
      return right(model.toEntity());
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> updateBrand({
    required String id,
    required String name,
    String? description,
    String? logoUrl,
    String? website,
    required bool isActive,
    String? profileId,
  }) async {
    try {
      await _supabase
          .from('brands')
          .update({
            'name': name.trim(),
            'description': description?.trim(),
            'logo_url': logoUrl?.trim(),
            'website': website?.trim(),
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
            if (profileId != null) 'updated_by': profileId,
          })
          .eq('id', id);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deleteBrand(String id) async {
    try {
      await _supabase.from('brands').delete().eq('id', id);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<BrandEntity>>> getBrands({
    bool activeOnly = false,
  }) async {
    try {
      var query = _supabase
          .from('brands')
          .select(
            'id, name, description, logo_url, website, is_active, created_at, updated_at, products:products(count)',
          );
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final response = await query.order('name');
      final models =
          List<Map<String, dynamic>>.from(
            response,
          ).map(BrandModel.fromJson).toList();
      return right(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      return _handleError(e, st);
    }
  }
}
