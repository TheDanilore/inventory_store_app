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
      var query = _supabase.from('suppliers').select('*');

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
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
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
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
