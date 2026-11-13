import 'dart:developer' as developer;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/loyalty/domain/repositories/loyalty_repository.dart';
import 'package:inventory_store_app/features/loyalty/domain/entities/loyalty_profile_entity.dart';
import 'package:inventory_store_app/features/loyalty/domain/entities/daily_checkin_entity.dart';
import 'package:inventory_store_app/features/loyalty/domain/entities/wallet_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/loyalty/data/models/loyalty_profile_model.dart';
import 'package:inventory_store_app/features/loyalty/data/models/daily_checkin_model.dart';
import 'package:inventory_store_app/features/loyalty/data/models/wallet_movement_model.dart';

@LazySingleton(as: LoyaltyRepository)
class LoyaltyRepositoryImpl implements LoyaltyRepository {
  final SupabaseClient _supabase;

  LoyaltyRepositoryImpl(this._supabase);

  Either<Failure, T> _handleError<T>(Object e, StackTrace st) {
    developer.log(
      'Error crítico en LoyaltyRepository',
      error: e.toString(),
      stackTrace: st,
    );

    if (e is PostgrestException) {
      if (e.code == 'P0002' || e.code == 'P0001') {
        return left(Failure.from(e.message));
      }
      return left(Failure.from('Error de base de datos: ${e.message}'));
    }
    return left(Failure.from('Error inesperado: $e'));
  }

