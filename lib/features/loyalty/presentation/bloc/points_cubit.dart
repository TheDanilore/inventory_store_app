import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/points_state.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/get_loyalty_profile_uc.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/get_today_checkin_uc.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/get_latest_checkin_uc.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/get_today_mini_games_uc.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/get_wallet_movements_uc.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/claim_daily_checkin_uc.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/record_mini_game_uc.dart';

@injectable
class PointsCubit extends Cubit<PointsState> {
  final GetLoyaltyProfileUC getLoyaltyProfileUC;
  final GetTodayCheckinUC getTodayCheckinUC;
  final GetLatestCheckinUC getLatestCheckinUC;
  final GetTodayMiniGamesUC getTodayMiniGamesUC;
  final GetWalletMovementsUC getWalletMovementsUC;
  final ClaimDailyCheckinUC claimDailyCheckinUC;
  final RecordMiniGameUC recordMiniGameUC;

  final SupabaseClient _supabase;
  final Random _random = Random();
  RealtimeChannel? _walletChannel;
  final int _movementsLimit = 20;

  PointsCubit({
    required this.getLoyaltyProfileUC,
    required this.getTodayCheckinUC,
    required this.getLatestCheckinUC,
    required this.getTodayMiniGamesUC,
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

      // 1. Perfil
      final profileResult = await getLoyaltyProfileUC(user.id);
      final profile = profileResult.fold(
        (l) => throw Exception(l.message),
        (r) => r,
      );
      final profileId = profile.id;
      final currentBalance = profile.walletBalance;

      final now = DateTime.now();
      final todayDate = DateFormat('yyyy-MM-dd').format(now);
      final currentDay = DateTime(now.year, now.month, now.day);
      final currentDayUtc = DateTime.utc(now.year, now.month, now.day);
      final yesterday = currentDay.subtract(const Duration(days: 1));

      // 2. Checkin Hoy
      final todayCheckinResult = await getTodayCheckinUC(profileId, todayDate);
      final hasTodayCheckin = todayCheckinResult.fold(
        (l) => false,
        (r) => r != null,
      );

      // 3. Último checkin (Racha)
      final latestCheckinResult = await getLatestCheckinUC(profileId);
      final latestCheckin = latestCheckinResult.fold((l) => null, (r) => r);

      final latestCheckinDate =
          latestCheckin != null
              ? DateTime.tryParse(latestCheckin.checkinDate)
              : null;
      final isStreakActive =
          latestCheckinDate != null &&
          (_isSameDay(latestCheckinDate, currentDay) ||
              _isSameDay(latestCheckinDate, yesterday));

      final streakDay = latestCheckin?.streakDay ?? 0;
      final currentStreak = isStreakActive ? streakDay : 0;
      final nextStreakDay = currentStreak > 0 ? currentStreak + 1 : 1;
      final nextCheckinReward = _rewardForStreakDay(nextStreakDay);

      // 4. Mini juegos
      final miniGamesResult = await getTodayMiniGamesUC(
        profileId,
        currentDayUtc.toIso8601String(),
      );
      final todayGames = miniGamesResult.fold((l) => [], (r) => r);

      final boxGame =
          todayGames
              .where((g) => g.movementType == 'MINI_GAME_BOXES')
              .firstOrNull;

      // 5. Movimientos
      final movsResult = await getWalletMovementsUC(
        profileId: profileId,
        limit: _movementsLimit,
        offset: 0,
      );
      final movements =
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
          profileId: profileId,
          currentBalance: currentBalance,
          hasTodayCheckin: hasTodayCheckin,
          currentStreak: currentStreak,
          lastCheckinDate: latestCheckinDate,
          nextCheckinReward: nextCheckinReward,
          boxesPlaysToday:
              todayGames
                  .where((g) => g.movementType == 'MINI_GAME_BOXES')
                  .length,
          memoramaPlaysToday:
              todayGames
                  .where((g) => g.movementType == 'MINI_GAME_MEMORY')
                  .length,
          catcherPlaysToday:
              todayGames
                  .where((g) => g.movementType == 'MINI_GAME_CATCHER')
                  .length,
          pinataPlaysToday:
              todayGames
                  .where((g) => g.movementType == 'MINI_GAME_PINATA')
                  .length,
          superSaltoPlaysToday:
              todayGames
                  .where((g) => g.movementType == 'MINI_GAME_JUMP')
                  .length,
          clawPlaysToday:
              todayGames
                  .where((g) => g.movementType == 'MINI_GAME_CLAW')
                  .length,
          stackPlaysToday:
              todayGames
                  .where((g) => g.movementType == 'MINI_GAME_STACK')
                  .length,
          dodgePlaysToday:
              todayGames
                  .where((g) => g.movementType == 'MINI_GAME_DODGE')
                  .length,
          lastBoxesReward: boxGame?.points,
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

      // Suscribirse a cambios en wallet_balance
      _walletChannel?.unsubscribe();
      _walletChannel =
          _supabase
              .channel('public:profiles_points_${user.id}')
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'profiles',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'auth_user_id',
                  value: user.id,
                ),
                callback: (payload) {
                  final newRow = payload.newRecord;
                  if (newRow.isNotEmpty && !isClosed) {
                    final newBalance =
                        (newRow['wallet_balance'] as num?)?.toInt() ?? 0;
                    if (state.currentBalance != newBalance) {
                      emit(state.copyWith(currentBalance: newBalance));
                    }
                  }
                },
              )
              .subscribe();
    } catch (e) {
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
        ),
      );
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
        todayDate: todayDate,
        points: rewardForToday,
        streakDay: nextStreakDay,
        actionByProfileId: state.profileId!,
      );

      result.fold((failure) {}, (_) {
        if (isClosed) return;
        final newMovement = {
          'points': rewardForToday,
          'description': 'Check-in diario del \$todayDate',
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
      });
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
    final isForFun =
        state.boxesPlaysToday >= boxesLimit || state.profileId == null;
    final reward = state.miniGameBoxes[boxIndex];

    try {
      if (!isForFun) {
        final result = await recordMiniGameUC(
          profileId: state.profileId!,
          movementType: 'MINI_GAME_BOXES',
          points: reward,
          description: 'Juego de cajas del \$todayDate',
        );

        result.fold((l) => null, (_) {
          if (!isClosed) {
            final newMovement = {
              'points': reward,
              'description': 'Juego de cajas del \$todayDate',
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

      result.fold((l) => null, (_) {
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
      });
    } catch (e) {
      // Ignorar errores
    }
  }

  @override
  Future<void> close() {
    _walletChannel?.unsubscribe();
    return super.close();
  }
}
