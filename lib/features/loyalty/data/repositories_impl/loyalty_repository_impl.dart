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
    developer.log('LoyaltyRepositoryError', error: e, stackTrace: st);
    if (e is PostgrestException) {
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
          .select()
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
        params: {
          'p_profile_id': profileId,
          'p_action_by': actionByProfileId,
        },
      );
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
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
    int limit,
  ) async {
    try {
      final response = await _supabase.rpc(
        'get_top_customers',
        params: {'p_limit': limit},
      );

      final customers =
          List<Map<String, dynamic>>.from(response).map((p) {
            return CustomerEntity(
              id: p['id'],
              fullName: p['full_name'] ?? 'Desconocido',
              avatarUrl: p['avatar_url'],
              isActive: p['is_active'] ?? true,
              walletBalance: p['wallet_balance'] ?? 0,
              createdAt: DateTime.parse(p['created_at']),
              totalRevenue: (p['total_revenue'] as num).toDouble(),
            );
          }).toList();

      return right(customers);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }
}
