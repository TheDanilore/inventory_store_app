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
          'financial_accounts!inner(id, name, type), profiles!inner(full_name)',
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

  Future<String?> _getActiveShift(String accountId) async {
    final res =
        await _supabase
            .from('cash_shifts')
            .select('id')
            .eq('account_id', accountId)
            .eq('status', 'OPEN')
            .maybeSingle();
    return res?['id'] as String?;
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
      final sourceAccRes =
          await _supabase
              .from('financial_accounts')
              .select('balance')
              .eq('id', accountId)
              .single();
      final currentBalance = (sourceAccRes['balance'] as num).toDouble();
      final shiftId = await _getActiveShift(accountId);

      final isIncome = movementType == 'INCOME';
      final newBalance =
          isIncome ? (currentBalance + amount) : (currentBalance - amount);

      await _supabase
          .from('financial_accounts')
          .update({'balance': newBalance})
          .eq('id', accountId);

      await _supabase.from('account_movements').insert({
        'account_id': accountId,
        'movement_type': movementType,
        'amount': amount,
        'description': description,
        'created_by': profileId,
        'shift_id': shiftId,
        'reference_type': 'manual',
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
              .select('balance, name')
              .eq('id', sourceAccountId)
              .single();
      final currentSourceBalance = (sourceAccRes['balance'] as num).toDouble();
      final sourceName = sourceAccRes['name'] as String;
      final sourceShiftId = await _getActiveShift(sourceAccountId);

      final destAccRes =
          await _supabase
              .from('financial_accounts')
              .select('balance, name')
              .eq('id', destAccountId)
              .single();
      final currentDestBalance = (destAccRes['balance'] as num).toDouble();
      final destName = destAccRes['name'] as String;
      final destShiftId = await _getActiveShift(destAccountId);

      await _supabase
          .from('financial_accounts')
          .update({'balance': currentSourceBalance - amount})
          .eq('id', sourceAccountId);
      await _supabase
          .from('financial_accounts')
          .update({'balance': currentDestBalance + amount})
          .eq('id', destAccountId);

      await _supabase.from('account_movements').insert([
        {
          'account_id': sourceAccountId,
          'movement_type': 'EXPENSE',
          'amount': amount,
          'description':
              'Transferencia enviada a $destName${description.isNotEmpty ? ' — $description' : ''}',
          'created_by': profileId,
          'shift_id': sourceShiftId,
          'reference_type': 'manual_transfer',
        },
        {
          'account_id': destAccountId,
          'movement_type': 'INCOME',
          'amount': amount,
          'description':
              'Transferencia recibida de $sourceName${description.isNotEmpty ? ' — $description' : ''}',
          'created_by': profileId,
          'shift_id': destShiftId,
          'reference_type': 'manual_transfer',
        },
      ]);
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
