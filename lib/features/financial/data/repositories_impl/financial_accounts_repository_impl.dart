import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/financial/data/models/financial_account_model.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/financial_accounts_repository.dart';
import 'dart:developer' as developer;

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

    try {
      final response = await _supabase
          .from('financial_accounts')
          .select(
            'id, name, type, balance, is_active, created_at, currency_code',
          )
          .order('is_active', ascending: false)
          .order('name')
          .range(start, end);

      final data = response as List;
      return data
          .map(
            (e) =>
                FinancialAccountModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ).toEntity(),
          )
          .toList();
    } catch (e, st) {
      developer.log(
        'getAccounts error',
        error: e,
        stackTrace: st,
        name: 'FinancialAccountsRepositoryImpl',
      );
      rethrow;
    }
  }

  @override
  Future<FinancialAccountEntity?> getAccountById(String accountId) async {
    try {
      final response =
          await _supabase
              .from('financial_accounts')
              .select(
                'id, name, type, balance, is_active, created_at, currency_code',
              )
              .eq('id', accountId)
              .maybeSingle();
      if (response == null) return null;
      return FinancialAccountModel.fromJson(response).toEntity();
    } catch (e, st) {
      developer.log(
        'getAccountById error',
        error: e,
        stackTrace: st,
        name: 'FinancialAccountsRepositoryImpl',
      );
      rethrow;
    }
  }

  @override
  Future<int> getAccountsCount() async {
    try {
      final response = await _supabase
          .from('financial_accounts')
          .select('id')
          .count(CountOption.exact);
      return response.count;
    } catch (e, st) {
      developer.log(
        'getAccountsCount error',
        error: e,
        stackTrace: st,
        name: 'FinancialAccountsRepositoryImpl',
      );
      return 0;
    }
  }

  @override
  Future<void> saveAccount({
    String? accountId,
    required String name,
    required String type,
    required bool isActive,
    double? initialBalance,
    String currencyCode = 'PEN',
  }) async {
    try {
      if (accountId != null) {
        final updatePayload = <String, dynamic>{
          'name': name,
          'type': type,
          'is_active': isActive,
          'currency_code': currencyCode,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (initialBalance != null) {
          updatePayload['balance'] = initialBalance;
        }
        await _supabase
            .from('financial_accounts')
            .update(updatePayload)
            .eq('id', accountId);
      } else {
        await _supabase.from('financial_accounts').insert({
          'name': name,
          'type': type,
          'balance': initialBalance ?? 0.0,
          'is_active': isActive,
          'currency_code': currencyCode,
        });
      }
    } catch (e, st) {
      developer.log(
        'saveAccount error',
        error: e,
        stackTrace: st,
        name: 'FinancialAccountsRepositoryImpl',
      );
      rethrow;
    }
  }
}
