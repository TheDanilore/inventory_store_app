import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/financial/data/models/financial_account_model.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/financial_accounts_repository.dart';
import 'dart:developer' as developer;

@LazySingleton(as: FinancialAccountsRepository)
class FinancialAccountsRepositoryImpl implements FinancialAccountsRepository {
  final SupabaseClient _supabase;
  List<FinancialAccountEntity>? _cachedAccounts;
  DateTime? _accountsCacheTime;
  static const Duration _cacheTtl = Duration(minutes: 15);

  FinancialAccountsRepositoryImpl(this._supabase);

  @override
  void invalidateCache() {
    _cachedAccounts = null;
    _accountsCacheTime = null;
  }

  @override
  Future<List<FinancialAccountEntity>> getAccounts({
    required int page,
    required int pageSize,
    bool force = false,
  }) async {
    // SWR / L1 In-Memory Cache para la primera página
    if (page == 0 &&
        !force &&
        _cachedAccounts != null &&
        _accountsCacheTime != null) {
      if (DateTime.now().difference(_accountsCacheTime!) < _cacheTtl) {
        return _cachedAccounts!;
      }
    }

    final start = page * pageSize;
    final end = start + pageSize - 1;

    try {
      final response = await _supabase
          .from('financial_accounts')
          .select(
            'id, name, type, balance, is_active, created_at, currency_code, warehouse_id, warehouses(id, name)',
          )
          .order('is_active', ascending: false)
          .order('name')
          .range(start, end);

      final data = response as List;
      final accounts =
          data
              .map(
                (e) =>
                    FinancialAccountModel.fromJson(
                      Map<String, dynamic>.from(e as Map),
                    ).toEntity(),
              )
              .toList();

      if (page == 0) {
        _cachedAccounts = accounts;
        _accountsCacheTime = DateTime.now();
      }

      return accounts;
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
                'id, name, type, balance, is_active, created_at, currency_code, warehouse_id, warehouses(id, name)',
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
    String? warehouseId,
  }) async {
    try {
      if (accountId != null) {
        // Si se corrigió el saldo en edición, intentamos el RPC atómico con Ledger
        if (initialBalance != null) {
          try {
            await _supabase.rpc(
              'rpc_adjust_financial_account_balance',
              params: {
                'p_account_id': accountId,
                'p_new_balance': initialBalance,
                'p_reason': 'Ajuste manual desde formulario',
              },
            );
          } catch (rpcErr) {
            // Fallback de compatibilidad si el RPC aún no fue migrado en Supabase
            developer.log(
              'Aviso: rpc_adjust_financial_account_balance no disponible, actualizando directamente: $rpcErr',
              name: 'FinancialAccountsRepositoryImpl',
            );
            await _supabase
                .from('financial_accounts')
                .update({'balance': initialBalance})
                .eq('id', accountId);
          }
        }

        final updatePayload = <String, dynamic>{
          'name': name,
          'type': type,
          'is_active': isActive,
          'currency_code': currencyCode,
          'warehouse_id': warehouseId,
          'updated_at': DateTime.now().toIso8601String(),
        };

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
          'warehouse_id': warehouseId,
        });
      }

      invalidateCache();
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