  @override
  Future<Either<Failure, LoyaltyProfileEntity>> getProfileSummary(
    String authUserId,
  ) async {
    try {
      final response =
          await _supabase
              .from('profiles')
              .select('id, wallet_balance')
              .eq('auth_user_id', authUserId)
              .maybeSingle();

      if (response == null) {
        return left(Failure.from('No se encontró el perfil'));
      }
      return right(LoyaltyProfileModel.fromJson(response).toEntity());
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, int>> getWalletBalance(String authUserId) async {
    try {
      final response =
          await _supabase
              .from('profiles')
              .select('wallet_balance')
              .eq('auth_user_id', authUserId)
              .maybeSingle();

      if (response == null) {
        return left(Failure.from('No se encontró el saldo'));
      }
      final balance = (response['wallet_balance'] as num?)?.toInt() ?? 0;
      return right(balance);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getLoyaltyDashboardData(
    String profileId,
  ) async {
    try {
      final authUserId = _supabase.auth.currentUser?.id ?? profileId;
      final response = await _supabase.rpc(
        'get_loyalty_dashboard',
        params: {'p_auth_user_id': authUserId},
      );
      return right(response as Map<String, dynamic>);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, DailyCheckinEntity?>> getTodayCheckin(
    String profileId,
    String todayDate,
  ) async {
    try {
      final response =
          await _supabase
              .from('daily_checkins')
              .select()
              .eq('profile_id', profileId)
              .eq('checkin_date', todayDate)
              .maybeSingle();

      if (response == null) return right(null);
      return right(DailyCheckinModel.fromJson(response).toEntity());
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, DailyCheckinEntity?>> getLatestCheckin(
    String profileId,
  ) async {
    try {
      final response =
          await _supabase
              .from('daily_checkins')
              .select()
              .eq('profile_id', profileId)
              .order('checkin_date', ascending: false)
              .limit(1)
              .maybeSingle();

      if (response == null) return right(null);
      return right(DailyCheckinModel.fromJson(response).toEntity());
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<WalletMovementEntity>>> getTodayMiniGames(
    String profileId,
    String currentDayUtcIso,
  ) async {
    try {
      final response = await _supabase
          .from('wallet_movements')
          .select()
          .eq('profile_id', profileId)
          .like('movement_type', 'MINI_GAME_%')
          .gte('created_at', currentDayUtcIso);

      final models =
          List<Map<String, dynamic>>.from(
            response,
          ).map(WalletMovementModel.fromJson).toList();
      return right(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<WalletMovementEntity>>> getWalletMovements({
    required String profileId,
    required int limit,
    required int offset,
  }) async {
    try {
      final response = await _supabase
          .from('wallet_movements')
          .select(
            'id, profile_id, movement_type, points, description, created_at',
          )
          .eq('profile_id', profileId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final models =
          List<Map<String, dynamic>>.from(
            response,
          ).map(WalletMovementModel.fromJson).toList();
      return right(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> claimDailyCheckin({
    required String profileId,
    required String actionByProfileId,
  }) async {
    try {
      await _supabase.rpc(
        'claim_daily_checkin',
        params: {'p_profile_id': profileId, 'p_action_by': actionByProfileId},
      );
      return right(null);
    } catch (e) {
      developer.log(
        'RPC claim_daily_checkin falló ($e). Ejecutando respaldo resiliente en Dart...',
      );
      try {
        final todayStr = DateTime.now().toUtc().toIso8601String().substring(
          0,
          10,
        );

        // 1. Validar si ya existe el check-in de hoy
        final existing =
            await _supabase
                .from('daily_checkins')
                .select('id')
                .eq('profile_id', profileId)
                .eq('checkin_date', todayStr)
                .maybeSingle();
        if (existing != null) {
          return left(Failure.from('Ya realizaste tu check-in hoy.'));
        }

        // 2. Consultar la racha de ayer
        final yesterdayStr = DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 1))
            .toIso8601String()
            .substring(0, 10);
        final yesterdayCheckin =
            await _supabase
                .from('daily_checkins')
                .select('streak_day')
                .eq('profile_id', profileId)
                .eq('checkin_date', yesterdayStr)
                .maybeSingle();
        final streakDay =
            (yesterdayCheckin != null && yesterdayCheckin['streak_day'] != null)
                ? (yesterdayCheckin['streak_day'] as num).toInt() + 1
                : 1;

        // 3. Obtener configuración
        final settings = await _supabase
            .from('app_settings')
            .select('key, value')
            .inFilter('key', ['checkin_reward', 'checkin_streak_step']);
        int baseReward = 20;
        int streakStep = 10;
        for (final row in settings) {
          if (row['key'] == 'checkin_reward') {
            baseReward = int.tryParse(row['value'].toString()) ?? 20;
          } else if (row['key'] == 'checkin_streak_step') {
            streakStep = int.tryParse(row['value'].toString()) ?? 10;
          }
        }
        final points = baseReward + ((streakDay - 1) * streakStep);

        // 4. Insertar check-in incluyendo points_received
        await _supabase.from('daily_checkins').insert({
          'profile_id': profileId,
          'checkin_date': todayStr,
          'streak_day': streakDay,
          'points_received': points,
        });

        // 5. Insertar movimiento en billeteras
        await _supabase.from('wallet_movements').insert({
          'profile_id': profileId,
          'movement_type': 'CHECKIN',
          'points': points,
          'description': 'Check-in diario del $todayStr',
        });

        // 6. Actualizar balance en profiles
        final profile =
            await _supabase
                .from('profiles')
                .select('wallet_balance')
                .eq('id', profileId)
                .maybeSingle();
        final currentBalance =
            (profile != null && profile['wallet_balance'] != null)
                ? (profile['wallet_balance'] as num).toInt()
                : 0;
        await _supabase
            .from('profiles')
            .update({'wallet_balance': currentBalance + points})
            .eq('id', profileId);

        return right(null);
      } catch (fallbackE, fallbackSt) {
        return _handleError(fallbackE, fallbackSt);
      }
    }
  }

  @override
  Future<Either<Failure, void>> recordMiniGame({
    required String profileId,
    required String movementType,
    required int points,
    required String description,
  }) async {
    try {
      await _supabase.rpc(
        'award_mini_game_points',
        params: {
          'p_profile_id': profileId,
          'p_movement_type': movementType,
          'p_points': points,
          'p_description': description,
        },
      );
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<CustomerEntity>>> getTopCustomers(
    int limit, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final bool hasDateFilter = startDate != null || endDate != null;

    // 1. Si no hay filtros de fecha, intentar RPC rápido
    if (!hasDateFilter) {
      try {
        final response = await _supabase.rpc(
          'get_top_customers_rpc',
          params: {'p_limit': limit},
        );

        if (response != null && response is List && response.isNotEmpty) {
          final customers =
              response.map<CustomerEntity>((p) {
                return CustomerEntity(
                  id: p['id'] as String,
                  fullName: p['full_name'] as String? ?? 'Desconocido',
                  phone: p['phone'] as String?,
                  documentNumber: p['document_number'] as String?,
                  documentType: p['document_type'] as String?,
                  avatarUrl: p['avatar_url'] as String?,
                  isActive: p['is_active'] as bool? ?? true,
                  walletBalance:
                      (p['wallet_balance'] as num?)?.toDouble() ?? 0.0,
                  createdAt:
                      p['created_at'] != null
                          ? DateTime.tryParse(p['created_at'].toString())
                          : null,
                  totalRevenue:
                      ((p['total_revenue'] ?? p['total_spent']) as num?)
                          ?.toDouble() ??
                      0.0,
                  orderCount: (p['order_count'] as num?)?.toInt() ?? 0,
                );
              }).toList();

          return right(customers);
        }
      } catch (rpcErr) {
        developer.log(
          'get_top_customers_rpc no disponible o falló en LoyaltyRepo, usando fallback resiliente: $rpcErr',
        );
      }
    }

    // 2. Fallback resiliente consultando directamente 'orders' y perfiles
    try {
      var ordersQuery = _supabase
          .from('orders')
          .select('customer_id, total_amount, created_at')
          .eq('status', 'COMPLETED');

      if (startDate != null) {
        ordersQuery = ordersQuery.gte(
          'created_at',
          startDate.toUtc().toIso8601String(),
        );
      }
      if (endDate != null) {
        ordersQuery = ordersQuery.lte(
          'created_at',
          endDate.toUtc().toIso8601String(),
        );
      }

      final ordersRes = await ordersQuery.limit(3000);
      final revMap = <String, double>{};
      final countMap = <String, int>{};

      for (final row in (ordersRes as List)) {
        final cid = row['customer_id'] as String?;
        if (cid != null && cid.trim().isNotEmpty) {
          final amt = (row['total_amount'] as num?)?.toDouble() ?? 0.0;
          revMap[cid] = (revMap[cid] ?? 0.0) + amt;
          countMap[cid] = (countMap[cid] ?? 0) + 1;
        }
      }

      if (revMap.isEmpty) {
        return right([]);
      }

      final sortedEntries =
          revMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topIds = sortedEntries.take(limit).map((e) => e.key).toList();

      if (topIds.isEmpty) {
        return right([]);
      }

      dynamic profilesRes;
      try {
        profilesRes = await _supabase
            .from('customers')
            .select(
              'id, full_name, phone, document_number, document_type, wallet_balance, is_active, created_at',
            )
            .inFilter('id', topIds);
        if ((profilesRes as List).isEmpty) {
          profilesRes = await _supabase
              .from('profiles')
              .select(
                'id, full_name, phone, document_number, document_type, avatar_url, wallet_balance, is_active, created_at',
              )
              .inFilter('id', topIds);
        }
      } catch (_) {
        profilesRes = await _supabase
            .from('profiles')
            .select(
              'id, full_name, phone, document_number, document_type, avatar_url, wallet_balance, is_active, created_at',
            )
            .inFilter('id', topIds);
      }

      final list =
          (profilesRes as List).map<CustomerEntity>((json) {
            final cid = json['id'] as String;
            return CustomerEntity(
              id: cid,
              fullName: json['full_name'] as String? ?? 'Cliente',
              phone: json['phone'] as String?,
              documentNumber: json['document_number'] as String?,
              documentType: json['document_type'] as String?,
              avatarUrl: json['avatar_url'] as String?,
              walletBalance:
                  (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
              isActive: json['is_active'] as bool? ?? true,
              createdAt:
                  json['created_at'] != null
                      ? DateTime.tryParse(json['created_at'].toString())
                      : null,
              totalRevenue: revMap[cid] ?? 0.0,
              orderCount: countMap[cid] ?? 0,
            );
          }).toList();

      list.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
      return right(list);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }
}
