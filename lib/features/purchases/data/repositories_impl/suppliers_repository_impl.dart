import 'dart:developer' as developer;
import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/suppliers_repository.dart';
import 'package:inventory_store_app/features/purchases/data/models/supplier_model.dart';

@LazySingleton(as: SuppliersRepository)
class SuppliersRepositoryImpl implements SuppliersRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<Either<Failure, ({List<SupplierEntity> suppliers, int totalCount})>>
  fetchSuppliers({
    required int page,
    required int pageSize,
    String searchQuery = '',
  }) async {
    try {
      var query = _supabase.from('suppliers').select('id, name, tax_id, contact_name, phone, email, address, is_active');

      final term = searchQuery.trim();
      if (term.isNotEmpty) {
        query = query.or(
          'name.ilike.%$term%,tax_id.ilike.%$term%,contact_name.ilike.%$term%',
        );
      }

      final start = page * pageSize;
      final end = start + pageSize - 1;

      final response = await query
          .order('name', ascending: true)
          .range(start, end)
          .count(CountOption.exact);

      final totalCount = response.count;
      final list =
          (response.data as List)
              .map((e) => SupplierModel.fromJson(e))
              .toList();

      return Right((suppliers: list, totalCount: totalCount));
    } on PostgrestException catch (e, st) {
      developer.log('[SuppliersRepositoryImpl] fetchSuppliers PostgrestException: ${e.message}', name: 'SuppliersRepository', error: e, stackTrace: st);
      return Left(ServerFailure(message: 'Error de base de datos: ${e.message}'));
    } catch (e, st) {
      developer.log('[SuppliersRepositoryImpl] fetchSuppliers Error: $e', name: 'SuppliersRepository', error: e, stackTrace: st);
      return Left(ServerFailure(message: 'Error inesperado: $e'));
    }
  }
  @override
  Future<Either<Failure, List<SupplierEntity>>> getActiveSuppliers() async {
    try {
      final response = await _supabase
          .from('suppliers')
          .select('id, name, tax_id, contact_name, phone, email, address, is_active')
          .eq('is_active', true)
          .order('name');
      
      final list = (response as List)
          .map((e) => SupplierModel.fromJson(e))
          .toList();
          
      return Right(list);
    } on PostgrestException catch (e, st) {
      developer.log('[SuppliersRepositoryImpl] getActiveSuppliers PostgrestException: ${e.message}', name: 'SuppliersRepository', error: e, stackTrace: st);
      return Left(ServerFailure(message: 'Error de base de datos: ${e.message}'));
    } catch (e, st) {
      developer.log('[SuppliersRepositoryImpl] getActiveSuppliers Error: $e', name: 'SuppliersRepository', error: e, stackTrace: st);
      return Left(ServerFailure(message: 'Error inesperado: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> toggleSupplierStatus(
    String supplierId,
    bool currentStatus,
  ) async {
    try {
      await _supabase
          .from('suppliers')
          .update({'is_active': !currentStatus})
          .eq('id', supplierId);
      return const Right(null);
    } on PostgrestException catch (e, st) {
      developer.log('[SuppliersRepositoryImpl] toggleSupplierStatus PostgrestException: ${e.message}', name: 'SuppliersRepository', error: e, stackTrace: st);
      return Left(ServerFailure(message: 'Error de base de datos: ${e.message}'));
    } catch (e, st) {
      developer.log('[SuppliersRepositoryImpl] toggleSupplierStatus Error: $e', name: 'SuppliersRepository', error: e, stackTrace: st);
      return Left(ServerFailure(message: 'Error inesperado: $e'));
    }
  }

  @override
  Future<Either<Failure, SupplierEntity>> createSupplier(SupplierEntity supplier) async {
    try {
      final model = SupplierModel(
        id: '',
        name: supplier.name,
        taxId: supplier.taxId,
        contactName: supplier.contactName,
        phone: supplier.phone,
        email: supplier.email,
        address: supplier.address,
        isActive: supplier.isActive,
      );

      final response = await _supabase
          .from('suppliers')
          .insert(model.toJson())
          .select('id, name, tax_id, contact_name, phone, email, address, is_active')
          .single();

      return Right(SupplierModel.fromJson(response));
    } on PostgrestException catch (e, st) {
      developer.log('[SuppliersRepositoryImpl] createSupplier PostgrestException: ${e.message}', name: 'SuppliersRepository', error: e, stackTrace: st);
      if (e.code == '23505') {
        return const Left(ValidationFailure(message: 'Ya existe un proveedor con ese número de RUC/ID fiscal.'));
      }
      return Left(ServerFailure(message: 'Error de base de datos: ${e.message}'));
    } catch (e, st) {
      developer.log('[SuppliersRepositoryImpl] createSupplier Error: $e', name: 'SuppliersRepository', error: e, stackTrace: st);
      return Left(ServerFailure(message: 'Error inesperado: $e'));
    }
  }

  @override
  Future<Either<Failure, SupplierEntity>> updateSupplier(SupplierEntity supplier) async {
    try {
      final model = SupplierModel(
        id: supplier.id,
        name: supplier.name,
        taxId: supplier.taxId,
        contactName: supplier.contactName,
        phone: supplier.phone,
        email: supplier.email,
        address: supplier.address,
        isActive: supplier.isActive,
      );

      final response = await _supabase
          .from('suppliers')
          .update(model.toJson())
          .eq('id', supplier.id)
          .select('id, name, tax_id, contact_name, phone, email, address, is_active')
          .single();

      return Right(SupplierModel.fromJson(response));
    } on PostgrestException catch (e, st) {
      developer.log('[SuppliersRepositoryImpl] updateSupplier PostgrestException: ${e.message}', name: 'SuppliersRepository', error: e, stackTrace: st);
      if (e.code == '23505') {
        return const Left(ValidationFailure(message: 'Ya existe un proveedor con ese número de RUC/ID fiscal.'));
      }
      return Left(ServerFailure(message: 'Error de base de datos: ${e.message}'));
    } catch (e, st) {
      developer.log('[SuppliersRepositoryImpl] updateSupplier Error: $e', name: 'SuppliersRepository', error: e, stackTrace: st);
      return Left(ServerFailure(message: 'Error inesperado: $e'));
    }
  }
}
