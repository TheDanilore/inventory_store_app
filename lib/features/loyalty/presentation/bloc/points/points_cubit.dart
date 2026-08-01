import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/points/points_state.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/get_loyalty_dashboard_uc.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/get_wallet_movements_uc.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/claim_daily_checkin_uc.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/record_mini_game_uc.dart';

@injectable
class PointsCubit extends Cubit<PointsState> {
  final GetLoyaltyDashboardUC getLoyaltyDashboardUC;
  final GetWalletMovementsUC getWalletMovementsUC;
  final ClaimDailyCheckinUC claimDailyCheckinUC;
  final RecordMiniGameUC recordMiniGameUC;

  final SupabaseClient _supabase;
  final Random _random = Random();
  RealtimeChannel? _walletChannel;
  final int _movementsLimit = 20;

  PointsCubit({
    required this.getLoyaltyDashboardUC,
    required this.getWalletMovementsUC,
    required this.claimDailyCheckinUC,
    required this.recordMiniGameUC,
    required SupabaseClient supabase,
  }) : _supabase = supabase,
       super(const PointsState());

  int _rewardForStreakDay(int streakDay) {
    final safeDay = streakDay < 1 ? 1 : streakDay;
    return state.baseCheckinReward + ((safeDay - 1) * state.streakStepReward);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<int> _buildMiniGameBoxes(AppConfigCubit config) {
    final prize1 = config.getDouble('boxes_prize_1', 10).toInt();
    final prize2 = config.getDouble('boxes_prize_2', 20).toInt();
    final prize3 = config.getDouble('boxes_prize_3', 30).toInt();
    return <int>[prize1, prize2, prize3]..shuffle(_random);
  }

  Future<void> fetchPointsData(AppConfigCubit config) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      emit(state.copyWith(isLoading: false));
      return;
    }

