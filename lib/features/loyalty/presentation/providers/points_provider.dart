import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/providers/wallet_provider.dart';
import 'package:inventory_store_app/features/loyalty/data/repositories/points_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PointsProvider extends ChangeNotifier {
  final PointsService _service = PointsService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final Random _random = Random();
  RealtimeChannel? _walletChannel;
  bool _disposed = false;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isClaimingCheckin = false;
  bool _isPlayingMiniGame = false;
  bool _isPreparingBoxes = false;
  bool _boxesRoundReady = false;
  bool _showBoxesPreviewValues = false;
  bool _hasMoreMovements = true;

  String? _profileId;
  int _currentBalance = 0;
  int _currentStreak = 0;
  bool _hasTodayCheckin = false;
  DateTime? _lastCheckinDate;

  // Game counters
  int _boxesPlaysToday = 0;
  int _memoramaPlaysToday = 0;
  int _catcherPlaysToday = 0;
  int _pinataPlaysToday = 0;
  int _superSaltoPlaysToday = 0;
  int _clawPlaysToday = 0;
  int _stackPlaysToday = 0;
  int _dodgePlaysToday = 0;

  int? _lastBoxesReward;
  int _boxesShuffleSeed = 0;
  List<int> _miniGamePreviewBoxes = [];
  List<int> _miniGameBoxes = [];

  // Config rewards
  int _baseCheckinReward = 20;
  int _streakStepReward = 10;
  int _nextCheckinReward = 20;

  // Pagination
  final int _movementsLimit = 20;
  List<Map<String, dynamic>> _movements = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isClaimingCheckin => _isClaimingCheckin;
  bool get isPlayingMiniGame => _isPlayingMiniGame;
  bool get isPreparingBoxes => _isPreparingBoxes;
  bool get boxesRoundReady => _boxesRoundReady;
  bool get showBoxesPreviewValues => _showBoxesPreviewValues;
  bool get hasMoreMovements => _hasMoreMovements;

  String? get profileId => _profileId;
  int get currentBalance => _currentBalance;
  int get currentStreak => _currentStreak;
  bool get hasTodayCheckin => _hasTodayCheckin;
  int get nextCheckinReward => _nextCheckinReward;
  List<Map<String, dynamic>> get movements => _movements;

  int get boxesPlaysToday => _boxesPlaysToday;
  int get memoramaPlaysToday => _memoramaPlaysToday;
  int get catcherPlaysToday => _catcherPlaysToday;
  int get pinataPlaysToday => _pinataPlaysToday;
  int get superSaltoPlaysToday => _superSaltoPlaysToday;
  int get clawPlaysToday => _clawPlaysToday;
  int get stackPlaysToday => _stackPlaysToday;
  int get dodgePlaysToday => _dodgePlaysToday;

  int? get lastBoxesReward => _lastBoxesReward;
  int get boxesShuffleSeed => _boxesShuffleSeed;
  List<int> get miniGamePreviewBoxes => _miniGamePreviewBoxes;
  List<int> get miniGameBoxes => _miniGameBoxes;

  int rewardForStreakDay(int streakDay) {
    final safeDay = streakDay < 1 ? 1 : streakDay;
    return _baseCheckinReward + ((safeDay - 1) * _streakStepReward);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<int> _buildMiniGameBoxes(AppConfigCubit config) {
    final prize1 = config.getDouble('boxes_prize_1', 10).toInt();
    final prize2 = config.getDouble('boxes_prize_2', 20).toInt();
    final prize3 = config.getDouble('boxes_prize_3', 30).toInt();
    final pool = <int>[prize1, prize2, prize3]..shuffle(_random);
    return pool;
  }

  Future<void> fetchPointsData(AppConfigCubit config) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
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

      _baseCheckinReward = reward <= 0 ? 20 : reward;
      _streakStepReward = streakStep <= 0 ? 10 : streakStep;

      final profile = await _service.fetchProfileSummary(user.id);
      if (profile == null) throw Exception("Perfil no encontrado");

      _profileId = profile['id'];
      _currentBalance = (profile['wallet_balance'] as num?)?.toInt() ?? 0;

      final now = DateTime.now();
      final todayDate = DateFormat('yyyy-MM-dd').format(now);
      final currentDay = DateTime(now.year, now.month, now.day);
      final currentDayUtc = DateTime.utc(now.year, now.month, now.day);
      final yesterday = currentDay.subtract(const Duration(days: 1));

      // 1. Checkin de hoy
      final todayCheckin = await _service.fetchTodayCheckin(
        _profileId!,
        todayDate,
      );
      _hasTodayCheckin = todayCheckin != null;

      // 2. Último checkin (Racha)
      final latestCheckin = await _service.fetchLatestCheckin(_profileId!);
      final latestCheckinDate = DateTime.tryParse(
        latestCheckin?['checkin_date']?.toString() ?? '',
      );

      final isStreakActive =
          latestCheckinDate != null &&
          (_isSameDay(latestCheckinDate, currentDay) ||
              _isSameDay(latestCheckinDate, yesterday));

      final streakDay = (latestCheckin?['streak_day'] as num?)?.toInt() ?? 0;
      _currentStreak = isStreakActive ? streakDay : 0;
      _lastCheckinDate = latestCheckinDate;

      final nextStreakDay = _currentStreak > 0 ? _currentStreak + 1 : 1;
      _nextCheckinReward = rewardForStreakDay(nextStreakDay);

      // 3. Mini juegos de hoy
      final todayGames = await _service.fetchTodayMiniGames(
        _profileId!,
        currentDayUtc.toIso8601String(),
      );

      _boxesPlaysToday =
          todayGames
              .where((g) => g['movement_type'] == 'MINI_GAME_BOXES')
              .length;
      _memoramaPlaysToday =
          todayGames
              .where((g) => g['movement_type'] == 'MINI_GAME_MEMORY')
              .length;
      _catcherPlaysToday =
          todayGames
              .where((g) => g['movement_type'] == 'MINI_GAME_CATCHER')
              .length;
      _pinataPlaysToday =
          todayGames
              .where((g) => g['movement_type'] == 'MINI_GAME_PINATA')
              .length;
      _superSaltoPlaysToday =
          todayGames
              .where((g) => g['movement_type'] == 'MINI_GAME_JUMP')
              .length;
      _clawPlaysToday =
          todayGames
              .where((g) => g['movement_type'] == 'MINI_GAME_CLAW')
              .length;
      _stackPlaysToday =
          todayGames
              .where((g) => g['movement_type'] == 'MINI_GAME_STACK')
              .length;
      _dodgePlaysToday =
          todayGames
              .where((g) => g['movement_type'] == 'MINI_GAME_DODGE')
              .length;

      final boxGame =
          todayGames
              .where((g) => g['movement_type'] == 'MINI_GAME_BOXES')
              .firstOrNull;
      _lastBoxesReward =
          boxGame == null ? null : (boxGame['points'] as num?)?.toInt();

      _miniGameBoxes = _buildMiniGameBoxes(config);
      _miniGamePreviewBoxes = [];
      _boxesRoundReady = false;
      _showBoxesPreviewValues = false;
      _isPreparingBoxes = false;

      // 4. Cargar movimientos iniciales
      _movements = await _service.fetchMovementsPaginated(
        _profileId!,
        0,
        _movementsLimit,
      );
      _hasMoreMovements = _movements.length == _movementsLimit;

      _isLoading = false;
      
      // Suscribirse a cambios en la tabla profiles para wallet_balance
      _walletChannel?.unsubscribe();
      _walletChannel = _supabase
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
                if (newRow.isNotEmpty && !_disposed) {
                   final newBalance = (newRow['wallet_balance'] as num?)?.toInt() ?? 0;
                   if (_currentBalance != newBalance) {
                       _currentBalance = newBalance;
                       notifyListeners();
                   }
                }
              })
          .subscribe();
          
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      if (!_disposed) notifyListeners();
      debugPrint('Error loading points: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        throw Exception('Sin conexión a internet.');
      }
      throw Exception('Ocurrió un error inesperado al cargar tus puntos.');
    }
  }

  Future<void> loadMoreMovements() async {
    if (_profileId == null || _isLoadingMore || !_hasMoreMovements) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final moreMovements = await _service.fetchMovementsPaginated(
        _profileId!,
        _movements.length,
        _movementsLimit,
      );
      _movements.addAll(moreMovements);
      _hasMoreMovements = moreMovements.length == _movementsLimit;
    } catch (e) {
      debugPrint('Error loading more movements: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> claimDailyCheckin([WalletProvider? wallet]) async {
    if (_profileId == null || _hasTodayCheckin || _isClaimingCheckin) return;

    _isClaimingCheckin = true;
    notifyListeners();

    final now = DateTime.now();
    final todayDate = DateFormat('yyyy-MM-dd').format(now);
    final currentDay = DateTime(now.year, now.month, now.day);
    final yesterday = currentDay.subtract(const Duration(days: 1));

    final nextStreakDay =
        _lastCheckinDate != null && _isSameDay(_lastCheckinDate!, yesterday)
            ? _currentStreak + 1
            : 1;
    final rewardForToday = rewardForStreakDay(nextStreakDay);

    try {
      final newBalance = await _service.claimDailyCheckin(
        profileId: _profileId!,
        todayDate: todayDate,
        reward: rewardForToday,
        streakDay: nextStreakDay,
        description: 'Check-in diario del $todayDate',
      );

      _currentBalance = newBalance;
      wallet?.addLocalBalance(rewardForToday);

      _hasTodayCheckin = true;
      _currentStreak = nextStreakDay;
      _lastCheckinDate = currentDay;
      _nextCheckinReward = rewardForStreakDay(nextStreakDay + 1);

      _movements.insert(0, {
        'points': rewardForToday,
        'description': 'Check-in diario del $todayDate',
        'created_at': now.toIso8601String(),
      });
    } finally {
      _isClaimingCheckin = false;
      notifyListeners();
    }
  }

  Future<void> startBoxesRound(AppConfigCubit config) async {
    if (_isPlayingMiniGame || _isPreparingBoxes) {
      return;
    }

    final previewBoxes = _buildMiniGameBoxes(config);
    final shuffledBoxes = List<int>.from(previewBoxes)..shuffle(_random);

    _isPlayingMiniGame = true;
    _isPreparingBoxes = true;
    _boxesRoundReady = false;
    _showBoxesPreviewValues = true;
    _boxesShuffleSeed = _random.nextInt(1000);
    _miniGamePreviewBoxes = previewBoxes;
    _miniGameBoxes = shuffledBoxes;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1100));
    _showBoxesPreviewValues = false;
    _boxesShuffleSeed = _random.nextInt(1000);
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 850));
    _isPreparingBoxes = false;
    _isPlayingMiniGame = false;
    _boxesRoundReady = true;
    notifyListeners();
  }

  Future<int?> playBoxMiniGame(
    int boxIndex,
    AppConfigCubit config, [
    WalletProvider? wallet,
  ]) async {
    final boxesLimit = config.getDouble('boxes_daily_limit', 1).round();
    if (_isPlayingMiniGame || !_boxesRoundReady) {
      return null;
    }
    if (boxIndex < 0 || boxIndex >= _miniGameBoxes.length) return null;

    _isPlayingMiniGame = true;
    notifyListeners();

    final now = DateTime.now();
    final todayDate = DateFormat('yyyy-MM-dd').format(now);
    final isForFun = _boxesPlaysToday >= boxesLimit || _profileId == null;
    final reward = _miniGameBoxes[boxIndex];

    try {
      if (!isForFun) {
        final newBalance = await _service.recordMiniGamePlay(
          profileId: _profileId!,
          reward: reward,
          movementType: 'MINI_GAME_BOXES',
          description: 'Juego de cajas del $todayDate',
        );

        _currentBalance = newBalance;
        wallet?.addLocalBalance(reward);

        _movements.insert(0, {
          'points': reward,
          'description': 'Juego de cajas del $todayDate',
          'created_at': now.toIso8601String(),
        });
      }

      _boxesPlaysToday += 1;
      _lastBoxesReward = reward;
      _miniGameBoxes = _buildMiniGameBoxes(config);
      _miniGamePreviewBoxes = [];
      _boxesRoundReady = false;
      _showBoxesPreviewValues = false;

      return reward;
    } finally {
      _isPlayingMiniGame = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _walletChannel?.unsubscribe();
    super.dispose();
  }
}
