import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/financial/data/models/account_movement_model.dart';
import 'package:inventory_store_app/features/financial/domain/entities/account_movement_entity.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';

class AccountMovementsRepositoryImpl implements AccountMovementsRepository {
  final SupabaseClient _supabase;

  AccountMovementsRepositoryImpl(this._supabase);

  @override
  Future<List<AccountMovementEntity>> getMovements({
    required MovementFilters filters,
    required int page,
    required int pageSize,
  }) async {
    final start = page * pageSize;
    final end = start + pageSize - 1;

    var query = _supabase
        .from('account_movements')
        .select(
          'id, movement_type, amount, description, reference_type, reference_id, created_at, '
          'financial_accounts!inner(id, name, type), profiles!inner(full_name)',
        );

    query = _applyFilters(query, filters);

    final response = await query
        .order('created_at', ascending: false)
        .range(start, end)
        .count(CountOption.exact);

    final data = response.data as List;
    return data
        .map((e) => AccountMovementModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ).toEntity())
        .toList();
  }

  @override
  Future<int> getMovementsCount({required MovementFilters filters}) async {
    var query = _supabase
        .from('account_movements')
        .select('id')
        .count(CountOption.exact);

    query = _applyFilters(query, filters);
    final response = await query;
    return response.count;
  }

  @override
  Future<MovementTotals> getMovementTotals({
    required MovementFilters filters,
  }) async {
    try {
      var query = _supabase
          .from('account_movements')
          .select('movement_type, amount');

      query = _applyFilters(query, filters);
      final res = await query as List;

      double totalIncome = 0;
      double totalExpense = 0;
      for (final item in res) {
        final amt = (item['amount'] as num).toDouble();
        if (item['movement_type'] == 'INCOME') totalIncome += amt;
        if (item['movement_type'] == 'EXPENSE') totalExpense += amt;
      }

      return MovementTotals(
        totalIncome: totalIncome,
        totalExpense: totalExpense,
      );
    } catch (e) {
      debugPrint('AccountMovementsRepositoryImpl.getMovementTotals error: $e');
      return const MovementTotals(totalIncome: 0, totalExpense: 0);
    }
  }

  @override
  Future<void> saveMovement({
    required String accountId,
    required String movementType,
    required double amount,
    required String description,
    String? referenceType,
    String? referenceId,
  }) async {
    try {
      await _supabase.from('account_movements').insert({
        'account_id': accountId,
        'movement_type': movementType,
        'amount': amount,
        'description': description,
        if (referenceType != null) 'reference_type': referenceType,
        if (referenceId != null) 'reference_id': referenceId,
      });
    } catch (e) {
      debugPrint('AccountMovementsRepositoryImpl.saveMovement error: $e');
      rethrow;
    }
  }

  /// Aplica los filtros activos a la query de Supabase de forma encadenada.
  dynamic _applyFilters(dynamic query, MovementFilters filters) {
    if (filters.filterType != 'Todos') {
      query = query.eq('movement_type', filters.filterType);
    }
    if (filters.filterAccountId != 'Todas') {
      query = query.eq('account_id', filters.filterAccountId);
    }
    if (filters.searchText.isNotEmpty) {
      query = query.ilike('description', '%${filters.searchText}%');
    }
    if (filters.dateFrom != null) {
      query = query.gte('created_at', filters.dateFrom!.toIso8601String());
    }
    if (filters.dateTo != null) {
      query = query.lte('created_at', filters.dateTo!.toIso8601String());
    }
    return query;
  }
}
