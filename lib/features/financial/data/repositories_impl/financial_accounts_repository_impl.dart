import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/financial/data/models/financial_account_model.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/financial_accounts_repository.dart';

@LazySingleton(as: FinancialAccountsRepository)
class FinancialAccountsRepositoryImpl implements FinancialAccountsRepository {
  final SupabaseClient _supabase;

  FinancialAccountsRepositoryImpl(this._supabase);

  @override
  Future<List<FinancialAccountEntity>> getAccounts({
    required int page,
    required int pageSize,
  }) async {
    final start = page * pageSize;
    final end = start + pageSize - 1;

    final response = await _supabase
        .from('financial_accounts')
        .select('id, name, type, balance, is_active, created_at')
        .order('is_active', ascending: false)
        .order('name')
        .range(start, end)
        .count(CountOption.exact);

    final data = response.data as List;
    return data
        .map(
          (e) =>
              FinancialAccountModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ).toEntity(),
        )
        .toList();
  }

  @override
  Future<FinancialAccountEntity?> getAccountById(String accountId) async {
    final response =
        await _supabase
            .from('financial_accounts')
            .select('id, name, type, balance, is_active, created_at')
            .eq('id', accountId)
            .maybeSingle();
    if (response == null) return null;
    return FinancialAccountModel.fromJson(response).toEntity();
  }

  @override
  Future<int> getAccountsCount() async {
    final response = await _supabase
        .from('financial_accounts')
        .select('id')
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Future<void> saveAccount({
    String? accountId,
    required String name,
    required String type,
    required bool isActive,
    double? initialBalance,
  }) async {
    try {
      if (accountId != null) {
        await _supabase
            .from('financial_accounts')
            .update({'name': name, 'type': type, 'is_active': isActive})
            .eq('id', accountId);
      } else {
        await _supabase.from('financial_accounts').insert({
          'name': name,
          'type': type,
          'balance': initialBalance ?? 0.0,
          'is_active': isActive,
        });
      }
    } catch (e) {
      debugPrint('FinancialAccountsRepositoryImpl.saveAccount error: $e');
      rethrow;
    }
  }
}
