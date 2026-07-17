import 'package:injectable/injectable.dart';
import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_movement_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credit_movements_repository.dart';
import 'package:inventory_store_app/features/purchases/data/models/supplier_credit_movement_model.dart';
import 'package:inventory_store_app/features/purchases/data/utils/credit_movements_pdf_generator.dart';

@LazySingleton(as: SupplierCreditMovementsRepository)
class SupplierCreditMovementsRepositoryImpl implements SupplierCreditMovementsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  PostgrestFilterBuilder<T> _applyDateFilter<T>(
    PostgrestFilterBuilder<T> query,
    MovementDateFilter dateFilter,
  ) {
    final now = DateTime.now();
    switch (dateFilter) {
      case MovementDateFilter.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return query.gte('created_at', startOfMonth.toIso8601String());
      case MovementDateFilter.lastMonth:
        final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
        final endOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);
        return query
            .gte('created_at', startOfLastMonth.toIso8601String())
            .lte('created_at', endOfLastMonth.toIso8601String());
      case MovementDateFilter.allTime:
        return query;
    }
  }

  @override
  Future<
      Either<
          Failure,
          ({
            List<SupplierCreditMovementEntity> movements,
            int totalCount,
            double totalCharged,
            double totalPaid,
          })>> fetchMovementsPaginated({
    required String creditId,
    required int page,
    required int pageSize,
    required MovementDateFilter dateFilter,
  }) async {
    try {
      // Totals
      var totalsQuery = _supabase
          .from('supplier_credit_movements')
          .select('amount, movement_type, created_at')
          .eq('supplier_credit_id', creditId);

      totalsQuery = _applyDateFilter(totalsQuery, dateFilter);

      final totalsResponse = await totalsQuery;
      final listAll = totalsResponse as List;

      double charged = 0;
      double paid = 0;

      for (final item in listAll) {
        final amount = (item['amount'] as num).toDouble();
        if (item['movement_type'] == 'CHARGE') {
          charged += amount;
        } else {
          paid += amount;
        }
      }

      // Pagination
      var query = _supabase
          .from('supplier_credit_movements')
          .select('*, profiles(full_name), purchase_orders(total_amount)')
          .eq('supplier_credit_id', creditId);

      query = _applyDateFilter(query, dateFilter);

      final start = page * pageSize;
      final end = start + pageSize - 1;

      final response = await query
          .order('created_at', ascending: false)
          .range(start, end)
          .count(CountOption.exact);

      final count = response.count;
      final movementsList = (response.data as List)
          .map((e) => SupplierCreditMovementModel.fromJson(e))
          .toList();

      return Right((
        movements: movementsList,
        totalCount: count,
        totalCharged: charged,
        totalPaid: paid,
      ));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Uint8List>> generateMovementsPdf({
    required String supplierName,
    required List<SupplierCreditMovementEntity> allMovementsForPdf,
  }) async {
    try {
      final pdfBytes = await CreditMovementsPdfGenerator.generatePdf(
        supplierName: supplierName,
        allMovements: allMovementsForPdf,
      );
      return Right(pdfBytes);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}



