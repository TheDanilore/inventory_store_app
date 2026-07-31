import 'dart:developer' as developer;
import 'package:inventory_store_app/core/utils/isolate_utils.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cash_shift_repository.dart';
import 'package:inventory_store_app/features/pos/data/models/cash_shift_model.dart';

@LazySingleton(as: CashShiftRepository)
class CashShiftRepositoryImpl implements CashShiftRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> _getProfileId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final profile =
        await _supabase
            .from('profiles')
            .select('id')
            .eq('auth_user_id', user.id)
            .maybeSingle();

    return profile?['id'] as String?;
  }

  @override
  Future<Either<Failure, ({List<CashShiftEntity> shifts, int totalCount})>>
  getShifts({
    required int limit,
    required int offset,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? profileId,
  }) async {
    try {
      var query = _supabase.from('cash_shifts').select('''
        id, status, opening_amount, expected_amount, actual_amount,
        difference_amount, notes, opened_at, closed_at, account_id,
        financial_accounts!inner(id, name, type),
        opened_by_profile:profiles!cash_shifts_opened_by_fkey(full_name),
        closed_by_profile:profiles!cash_shifts_closed_by_fkey(full_name)
      ''');

      if (status != null && status != 'Todos') {
        query = query.eq('status', status);
      }
      if (dateFrom != null) {
        query = query.gte('opened_at', dateFrom.toIso8601String());
      }
      if (dateTo != null) {
        query = query.lte('opened_at', dateTo.toIso8601String());
      }
      if (profileId != null) {
        query = query.eq('opened_by', profileId);
      }

      final response = await query
          .order('status', ascending: false) // OPEN first
          .order('opened_at', ascending: false)
          .range(offset, offset + limit - 1)
          .count(CountOption.exact);

      final data = response.data as List;

      // Isolate para evitar jank en el parseo JSON
      final shifts = await IsolateUtils.run(() {
        return data
            .map(
              (e) =>
                  CashShiftModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ).toEntity(),
            )
            .toList();
      });

      return right((shifts: shifts, totalCount: response.count));
    } on PostgrestException catch (e, stack) {
      developer.log(
        'PostgrestException en getShifts',
        error: e,
        stackTrace: stack,
      );
      return left(ServerFailure(message: e.message));
    } catch (e, stack) {
      developer.log('Error general en getShifts', error: e, stackTrace: stack);
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, ({int openCount, int closedCount})>>
  getShiftsStatusCount({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? profileId,
  }) async {
    try {
      var openQuery = _supabase
          .from('cash_shifts')
          .select('id')
          .eq('status', 'OPEN');
      var closedQuery = _supabase
          .from('cash_shifts')
          .select('id')
          .eq('status', 'CLOSED');

      if (profileId != null) {
        openQuery = openQuery.eq('opened_by', profileId);
        closedQuery = closedQuery.eq('opened_by', profileId);
      }

      final openRes = await openQuery.count(CountOption.exact);
      final closedRes = await closedQuery.count(CountOption.exact);

      return right((openCount: openRes.count, closedCount: closedRes.count));
    } catch (e) {
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, CashShiftEntity>> openShift({
    required String accountId,
    required double openingBalance,
    String? notes,
  }) async {
    try {
      final profileId = await _getProfileId();
      if (profileId == null) {
        return left(
          const ServerFailure(
            message: 'No se pudo obtener el perfil de usuario.',
          ),
        );
      }

      final existing =
          await _supabase
              .from('cash_shifts')
              .select('id')
              .eq('account_id', accountId)
              .eq('status', 'OPEN')
              .maybeSingle();

      if (existing != null) {
        return left(
          const ValidationFailure(
            message: 'Esta caja ya tiene un turno abierto.',
          ),
        );
      }

      final inserted =
          await _supabase
              .from('cash_shifts')
              .insert({
                'account_id': accountId,
                'opening_amount': openingBalance,
                'notes': notes,
                'opened_by': profileId,
              })
              .select('''
        id, status, opening_amount, expected_amount, actual_amount,
        difference_amount, notes, opened_at, closed_at, account_id,
        financial_accounts(id, name, type),
        opened_by_profile:profiles!cash_shifts_opened_by_fkey(full_name),
        closed_by_profile:profiles!cash_shifts_closed_by_fkey(full_name)
      ''')
              .single();

      final shift =
          CashShiftModel.fromJson(
            Map<String, dynamic>.from(inserted),
          ).toEntity();
      return right(shift);
    } catch (e) {
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> closeShift({
    required String shiftId,
    required double closingBalance,
    String? notes,
  }) async {
    try {
      final profileId = await _getProfileId();
      if (profileId == null) {
        return left(
          const ServerFailure(
            message: 'No se pudo obtener el perfil de usuario.',
          ),
        );
      }

      final shiftRes =
          await _supabase
              .from('cash_shifts')
              .select('account_id, opening_amount')
              .eq('id', shiftId)
              .single();

      final accountId = shiftRes['account_id'];
      final openingAmount = (shiftRes['opening_amount'] as num).toDouble();

      final movRes = await _supabase
          .from('account_movements')
          .select('movement_type, amount')
          .eq('account_id', accountId)
          .eq('shift_id', shiftId);

      double income = 0;
      double expense = 0;
      for (final m in (movRes as List)) {
        final amt = (m['amount'] as num).toDouble();
        if (m['movement_type'] == 'INCOME') income += amt;
        if (m['movement_type'] == 'EXPENSE') expense += amt;
      }

      final expectedAmount = openingAmount + income - expense;
      final differenceAmount = closingBalance - expectedAmount;

      await _supabase
          .from('cash_shifts')
          .update({
            'status': 'CLOSED',
            'closed_at': DateTime.now().toIso8601String(),
            'closed_by': profileId,
            'actual_amount': closingBalance,
            'expected_amount': expectedAmount,
            'difference_amount': differenceAmount,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
          })
          .eq('id', shiftId);

      return right(unit);
    } catch (e) {
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, double>> calcExpected({
    required String shiftId,
    required String accountId,
    required double openingAmount,
  }) async {
    try {
      final movRes = await _supabase
          .from('account_movements')
          .select('movement_type, amount')
          .eq('account_id', accountId)
          .eq('shift_id', shiftId);

      double income = 0;
      double expense = 0;
      for (final m in (movRes as List)) {
        final amt = (m['amount'] as num).toDouble();
        if (m['movement_type'] == 'INCOME') income += amt;
        if (m['movement_type'] == 'EXPENSE') expense += amt;
      }
      return right(income - expense);
    } on PostgrestException catch (e, stack) {
      developer.log(
        'PostgrestException en calcExpected',
        error: e,
        stackTrace: stack,
      );
      return left(ServerFailure(message: e.message));
    } catch (e, stack) {
      developer.log(
        'Error general en calcExpected',
        error: e,
        stackTrace: stack,
      );
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, CashShiftEntity?>> checkActiveShift(
    String accountId,
  ) async {
    try {
      final shiftData =
          await _supabase
              .from('cash_shifts')
              .select(
                'id, status, account_id',
              ) // Solo los campos mínimos necesarios
              .eq('account_id', accountId)
              .eq('status', 'OPEN')
              .maybeSingle();

      if (shiftData == null) return right(null);

      // Usamos los campos mínimos
      final shift = CashShiftEntity(
        id: shiftData['id'],
        status: CashShiftStatus.fromString(shiftData['status']),
        openingAmount: 0.0, // No requerido para el checkout
        openedAt: DateTime.now(), // Fake date for checkout
        accountId: shiftData['account_id'],
      );

      return right(shift);
    } on PostgrestException catch (e, stack) {
      // Capturamos el error específico de Supabase para trazabilidad
      developer.log(
        'PostgrestException en checkActiveShift',
        error: e,
        stackTrace: stack,
      );
      return left(ServerFailure(message: e.message));
    } catch (e, stack) {
      developer.log(
        'Error general en checkActiveShift',
        error: e,
        stackTrace: stack,
      );
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getStaffProfiles() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, full_name')
          .neq('role', 'customer')
          .order('full_name');

      return right(List<Map<String, dynamic>>.from(res));
    } on PostgrestException catch (e, stack) {
      developer.log(
        'PostgrestException en getStaffProfiles',
        error: e,
        stackTrace: stack,
      );
      return left(ServerFailure(message: e.message));
    } catch (e, stack) {
      developer.log(
        'Error general en getStaffProfiles',
        error: e,
        stackTrace: stack,
      );
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getAvailableAccounts(
    Set<String> openAccountIds,
  ) async {
    try {
      final res = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .eq('type', 'CAJA')
          .order('name');

      final accounts =
          (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
      final availableAccounts =
          accounts.where((a) => !openAccountIds.contains(a['id'])).toList();

      return right(availableAccounts);
    } on PostgrestException catch (e, stack) {
      developer.log(
        'PostgrestException en getAvailableAccounts',
        error: e,
        stackTrace: stack,
      );
      return left(ServerFailure(message: e.message));
    } catch (e, stack) {
      developer.log(
        'Error general en getAvailableAccounts',
        error: e,
        stackTrace: stack,
      );
      return left(Failure.from(e));
    }
  }
}
