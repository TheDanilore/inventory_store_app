import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/financial/data/models/account_movement_model.dart';
import 'package:inventory_store_app/features/financial/domain/entities/account_movement_entity.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';

@LazySingleton(as: AccountMovementsRepository)
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
          'financial_accounts!inner(id, name, type), profiles(full_name)',
        );

    query = _applyFilters(query, filters);

    final response = await query
        .order('created_at', ascending: false)
        .range(start, end)
        .count(CountOption.exact);

    final data = response.data as List;
    return data
        .map(
          (e) =>
              AccountMovementModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ).toEntity(),
        )
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
  Future<void> registerManualMovement({
    required String profileId,
    required String accountId,
    required String movementType,
    required double amount,
    required String description,
  }) async {
    try {
      await _supabase.rpc('register_financial_movement', params: {
        'p_account_id': accountId,
        'p_movement_type': movementType,
        'p_amount': amount,
        'p_description': description,
        'p_reference_type': 'manual',
        'p_reference_id': null,
        'p_created_by': profileId,
      });
    } catch (e) {
      debugPrint(
        'AccountMovementsRepositoryImpl.registerManualMovement error: $e',
      );
      rethrow;
    }
  }

  @override
  Future<void> transferFunds({
    required String profileId,
    required String sourceAccountId,
    required String destAccountId,
    required double amount,
    required String description,
  }) async {
    try {
      final sourceAccRes =
          await _supabase
              .from('financial_accounts')
              .select('name')
              .eq('id', sourceAccountId)
              .single();
      final sourceName = sourceAccRes['name'] as String;

      final destAccRes =
          await _supabase
              .from('financial_accounts')
              .select('name')
              .eq('id', destAccountId)
              .single();
      final destName = destAccRes['name'] as String;

      await _supabase.rpc('register_financial_movement', params: {
        'p_account_id': sourceAccountId,
        'p_movement_type': 'EXPENSE',
        'p_amount': amount,
        'p_description':
            'Transferencia enviada a $destName${description.isNotEmpty ? ' — $description' : ''}',
        'p_reference_type': 'manual_transfer',
        'p_reference_id': null,
        'p_created_by': profileId,
      });

      await _supabase.rpc('register_financial_movement', params: {
        'p_account_id': destAccountId,
        'p_movement_type': 'INCOME',
        'p_amount': amount,
        'p_description':
            'Transferencia recibida de $sourceName${description.isNotEmpty ? ' — $description' : ''}',
        'p_reference_type': 'manual_transfer',
        'p_reference_id': null,
        'p_created_by': profileId,
      });
    } catch (e) {
      debugPrint('AccountMovementsRepositoryImpl.transferFunds error: $e');
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
      final term = filters.searchText.trim();
      final isUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(term);
      if (isUuid) {
        query = query.or('description.ilike.%$term%,reference_id.eq.$term');
      } else {
        query = query.ilike('description', '%$term%');
      }
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
