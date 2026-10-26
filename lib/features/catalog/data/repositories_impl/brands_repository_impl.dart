import 'package:inventory_store_app/core/services/logger_service.dart';
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

  // ─── CACHÉ L1 EN MEMORIA (TTL: 15 MINUTOS) ──────────────────────────────
  List<BrandEntity>? _brandsCache;
  DateTime? _cacheTimestamp;
  static const Duration _cacheTtl = Duration(minutes: 15);

  void _invalidateCache() {
    _brandsCache = null;
    _cacheTimestamp = null;
  }

  @override
  List<BrandEntity>? getCachedBrands({bool activeOnly = false}) {
    if (_brandsCache != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < _cacheTtl) {
        if (activeOnly) {
          return _brandsCache!.where((b) => b.isActive).toList();
        }
        return _brandsCache;
      }
    }
    return null;
  }

  BrandsRepositoryImpl(this._supabase);

  Either<Failure, T> _handleError<T>(Object e, [StackTrace? st]) {
    LoggerService.e(
      'Error en BrandsRepositoryImpl',
      tag: 'BRANDS_REPO',
      error: e,
      stackTrace: st,
    );
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
          Failure.from('Ya existe una marca registrada con ese nombre.'),
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
      _invalidateCache();
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
      _invalidateCache();
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deleteBrand(String id) async {
    try {
      await _supabase.from('brands').delete().eq('id', id);
      _invalidateCache();
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<BrandEntity>>> getBrands({
    bool activeOnly = false,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = getCachedBrands(activeOnly: activeOnly);
      if (cached != null) {
        return right(cached);
      }
    }

    try {
      var query = _supabase
          .from('brands')
          .select(
            'id, name, description, logo_url, website, is_active, created_at, updated_at, products:products(count)',
          );
      final response = await query.order('name');
      final models =
          List<Map<String, dynamic>>.from(
            response,
          ).map(BrandModel.fromJson).toList();
      final allBrands = models.map((m) => m.toEntity()).toList();

      _brandsCache = allBrands;
      _cacheTimestamp = DateTime.now();

      if (activeOnly) {
        return right(allBrands.where((b) => b.isActive).toList());
      }
      return right(allBrands);
    } catch (e, st) {
      if (_brandsCache != null) {
        if (activeOnly) {
          return right(_brandsCache!.where((b) => b.isActive).toList());
        }
        return right(_brandsCache!);
      }
      return _handleError(e, st);
    }
  }
}