    try {
      final reward =
          config
              .getDouble(
                'checkin_reward',
                config.getDouble('daily_checkin_reward', 10),
              )
              .round();
      final streakStep = config.getDouble('checkin_streak_step', 10).round();
      final baseReward = reward <= 0 ? 20 : reward;
      final stepReward = streakStep <= 0 ? 10 : streakStep;

      emit(
        state.copyWith(
          isLoading: true,
          baseCheckinReward: baseReward,
          streakStepReward: stepReward,
        ),
      );

      // Obtener datos del dashboard
      final dashboardResult = await getLoyaltyDashboardUC(user.id);
      final dashboard = dashboardResult.fold(
        (l) => throw Exception(l.message),
        (r) => r,
      );

      final profileId = dashboard['profile_id'] as String;
      final currentBalance = dashboard['wallet_balance'] as int;
      final hasTodayCheckin = dashboard['has_today_checkin'] as bool;

      final now = DateTime.now();
      final currentDay = DateTime(now.year, now.month, now.day);
      final yesterday = currentDay.subtract(const Duration(days: 1));

      // Checkin y Racha
      final latestCheckin = dashboard['latest_checkin'] as Map<String, dynamic>?;
      final latestCheckinDateStr = latestCheckin?['checkin_date'] as String?;
      final latestCheckinDate = latestCheckinDateStr != null ? DateTime.tryParse(latestCheckinDateStr) : null;

      final isStreakActive =
          latestCheckinDate != null &&
          (_isSameDay(latestCheckinDate, currentDay) ||
              _isSameDay(latestCheckinDate, yesterday));

      final streakDay = (latestCheckin?['streak_day'] as num?)?.toInt() ?? 0;
      final currentStreak = isStreakActive ? streakDay : 0;
      final nextStreakDay = currentStreak > 0 ? currentStreak + 1 : 1;
      final nextCheckinReward = _rewardForStreakDay(nextStreakDay);

      // Minijuegos
      final todayGames = dashboard['today_games'] as Map<String, dynamic>? ?? {};

      // Movimientos
      final movements = List<Map<String, dynamic>>.from(dashboard['recent_movements'] ?? []);

      final boxGame = movements.firstWhere(
        (m) => m['movement_type'] == 'MINI_GAME_BOXES' && (m['created_at'] as String).startsWith(now.toUtc().toIso8601String().substring(0, 10)),
        orElse: () => <String, dynamic>{},
      );

      emit(
        state.copyWith(
          profileId: profileId,
          currentBalance: currentBalance,
          hasTodayCheckin: hasTodayCheckin,
          currentStreak: currentStreak,
          lastCheckinDate: latestCheckinDate,
          nextCheckinReward: nextCheckinReward,
          lastBoxesReward: boxGame['points'] as int?,
          boxesPlaysToday: (todayGames['MINI_GAME_BOXES'] as num?)?.toInt() ?? 0,
          memoramaPlaysToday: (todayGames['MINI_GAME_MEMORY'] as num?)?.toInt() ?? 0,
          catcherPlaysToday: (todayGames['MINI_GAME_CATCHER'] as num?)?.toInt() ?? 0,
          pinataPlaysToday: (todayGames['MINI_GAME_PINATA'] as num?)?.toInt() ?? 0,
          superSaltoPlaysToday: (todayGames['MINI_GAME_JUMP'] as num?)?.toInt() ?? 0,
          clawPlaysToday: (todayGames['MINI_GAME_CLAW'] as num?)?.toInt() ?? 0,
          stackPlaysToday: (todayGames['MINI_GAME_STACK'] as num?)?.toInt() ?? 0,
          dodgePlaysToday: (todayGames['MINI_GAME_DODGE'] as num?)?.toInt() ?? 0,
          miniGameBoxes: _buildMiniGameBoxes(config),
          miniGamePreviewBoxes: const [],
          boxesRoundReady: false,
          showBoxesPreviewValues: false,
          isPreparingBoxes: false,
          movements: movements,
          hasMoreMovements: movements.length == _movementsLimit,
          isLoading: false,
        ),
      );

      // Suscribirse a cambios en wallet_balance (solo una vez)
      _initWalletChannel(user.id);
    } catch (e, st) {
      developer.log('Error en fetchPointsData', error: e, stackTrace: st);
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Ocurrió un error inesperado al cargar tus puntos.',
          ),
        );
      }
    }
  }

  Future<void> loadMoreMovements() async {
    if (state.profileId == null ||
        state.isLoadingMore ||
        !state.hasMoreMovements) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));
    try {
      final movsResult = await getWalletMovementsUC(
        profileId: state.profileId!,
        limit: _movementsLimit,
        offset: state.movements.length,
      );
      final moreMovs =
          movsResult
              .fold((l) => [], (r) => r)
              .map(
                (e) => {
                  'points': e.points,
                  'description': e.description,
                  'movement_type': e.movementType,
                  'created_at': e.createdAt.toIso8601String(),
                },
              )
              .toList();

      emit(
        state.copyWith(
          movements: [...state.movements, ...moreMovs],
          hasMoreMovements: moreMovs.length == _movementsLimit,
          loadMoreError: null,
        ),
      );
    } catch (e, st) {
      developer.log('Error en loadMoreMovements', error: e, stackTrace: st);
      if (!isClosed) {
        emit(state.copyWith(loadMoreError: 'No se pudieron cargar más movimientos.'));
      }
    } finally {
      if (!isClosed) emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> claimDailyCheckin() async {
    if (state.profileId == null ||
        state.hasTodayCheckin ||
        state.isClaimingCheckin) {
      return;
    }

    emit(state.copyWith(isClaimingCheckin: true));

    final now = DateTime.now();
    final todayDate = DateFormat('yyyy-MM-dd').format(now);
    final currentDay = DateTime(now.year, now.month, now.day);
    final yesterday = currentDay.subtract(const Duration(days: 1));

    final nextStreakDay =
        state.lastCheckinDate != null &&
                _isSameDay(state.lastCheckinDate!, yesterday)
            ? state.currentStreak + 1
            : 1;
    final rewardForToday = _rewardForStreakDay(nextStreakDay);

    try {
      final result = await claimDailyCheckinUC(
        profileId: state.profileId!,
        actionByProfileId: state.profileId!,
      );

      result.fold(
        (failure) {
          if (!isClosed) {
            emit(state.copyWith(errorMessage: failure.message));
          }
        }, 
        (_) {
          if (isClosed) return;
          final newMovement = {
            'points': rewardForToday,
            'description': 'Check-in diario del $todayDate',
            'created_at': now.toIso8601String(),
          };

          emit(
            state.copyWith(
              hasTodayCheckin: true,
              currentStreak: nextStreakDay,
              lastCheckinDate: currentDay,
              nextCheckinReward: _rewardForStreakDay(nextStreakDay + 1),
              movements: [newMovement, ...state.movements],
              currentBalance: state.currentBalance + rewardForToday,
            ),
          );
        }
      );
    } catch (e, st) {
      developer.log('Error claimDailyCheckin', error: e, stackTrace: st);
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Ocurrió un error inesperado al reclamar el check-in.'));
      }
    } finally {
      if (!isClosed) emit(state.copyWith(isClaimingCheckin: false));
    }
  }

  Future<void> startBoxesRound(AppConfigCubit config) async {
    if (state.isPlayingMiniGame || state.isPreparingBoxes) return;

    final previewBoxes = _buildMiniGameBoxes(config);
    final shuffledBoxes = List<int>.from(previewBoxes)..shuffle(_random);

    emit(
      state.copyWith(
        isPlayingMiniGame: true,
        isPreparingBoxes: true,
        boxesRoundReady: false,
        showBoxesPreviewValues: true,
        boxesShuffleSeed: _random.nextInt(1000),
        miniGamePreviewBoxes: previewBoxes,
        miniGameBoxes: shuffledBoxes,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1100));
    if (isClosed) return;
    emit(
      state.copyWith(
        showBoxesPreviewValues: false,
        boxesShuffleSeed: _random.nextInt(1000),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 850));
    if (isClosed) return;
    emit(
      state.copyWith(
        isPreparingBoxes: false,
        isPlayingMiniGame: false,
        boxesRoundReady: true,
      ),
    );
  }

  Future<int?> playBoxMiniGame(int boxIndex, AppConfigCubit config) async {
    final boxesLimit = config.getDouble('boxes_daily_limit', 1).round();
    if (state.isPlayingMiniGame || !state.boxesRoundReady) return null;
    if (boxIndex < 0 || boxIndex >= state.miniGameBoxes.length) return null;

    emit(state.copyWith(isPlayingMiniGame: true));

    final now = DateTime.now();
    final todayDate = DateFormat('yyyy-MM-dd').format(now);
    final isForFun =
        state.boxesPlaysToday >= boxesLimit || state.profileId == null;
    final reward = state.miniGameBoxes[boxIndex];

    try {
      if (!isForFun) {
        final result = await recordMiniGameUC(
          profileId: state.profileId!,
          movementType: 'MINI_GAME_BOXES',
          points: reward,
          description: 'Juego de cajas del $todayDate',
        );

        result.fold((l) {
          if (!isClosed) {
            emit(state.copyWith(errorMessage: l.message));
          }
        }, (_) {
          if (!isClosed) {
            final newMovement = {
              'points': reward,
              'description': 'Juego de cajas del $todayDate',
              'created_at': now.toIso8601String(),
            };
            emit(
              state.copyWith(
                currentBalance: state.currentBalance + reward,
                movements: [newMovement, ...state.movements],
              ),
            );
          }
        });
      }

      if (!isClosed) {
        emit(
          state.copyWith(
            boxesPlaysToday: state.boxesPlaysToday + 1,
            lastBoxesReward: reward,
            miniGameBoxes: _buildMiniGameBoxes(config),
            miniGamePreviewBoxes: const [],
            boxesRoundReady: false,
            showBoxesPreviewValues: false,
          ),
        );
      }
      return reward;
    } finally {
      if (!isClosed) emit(state.copyWith(isPlayingMiniGame: false));
    }
  }

  Future<void> recordMiniGameResult(
    String movementType,
    int points,
    String description,
  ) async {
    if (state.profileId == null) return;

    final now = DateTime.now();
    try {
      final result = await recordMiniGameUC(
        profileId: state.profileId!,
        movementType: movementType,
        points: points,
        description: description,
      );

      result.fold(
        (failure) {
          if (!isClosed) {
            emit(state.copyWith(errorMessage: failure.message));
          }
        }, 
        (_) {
          if (!isClosed) {
            final newMovement = {
              'points': points,
              'description': description,
              'created_at': now.toIso8601String(),
            };
            emit(
              state.copyWith(
                currentBalance: state.currentBalance + points,
                movements: [newMovement, ...state.movements],
              ),
            );
          }
        }
      );
    } catch (e, st) {
      developer.log('Error al guardar minijuego', error: e, stackTrace: st);
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Ocurrió un error inesperado al guardar el premio.'));
      }
    }
  }

  void _initWalletChannel(String authUserId) {
    if (_walletChannel != null) return; // Ya está suscrito

    _walletChannel = _supabase
        .channel('public:profiles_points_$authUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'auth_user_id',
            value: authUserId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            if (newRow.isNotEmpty && !isClosed) {
              final newBalance = (newRow['wallet_balance'] as num?)?.toInt() ?? 0;
              if (state.currentBalance != newBalance) {
                emit(state.copyWith(currentBalance: newBalance));
              }
            }
          },
        )
        .subscribe();
  }

  @override
  Future<void> close() {
    _walletChannel?.unsubscribe();
    return super.close();
  }
}
