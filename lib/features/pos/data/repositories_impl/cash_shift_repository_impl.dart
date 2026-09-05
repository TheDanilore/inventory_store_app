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

  CashShiftRepositoryImpl();

  // Caché en memoria del profileId — el Singleton vive toda la sesión.
  // Se invalida en logout mediante clearCachedProfile().
  String? _cachedProfileId;

  Future<String?> _getProfileId() async {
    if (_cachedProfileId != null) return _cachedProfileId;
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final profile =
        await _supabase
            .from('profiles')
            .select('id')
            .eq('auth_user_id', user.id)
            .maybeSingle();

    _cachedProfileId = profile?['id'] as String?;
    return _cachedProfileId;
  }

  /// Llamar al cerrar sesión para invalidar el caché del perfil.
  void clearCachedProfile() => _cachedProfileId = null;

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
    } on PostgrestException catch (e, stack) {
      developer.log(
        'PostgrestException en getShiftsStatusCount',
        error: e,
        stackTrace: stack,
      );
      return left(ServerFailure(message: e.message));
    } catch (e, stack) {
      developer.log(
        'Error general en getShiftsStatusCount',
        error: e,
        stackTrace: stack,
      );
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

      final shiftId = await _supabase.rpc(
        'rpc_open_cash_shift',
        params: {
          'p_account_id': accountId,
          'p_opening_amount': openingBalance,
          'p_opened_by': profileId,
          'p_notes': notes,
        },
      );

      final inserted =
          await _supabase
              .from('cash_shifts')
              .select('''
        id, status, opening_amount, expected_amount, actual_amount,
        difference_amount, notes, opened_at, closed_at, account_id,
        financial_accounts(id, name, type),
        opened_by_profile:profiles!cash_shifts_opened_by_fkey(full_name),
        closed_by_profile:profiles!cash_shifts_closed_by_fkey(full_name)
      ''')
              .eq('id', shiftId)
              .single();

      final shift =
          CashShiftModel.fromJson(
            Map<String, dynamic>.from(inserted),
          ).toEntity();
      return right(shift);
    } on PostgrestException catch (e, st) {
      developer.log(
        'PostgrestException en openShift',
        error: e,
        stackTrace: st,
      );
      // Mapeo robusto por code SQLSTATE (definido en el RPC de BD).
      // Fallback a análisis de mensaje para retrocompatibilidad.
      final msg = _mapShiftError(e);
      return left(ServerFailure(message: msg));
    } catch (e, st) {
      developer.log('Error inesperado en openShift', error: e, stackTrace: st);
      return left(
        const ServerFailure(message: 'Error inesperado al abrir el turno.'),
      );
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

      await _supabase.rpc(
        'rpc_close_cash_shift',
        params: {
          'p_shift_id': shiftId,
          'p_actual_amount': closingBalance,
          'p_closed_by': profileId,
          'p_notes': notes,
        },
      );

      return right(unit);
    } on PostgrestException catch (e, st) {
      developer.log(
        'PostgrestException en closeShift',
        error: e,
        stackTrace: st,
      );
      final msg = _mapShiftError(e);
      return left(ServerFailure(message: msg));
    } catch (e, st) {
      developer.log('Error inesperado en closeShift', error: e, stackTrace: st);
      return left(
        const ServerFailure(message: 'Error inesperado al cerrar el turno.'),
      );
    }
  }

  @override
  Future<Either<Failure, double>> calcExpected({
    required String shiftId,
    required String accountId,
    required double openingAmount,
  }) async {
    try {
      // [OPTIMIZACIÓN DATA EGRESS] La suma se delega al RPC en BD con SUM()
      // en lugar de descargar N filas al cliente para sumarlas en Flutter.
      final result = await _supabase.rpc(
        'calc_expected_shift_rpc',
        params: {'p_shift_id': shiftId, 'p_account_id': accountId},
      );

      final netMovements = (result as num?)?.toDouble() ?? 0.0;
      final expected = openingAmount + netMovements;
      return right(expected);
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
              .select('''
                id, status, opening_amount, expected_amount, actual_amount,
                difference_amount, notes, opened_at, closed_at, account_id,
                financial_accounts(id, name, type),
                opened_by_profile:profiles!cash_shifts_opened_by_fkey(full_name),
                closed_by_profile:profiles!cash_shifts_closed_by_fkey(full_name)
              ''')
              .eq('account_id', accountId)
              .eq('status', 'OPEN')
              .maybeSingle();

      if (shiftData == null) return right(null);

      final shift =
          CashShiftModel.fromJson(
            Map<String, dynamic>.from(shiftData),
          ).toEntity();

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

  // ── HELPER PRIVADO ───────────────────────────────────────────────────────────

  /// Mapea errores de PostgrestException a mensajes de usuario legibles.
  /// Prioriza el code SQLSTATE (si el RPC lo define), hace fallback al mensaje.
  String _mapShiftError(PostgrestException e) {
    // Mapeo por código SQLSTATE personalizado (definido con USING ERRCODE en PL/pgSQL)
    switch (e.code) {
      case 'P0001':
        return 'Esta caja ya tiene un turno abierto.';
      case 'P0002':
        return 'Este turno de caja ya se encuentra cerrado.';
      case 'P0003':
        return 'El turno de caja especificado no existe.';
      case 'P0004':
        return 'Saldo insuficiente para abrir la caja.';
    }
    // Fallback: análisis del mensaje para retrocompatibilidad con RPCs
    // que aún no usan SQLSTATE codes.
    final msg = e.message.toLowerCase();
    if (msg.contains('ya tiene un turno abierto')) {
      return 'Esta caja ya tiene un turno abierto.';
    }
    if (msg.contains('ya se encuentra cerrado')) {
      return 'Este turno de caja ya se encuentra cerrado.';
    }
    if (msg.contains('no existe')) {
      return 'El turno de caja especificado no existe.';
    }
    if (msg.contains('saldo insuficiente')) return e.message;
    return 'Error de base de datos al operar el turno: ${e.message}';
  }
}
