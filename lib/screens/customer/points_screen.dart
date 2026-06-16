import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart';
import 'package:inventory_store_app/screens/customer/games/coin_catcher_game_screen.dart';
import 'package:inventory_store_app/screens/customer/games/dodge_game_screen.dart';
import 'package:inventory_store_app/screens/customer/games/memorama_game_screen.dart';
import 'package:inventory_store_app/screens/customer/games/pinata_game_screen.dart';
import 'package:inventory_store_app/screens/customer/games/super_salto_screen.dart';
import 'package:inventory_store_app/screens/customer/games/claw_machine_screen.dart';
import 'package:inventory_store_app/screens/customer/games/stack_game_screen.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/customer_layout.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── DESIGN TOKENS ────────────────────────────────────────────────────────────

class _DS {
  // Amber / gold palette
  static const gold = Color(0xFFF59E0B);
  static const goldLight = Color(0xFFFEF3C7);
  static const goldDark = Color(0xFF92400E);
  static const goldMid = Color(0xFFFBBF24);

  // Teal palette
  static const teal = Color(0xFF0D9488);
  static const tealLight = Color(0xFFCCFBF1);
  static const tealDark = Color(0xFF0F766E);

  // Neutrals
  static const bg = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const border = Color(0xFFE8ECF0);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  // Status
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFD1FAE5);
  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFFFE4E6);

  static const radius = 16.0;
  static const radiusXl = 24.0;

  static List<BoxShadow> cardShadow({double opacity = 0.06}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: opacity),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

// ─── SCREEN ───────────────────────────────────────────────────────────────────

class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  final _supabase = Supabase.instance.client;
  final _random = Random();

  List<Map<String, dynamic>> _movements = [];
  int _currentBalance = 0;
  int _currentStreak = 0;
  int _baseCheckinReward = 20;
  int _streakStepReward = 10;
  int _nextCheckinReward = 20;
  bool _hasTodayCheckin = false;
  int _boxesPlaysToday = 0;
  int _memoramaPlaysToday = 0;
  int _catcherPlaysToday = 0;
  int _pinataPlaysToday = 0;
  int _superSaltoPlaysToday = 0;
  int _clawPlaysToday = 0;
  int _stackPlaysToday = 0;
  int _dodgePlaysToday = 0;
  bool _isClaimingCheckin = false;
  bool _isPlayingMiniGame = false;
  bool _isPreparingBoxes = false;
  bool _boxesRoundReady = false;
  bool _showBoxesPreviewValues = false;
  bool _isLoading = true;
  String? _profileId;
  DateTime? _lastCheckinDate;
  int? _lastBoxesReward;
  int _boxesShuffleSeed = 0;
  List<int> _miniGamePreviewBoxes = [];
  List<int> _miniGameBoxes = [];

  static const String _boxesPrize1Key = 'boxes_prize_1';
  static const String _boxesPrize2Key = 'boxes_prize_2';
  static const String _boxesPrize3Key = 'boxes_prize_3';
  static const double _defaultBoxesPrize1 = 10;
  static const double _defaultBoxesPrize2 = 20;
  static const double _defaultBoxesPrize3 = 30;

  @override
  void initState() {
    super.initState();
    _fetchPointsData();
  }

  int _rewardForStreakDay(int streakDay) {
    final safeDay = streakDay < 1 ? 1 : streakDay;
    return _baseCheckinReward + ((safeDay - 1) * _streakStepReward);
  }

  List<int> _buildMiniGameBoxes(AppConfigProvider config) {
    final prize1 =
        config.getDouble(_boxesPrize1Key, _defaultBoxesPrize1).toInt();
    final prize2 =
        config.getDouble(_boxesPrize2Key, _defaultBoxesPrize2).toInt();
    final prize3 =
        config.getDouble(_boxesPrize3Key, _defaultBoxesPrize3).toInt();
    final pool = <int>[prize1, prize2, prize3]..shuffle(_random);
    return pool;
  }

  Future<void> _startBoxesRound() async {
    final config = context.read<AppConfigProvider>();
    final boxesLimit = config.getDouble('boxes_daily_limit', 1).round();
    if (_profileId == null ||
        _boxesPlaysToday >= boxesLimit ||
        _isPlayingMiniGame ||
        _isPreparingBoxes) {
      return;
    }

    final previewBoxes = _buildMiniGameBoxes(config);
    final shuffledBoxes = List<int>.from(previewBoxes)..shuffle(_random);

    setState(() {
      _isPlayingMiniGame = true;
      _isPreparingBoxes = true;
      _boxesRoundReady = false;
      _showBoxesPreviewValues = true;
      _boxesShuffleSeed = _random.nextInt(1000);
      _miniGamePreviewBoxes = previewBoxes;
      _miniGameBoxes = shuffledBoxes;
    });

    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() {
      _showBoxesPreviewValues = false;
      _boxesShuffleSeed = _random.nextInt(1000);
    });

    await Future.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    setState(() {
      _isPreparingBoxes = false;
      _isPlayingMiniGame = false;
      _boxesRoundReady = true;
    });
  }

  Future<void> _fetchPointsData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final config = context.read<AppConfigProvider>();
      final reward =
          config
              .getDouble(
                'checkin_reward',
                config.getDouble('daily_checkin_reward', 10),
              )
              .round();
      final streakStep = config.getDouble('checkin_streak_step', 10).round();

      final profile =
          await _supabase
              .from('profiles')
              .select('id, wallet_balance')
              .eq('auth_user_id', user.id)
              .single();

      final profileId = profile['id'];
      final today = DateTime.now();
      final todayDate = DateFormat('yyyy-MM-dd').format(today);
      final currentDay = DateTime(today.year, today.month, today.day);
      final currentDayUtc = DateTime.utc(today.year, today.month, today.day);
      final yesterday = currentDay.subtract(const Duration(days: 1));

      final todayCheckin =
          await _supabase
              .from('daily_checkins')
              .select('id')
              .eq('profile_id', profileId)
              .eq('checkin_date', todayDate)
              .maybeSingle();

      final latestCheckin =
          await _supabase
              .from('daily_checkins')
              .select('checkin_date, streak_day, points_received, created_at')
              .eq('profile_id', profileId)
              .order('checkin_date', ascending: false)
              .limit(1)
              .maybeSingle();

      final latestCheckinDate = DateTime.tryParse(
        latestCheckin?['checkin_date']?.toString() ?? '',
      );
      final isStreakActive =
          latestCheckinDate != null &&
          (isSameDay(latestCheckinDate, currentDay) ||
              isSameDay(latestCheckinDate, yesterday));
      final streakDay = (latestCheckin?['streak_day'] as num?)?.toInt() ?? 0;
      final activeStreakDay = isStreakActive ? streakDay : 0;
      final nextStreakDay = activeStreakDay > 0 ? activeStreakDay + 1 : 1;

      final todayGames = List<Map<String, dynamic>>.from(
        await _supabase
            .from('wallet_movements')
            .select('movement_type, points, created_at')
            .eq('profile_id', profileId)
            .like('movement_type', 'MINI_GAME_%')
            .gte('created_at', currentDayUtc.toIso8601String()),
      );

      final boxGame = todayGames
          .where((g) => g['movement_type'] == 'MINI_GAME_BOXES')
          .cast<Map<String, dynamic>?>()
          .firstWhere((_) => true, orElse: () => null);

      final movements = await _supabase
          .from('wallet_movements')
          .select('*, orders(id)')
          .eq('profile_id', profileId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _currentBalance = (profile['wallet_balance'] as num?)?.toInt() ?? 0;
        _movements = List<Map<String, dynamic>>.from(movements);
        _profileId = profileId as String?;
        _baseCheckinReward = reward <= 0 ? 20 : reward;
        _streakStepReward = streakStep <= 0 ? 10 : streakStep;
        _hasTodayCheckin = todayCheckin != null;
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
        _lastCheckinDate = latestCheckinDate;
        _lastBoxesReward =
            boxGame == null ? null : (boxGame['points'] as num?)?.toInt();
        _currentStreak = activeStreakDay;
        _nextCheckinReward = _rewardForStreakDay(nextStreakDay);
        _miniGameBoxes = _buildMiniGameBoxes(config);
        _miniGamePreviewBoxes = [];
        _boxesRoundReady = false;
        _showBoxesPreviewValues = false;
        _isPreparingBoxes = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackbar.show(
        context,
        message: 'Error cargando monedas: $e',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _claimDailyCheckin() async {
    if (_profileId == null || _hasTodayCheckin || _isClaimingCheckin) return;
    setState(() => _isClaimingCheckin = true);

    final now = DateTime.now();
    final currentDay = DateTime(now.year, now.month, now.day);
    final yesterday = currentDay.subtract(const Duration(days: 1));
    final todayDate = DateFormat('yyyy-MM-dd').format(now);
    final nextStreakDay =
        _lastCheckinDate != null && isSameDay(_lastCheckinDate!, yesterday)
            ? _currentStreak + 1
            : 1;
    final rewardForToday = _rewardForStreakDay(nextStreakDay);

    try {
      await _supabase.from('daily_checkins').insert({
        'profile_id': _profileId,
        'checkin_date': todayDate,
        'points_received': rewardForToday,
        'streak_day': nextStreakDay,
      });
      await _supabase.from('wallet_movements').insert({
        'profile_id': _profileId,
        'points': rewardForToday,
        'movement_type': 'DAILY_CHECKIN',
        'description': 'Check-in diario del $todayDate',
      });

      // 1. AVISAMOS AL PROVIDER AQUÍ
      if (mounted) {
        Provider.of<WalletProvider>(context, listen: false).refresh();
      }

      if (!mounted) return;
      setState(() {
        _currentBalance += rewardForToday;
        _hasTodayCheckin = true;
        _currentStreak = nextStreakDay;
        _lastCheckinDate = currentDay;
        _nextCheckinReward = _rewardForStreakDay(nextStreakDay + 1);
        _movements.insert(0, {
          'points': rewardForToday,
          'description': 'Check-in diario del $todayDate',
          'created_at': now.toIso8601String(),
        });
      });
      AppSnackbar.show(
        context,
        message: 'Reclamaste $rewardForToday monedas por tu check-in diario.',
        type: SnackbarType.success,
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message:
            e.code == '23505'
                ? 'Ya reclamaste tus monedas de hoy.'
                : 'No se pudo reclamar el check-in: ${e.message}',
        type: SnackbarType.error,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'No se pudo reclamar el check-in: $e',
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isClaimingCheckin = false);
    }
  }

  Future<void> _playBoxMiniGame(int boxIndex) async {
    final config = context.read<AppConfigProvider>();
    final boxesLimit = config.getDouble('boxes_daily_limit', 1).round();
    if (_profileId == null ||
        _boxesPlaysToday >= boxesLimit ||
        _isPlayingMiniGame ||
        !_boxesRoundReady) {
      return;
    }
    if (boxIndex < 0 || boxIndex >= _miniGameBoxes.length) return;

    setState(() => _isPlayingMiniGame = true);
    final now = DateTime.now();
    final todayDate = DateFormat('yyyy-MM-dd').format(now);
    final reward = _miniGameBoxes[boxIndex];

    try {
      await _supabase.from('wallet_movements').insert({
        'profile_id': _profileId,
        'points': reward,
        'movement_type': 'MINI_GAME_BOXES',
        'description': 'Juego de cajas del $todayDate',
      });

      // 2. AVISAMOS AL PROVIDER AQUÍ TAMBIÉN
      if (mounted) {
        Provider.of<WalletProvider>(context, listen: false).refresh();
      }

      if (!mounted) return;
      setState(() {
        _currentBalance += reward;
        _boxesPlaysToday += 1;
        _lastBoxesReward = reward;
        _miniGameBoxes = _buildMiniGameBoxes(config);
        _miniGamePreviewBoxes = [];
        _boxesRoundReady = false;
        _showBoxesPreviewValues = false;
        _movements.insert(0, {
          'points': reward,
          'description': 'Juego de cajas del $todayDate',
          'created_at': now.toIso8601String(),
        });
      });
      AppSnackbar.show(
        context,
        message: 'Ganaste $reward monedas en el jueguito de cajas.',
        type: SnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'No se pudo jugar en este momento: $e',
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isPlayingMiniGame = false);
    }
  }

  Future<void> _openCoinCatcherGame() async {
    final limit =
        context
            .read<AppConfigProvider>()
            .getDouble('catcher_daily_limit', 1)
            .round();
    if (_profileId == null || _catcherPlaysToday >= limit) return;
    final reward = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CoinCatcherGameScreen(profileId: _profileId!),
      ),
    );
    if (!mounted) return;
    if (reward != null) {
      setState(() => _catcherPlaysToday += 1);
      await _fetchPointsData();
      if (mounted)
        Provider.of<WalletProvider>(context, listen: false).refresh(); // AVISO
    }
  }

  Future<void> _openMemoramaGame() async {
    final limit =
        context
            .read<AppConfigProvider>()
            .getDouble('memorama_daily_limit', 1)
            .round();
    if (_profileId == null || _memoramaPlaysToday >= limit) return;
    final reward = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => MemoramaGameScreen(profileId: _profileId!),
      ),
    );
    if (!mounted) return;
    if (reward != null) {
      setState(() => _memoramaPlaysToday += 1);
      await _fetchPointsData();
      if (mounted)
        Provider.of<WalletProvider>(context, listen: false).refresh(); // AVISO
    }
  }

  Future<void> _openPinataGame() async {
    final limit =
        context
            .read<AppConfigProvider>()
            .getDouble('pinata_daily_limit', 1)
            .round();
    if (_profileId == null || _pinataPlaysToday >= limit) return;
    final reward = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => PinataGameScreen(profileId: _profileId!),
      ),
    );
    if (!mounted) return;
    if (reward != null) {
      setState(() => _pinataPlaysToday += 1);
      await _fetchPointsData();
      if (mounted)
        Provider.of<WalletProvider>(context, listen: false).refresh(); // AVISO
    }
  }

  Future<void> _openSuperSaltoGame() async {
    final limit =
        context
            .read<AppConfigProvider>()
            .getDouble('jump_daily_limit', 1)
            .round();
    if (_profileId == null || _superSaltoPlaysToday >= limit) return;
    final pts = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => SuperSaltoScreen(profileId: _profileId!),
      ),
    );
    if (!mounted) return;
    if (pts != null) {
      setState(() => _superSaltoPlaysToday += 1);
      await _fetchPointsData();
      if (mounted)
        Provider.of<WalletProvider>(context, listen: false).refresh(); // AVISO
    }
  }

  Future<void> _openClawMachineGame() async {
    final limit =
        context
            .read<AppConfigProvider>()
            .getDouble('claw_daily_limit', 1)
            .round();
    if (_profileId == null || _clawPlaysToday >= limit) return;
    final r = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => ClawMachineScreen(profileId: _profileId!),
      ),
    );
    if (!mounted) return;
    if (r != null) {
      setState(() => _clawPlaysToday += 1);
      await _fetchPointsData();
      if (mounted)
        Provider.of<WalletProvider>(context, listen: false).refresh(); // AVISO
    }
  }

  Future<void> _openStackGame() async {
    final limit =
        context
            .read<AppConfigProvider>()
            .getDouble('stack_daily_limit', 1)
            .round();
    if (_profileId == null || _stackPlaysToday >= limit) return;
    final r = await Navigator.push<int?>(
      context,
      MaterialPageRoute(
        builder: (_) => StackGameScreen(profileId: _profileId!),
      ),
    );
    if (!mounted) return;
    if (r != null) {
      await _fetchPointsData();
      if (mounted)
        Provider.of<WalletProvider>(context, listen: false).refresh(); // AVISO
    }
  }

  Future<void> _openDodgeGame() async {
    final limit =
        context
            .read<AppConfigProvider>()
            .getDouble('dodge_daily_limit', 1)
            .round();
    if (_profileId == null || _dodgePlaysToday >= limit) return;
    final r = await Navigator.push<int?>(
      context,
      MaterialPageRoute(
        builder: (_) => DodgeGameScreen(profileId: _profileId!),
      ),
    );
    if (!mounted) return;
    if (r != null) {
      await _fetchPointsData();
      if (mounted)
        Provider.of<WalletProvider>(context, listen: false).refresh(); // AVISO
    }
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _streakPreviewLabel() {
    final d1 = _rewardForStreakDay(1);
    final d2 = _rewardForStreakDay(2);
    return 'Día 1: $d1 monedas. Día 2: $d2 monedas. Sigue la racha para ganar más.';
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final hundredCoinsValue = (100 * pointsToSolesRatio).toStringAsFixed(2);
    final boxesLimit = config.getDouble('boxes_daily_limit', 1).round();
    final memoramaLimit = config.getDouble('memorama_daily_limit', 1).round();
    final catcherLimit = config.getDouble('catcher_daily_limit', 1).round();
    final pinataLimit = config.getDouble('pinata_daily_limit', 1).round();
    final superSaltoLimit = config.getDouble('jump_daily_limit', 1).round();
    final clawLimit = config.getDouble('claw_daily_limit', 1).round();
    final stackLimit = config.getDouble('stack_daily_limit', 1).round();
    final dodgeLimit = config.getDouble('dodge_daily_limit', 1).round();

    final canPlayBoxes = _boxesPlaysToday < boxesLimit;
    final canPlayMemorama = _memoramaPlaysToday < memoramaLimit;
    final canPlayCatcher = _catcherPlaysToday < catcherLimit;
    final canPlayPinata = _pinataPlaysToday < pinataLimit;
    final canPlaySuperSalto = _superSaltoPlaysToday < superSaltoLimit;
    final canPlayClaw = _clawPlaysToday < clawLimit;
    final canPlayStack = _stackPlaysToday < stackLimit;
    final canPlayDodge = _dodgePlaysToday < dodgeLimit;

    final claimMessage =
        _hasTodayCheckin
            ? 'Hoy ya reclamaste tus monedas. Vuelve mañana para seguir la racha.'
            : 'Reclama tus monedas de hoy con un toque y mantén activa tu racha.';

    final prizePreview =
        _boxesRoundReady && _miniGameBoxes.isNotEmpty
            ? _miniGameBoxes
            : (_miniGamePreviewBoxes.isNotEmpty
                ? _miniGamePreviewBoxes
                : _miniGameBoxes);

    return CustomerLayout(
      title: 'Mis Monedas',
      showBackButton: true,
      showBottomNav: false,
      showCartIcon: true,
      showWalletChip: true,
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              )
              : SafeArea(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── 1. Hero balance card ─────────────────────────────
                      _BalanceHeroCard(
                        currentBalance: _currentBalance,
                        hundredCoinsValue: hundredCoinsValue,
                        currentStreak: _currentStreak,
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),

                            // ── 2. Check-in diario ───────────────────────
                            PointsDailyCheckinCard(
                              hundredCoinsValue: hundredCoinsValue,
                              claimMessage: claimMessage,
                              streakPreviewLabel: _streakPreviewLabel(),
                              currentStreak: _currentStreak,
                              nextCheckinReward: _nextCheckinReward,
                              hasTodayCheckin: _hasTodayCheckin,
                              isClaimingCheckin: _isClaimingCheckin,
                              onClaim: _claimDailyCheckin,
                            ),
                            const SizedBox(height: 16),

                            // ── 3. Juegos diarios ────────────────────────
                            PointsGameActionsSection(
                              playsToday: _memoramaPlaysToday,
                              dailyLimit: memoramaLimit,
                              canPlay: canPlayMemorama,
                              onPlayMemorama: _openMemoramaGame,
                              catcherPlaysToday: _catcherPlaysToday,
                              catcherDailyLimit: catcherLimit,
                              canPlayCatcher: canPlayCatcher,
                              onPlayCoinCatcher: _openCoinCatcherGame,
                              pinataPlaysToday: _pinataPlaysToday,
                              pinataDailyLimit: pinataLimit,
                              canPlayPinata: canPlayPinata,
                              onPlayPinata: _openPinataGame,
                              clawPlaysToday: _clawPlaysToday,
                              clawDailyLimit: clawLimit,
                              canPlayClaw: canPlayClaw,
                              onPlayClaw: _openClawMachineGame,
                              stackPlaysToday: _stackPlaysToday,
                              stackDailyLimit: stackLimit,
                              canPlayStack: canPlayStack,
                              onPlayStack: _openStackGame,
                              dodgePlaysToday: _dodgePlaysToday,
                              dodgeDailyLimit: dodgeLimit,
                              canPlayDodge: canPlayDodge,
                              onPlayDodge: _openDodgeGame,
                              superSaltoPlaysToday: _superSaltoPlaysToday,
                              superSaltoDailyLimit: superSaltoLimit,
                              canPlaySuperSalto: canPlaySuperSalto,
                              onPlaySuperSalto: _openSuperSaltoGame,
                            ),
                            const SizedBox(height: 16),

                            // ── 4. Mini-juego cajas ──────────────────────
                            PointsMiniGameCard(
                              prizePreview: prizePreview,
                              showPreviewValues: _showBoxesPreviewValues,
                              isPreparingBoxes: _isPreparingBoxes,
                              boxesRoundReady: _boxesRoundReady,
                              shuffleSeed: _boxesShuffleSeed,
                              playsToday: _boxesPlaysToday,
                              dailyLimit: boxesLimit,
                              canPlay: canPlayBoxes,
                              isPlayingMiniGame: _isPlayingMiniGame,
                              lastBoxesReward: _lastBoxesReward,
                              onPlayRandom: _startBoxesRound,
                              onPlayBox: _playBoxMiniGame,
                            ),
                            const SizedBox(height: 16),

                            // ── 5. Historial ─────────────────────────────
                            _MovementsSection(movements: _movements),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

// ─── BALANCE HERO CARD ────────────────────────────────────────────────────────

class _BalanceHeroCard extends StatelessWidget {
  final int currentBalance;
  final String hundredCoinsValue;
  final int currentStreak;

  const _BalanceHeroCard({
    required this.currentBalance,
    required this.hundredCoinsValue,
    required this.currentStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_DS.radiusXl),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF1E3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.4),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20,
            top: -20,
            child: _DecorCircle(size: 110, opacity: 0.06),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: _DecorCircle(size: 80, opacity: 0.05),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label + wallet icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saldo de monedas',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Big balance number
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currentBalance',
                    style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                      letterSpacing: -2,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8, left: 8),
                    child: Text(
                      'monedas',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Info chips row
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.toll_rounded,
                    label: '100 = S/ $hundredCoinsValue',
                    color: _DS.goldMid,
                  ),
                  const SizedBox(width: 8),
                  if (currentStreak > 0)
                    _InfoChip(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Racha: $currentStreak días',
                      color: const Color(0xFFF97316),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _DecorCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DAILY CHECK-IN CARD ─────────────────────────────────────────────────────

class PointsDailyCheckinCard extends StatelessWidget {
  final String hundredCoinsValue;
  final String claimMessage;
  final String streakPreviewLabel;
  final int currentStreak;
  final int nextCheckinReward;
  final bool hasTodayCheckin;
  final bool isClaimingCheckin;
  final VoidCallback onClaim;

  const PointsDailyCheckinCard({
    super.key,
    required this.hundredCoinsValue,
    required this.claimMessage,
    required this.streakPreviewLabel,
    required this.currentStreak,
    required this.nextCheckinReward,
    required this.hasTodayCheckin,
    required this.isClaimingCheckin,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(_DS.radiusXl),
        border: Border.all(
          color: hasTodayCheckin ? _DS.successLight : _DS.goldLight,
          width: 1.5,
        ),
        boxShadow: _DS.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hasTodayCheckin ? _DS.successLight : _DS.goldLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasTodayCheckin
                          ? Icons.check_circle_rounded
                          : Icons.calendar_today_rounded,
                      size: 18,
                      color: hasTodayCheckin ? _DS.success : _DS.gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Racha diaria',
                    style: TextStyle(
                      color: _DS.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              _StatusPill(
                label: hasTodayCheckin ? 'Completado' : 'Disponible',
                color: hasTodayCheckin ? _DS.success : _DS.gold,
                bgColor: hasTodayCheckin ? _DS.successLight : _DS.goldLight,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reward + message
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hasTodayCheckin ? _DS.successLight : _DS.goldLight,
              borderRadius: BorderRadius.circular(_DS.radius),
            ),
            child: Row(
              children: [
                // Reward bubble
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: hasTodayCheckin ? _DS.success : _DS.gold,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.toll_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+$nextCheckinReward',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        streakPreviewLabel,
                        style: TextStyle(
                          color: hasTodayCheckin ? _DS.tealDark : _DS.goldDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        claimMessage,
                        style: TextStyle(
                          color: hasTodayCheckin ? _DS.success : _DS.gold,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Streak row
          if (currentStreak > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFF97316),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Llevas $currentStreak días seguidos reclamando.',
                    style: const TextStyle(
                      color: Color(0xFF9A3412),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Claim button
          GestureDetector(
            onTap: hasTodayCheckin || isClaimingCheckin ? null : onClaim,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient:
                    !hasTodayCheckin
                        ? const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                        : null,
                color: hasTodayCheckin ? const Color(0xFFF1F5F9) : null,
                borderRadius: BorderRadius.circular(_DS.radius),
                boxShadow:
                    hasTodayCheckin
                        ? null
                        : [
                          BoxShadow(
                            color: _DS.gold.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isClaimingCheckin)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  else
                    Icon(
                      hasTodayCheckin
                          ? Icons.check_circle_outline
                          : Icons.touch_app_rounded,
                      color: hasTodayCheckin ? _DS.textMuted : Colors.white,
                      size: 18,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    isClaimingCheckin
                        ? 'Reclamando…'
                        : hasTodayCheckin
                        ? 'Ya reclamado hoy'
                        : 'Reclamar monedas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: hasTodayCheckin ? _DS.textMuted : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── GAME ACTIONS SECTION ─────────────────────────────────────────────────────

class PointsGameActionsSection extends StatelessWidget {
  final int playsToday;
  final int dailyLimit;
  final bool canPlay;
  final Future<void> Function() onPlayMemorama;
  final int catcherPlaysToday;
  final int catcherDailyLimit;
  final bool canPlayCatcher;
  final Future<void> Function() onPlayCoinCatcher;
  final int pinataPlaysToday;
  final int pinataDailyLimit;
  final bool canPlayPinata;
  final Future<void> Function() onPlayPinata;
  final int clawPlaysToday;
  final int clawDailyLimit;
  final bool canPlayClaw;
  final Future<void> Function() onPlayClaw;
  final int stackPlaysToday;
  final int stackDailyLimit;
  final bool canPlayStack;
  final Future<void> Function() onPlayStack;
  final int dodgePlaysToday;
  final int dodgeDailyLimit;
  final bool canPlayDodge;
  final Future<void> Function() onPlayDodge;
  final int superSaltoPlaysToday;
  final int superSaltoDailyLimit;
  final bool canPlaySuperSalto;
  final Future<void> Function() onPlaySuperSalto;

  const PointsGameActionsSection({
    super.key,
    required this.playsToday,
    required this.dailyLimit,
    required this.canPlay,
    required this.onPlayMemorama,
    required this.catcherPlaysToday,
    required this.catcherDailyLimit,
    required this.canPlayCatcher,
    required this.onPlayCoinCatcher,
    required this.pinataPlaysToday,
    required this.pinataDailyLimit,
    required this.canPlayPinata,
    required this.onPlayPinata,
    required this.clawPlaysToday,
    required this.clawDailyLimit,
    required this.canPlayClaw,
    required this.onPlayClaw,
    required this.stackPlaysToday,
    required this.stackDailyLimit,
    required this.canPlayStack,
    required this.onPlayStack,
    required this.dodgePlaysToday,
    required this.dodgeDailyLimit,
    required this.canPlayDodge,
    required this.onPlayDodge,
    required this.superSaltoPlaysToday,
    required this.superSaltoDailyLimit,
    required this.canPlaySuperSalto,
    required this.onPlaySuperSalto,
  });

  Widget _buildGameTile({
    required String title,
    required String emoji,
    required int plays,
    required int limit,
    required Color color,
    required VoidCallback? onPlay,
  }) {
    final active = plays < limit;
    return _GameTile(
      title: title,
      emoji: emoji,
      plays: plays,
      limit: limit,
      color: color,
      active: active,
      onPlay: onPlay,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(_DS.radiusXl),
        boxShadow: _DS.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Juegos Diarios',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _DS.textPrimary,
                      ),
                    ),
                    Text(
                      'Diviértete y gana monedas extra',
                      style: TextStyle(fontSize: 11, color: _DS.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Game tiles grid  (2 columns)
          _buildGameTile(
            title: 'Memorama',
            emoji: '🧠',
            plays: playsToday,
            limit: dailyLimit,
            color: _DS.teal,
            onPlay: canPlay ? onPlayMemorama : null,
          ),
          _buildGameTile(
            title: 'Lluvia de Monedas',
            emoji: '🪙',
            plays: catcherPlaysToday,
            limit: catcherDailyLimit,
            color: const Color(0xFFE5A93C),
            onPlay: canPlayCatcher ? onPlayCoinCatcher : null,
          ),
          _buildGameTile(
            title: 'Piñata',
            emoji: '🎉',
            plays: pinataPlaysToday,
            limit: pinataDailyLimit,
            color: const Color(0xFFE05C41),
            onPlay: canPlayPinata ? onPlayPinata : null,
          ),
          _buildGameTile(
            title: 'Máquina de Garra',
            emoji: '🦾',
            plays: clawPlaysToday,
            limit: clawDailyLimit,
            color: const Color(0xFFB26CFF),
            onPlay: canPlayClaw ? onPlayClaw : null,
          ),
          _buildGameTile(
            title: 'Torre de Cajas',
            emoji: '📦',
            plays: stackPlaysToday,
            limit: stackDailyLimit,
            color: const Color(0xFF4E79FF),
            onPlay: canPlayStack ? onPlayStack : null,
          ),
          _buildGameTile(
            title: 'Esquiva y Atrapa',
            emoji: '⚡',
            plays: dodgePlaysToday,
            limit: dodgeDailyLimit,
            color: const Color(0xFF3E7DD1),
            onPlay: canPlayDodge ? onPlayDodge : null,
          ),
          _buildGameTile(
            title: 'Super Salto',
            emoji: '🚀',
            plays: superSaltoPlaysToday,
            limit: superSaltoDailyLimit,
            color: const Color(0xFF6A5AE0),
            onPlay: canPlaySuperSalto ? onPlaySuperSalto : null,
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final String title;
  final String emoji;
  final int plays;
  final int limit;
  final Color color;
  final bool active;
  final VoidCallback? onPlay;

  const _GameTile({
    required this.title,
    required this.emoji,
    required this.plays,
    required this.limit,
    required this.color,
    required this.active,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(_DS.radius),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.2) : _DS.border,
        ),
      ),
      child: Row(
        children: [
          // Emoji icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  active
                      ? color.withValues(alpha: 0.12)
                      : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),

          // Title + attempts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: active ? _DS.textPrimary : _DS.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: limit == 0 ? 0 : plays / limit,
                    backgroundColor: _DS.border,
                    color: active ? color : _DS.textMuted,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$plays / $limit juego${limit != 1 ? "s" : ""} hoy',
                  style: TextStyle(
                    fontSize: 10,
                    color: active ? color : _DS.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Play button
          GestureDetector(
            onTap: onPlay,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: active ? color : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                active ? 'Jugar' : 'Listo',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: active ? Colors.white : _DS.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MINI-GAME (CAJAS) CARD ──────────────────────────────────────────────────

class PointsMiniGameCard extends StatelessWidget {
  final List<int> prizePreview;
  final bool showPreviewValues;
  final bool isPreparingBoxes;
  final bool boxesRoundReady;
  final int shuffleSeed;
  final int playsToday;
  final int dailyLimit;
  final bool canPlay;
  final bool isPlayingMiniGame;
  final int? lastBoxesReward;
  final VoidCallback onPlayRandom;
  final void Function(int) onPlayBox;

  const PointsMiniGameCard({
    super.key,
    required this.prizePreview,
    required this.showPreviewValues,
    required this.isPreparingBoxes,
    required this.boxesRoundReady,
    required this.shuffleSeed,
    required this.playsToday,
    required this.dailyLimit,
    required this.canPlay,
    required this.isPlayingMiniGame,
    required this.lastBoxesReward,
    required this.onPlayRandom,
    required this.onPlayBox,
  });

  @override
  Widget build(BuildContext context) {
    final phase =
        !canPlay
            ? 'done'
            : isPreparingBoxes
            ? 'reveal'
            : boxesRoundReady
            ? 'pick'
            : 'idle';

    final phaseLabel =
        {
          'done': 'Ya completaste el juego de hoy',
          'reveal': 'Mira los premios, luego se mezclarán…',
          'pick': '¡Elige una caja ahora!',
          'idle': 'Toca "Revelar cajas" para comenzar',
        }[phase]!;

    final (headerBg, headerIcon, headerIconColor) =
        phase == 'done'
            ? (const Color(0xFFF1F5F9), Icons.lock_rounded, _DS.textMuted)
            : phase == 'pick'
            ? (_DS.goldLight, Icons.card_giftcard_rounded, _DS.gold)
            : (_DS.tealLight, Icons.extension_rounded, _DS.teal);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(_DS.radiusXl),
        boxShadow: _DS.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(headerIcon, color: headerIconColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jueguito de cajas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _DS.textPrimary,
                      ),
                    ),
                    Text(
                      'Elige la caja con el mejor premio',
                      style: TextStyle(fontSize: 11, color: _DS.textMuted),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: '$playsToday/$dailyLimit',
                color: canPlay ? _DS.teal : _DS.textMuted,
                bgColor: canPlay ? _DS.tealLight : const Color(0xFFF1F5F9),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Phase label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  phase == 'pick'
                      ? _DS.goldLight
                      : phase == 'done'
                      ? const Color(0xFFF1F5F9)
                      : _DS.tealLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  phase == 'pick'
                      ? Icons.touch_app_rounded
                      : phase == 'done'
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 14,
                  color:
                      phase == 'pick'
                          ? _DS.goldDark
                          : phase == 'done'
                          ? _DS.textMuted
                          : _DS.teal,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    phaseLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          phase == 'pick'
                              ? _DS.goldDark
                              : phase == 'done'
                              ? _DS.textMuted
                              : _DS.tealDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Box row
          Row(
            children: List.generate(prizePreview.length, (index) {
              final reward = prizePreview[index];
              final locked = !canPlay || isPlayingMiniGame || !boxesRoundReady;
              final wobble =
                  isPreparingBoxes
                      ? ((shuffleSeed + index) % 3 - 1) * 0.04
                      : 0.0;
              final vertShift =
                  isPreparingBoxes
                      ? ((shuffleSeed + index * 2) % 3 - 1) * 5.0
                      : 0.0;
              final isWinner = !canPlay && lastBoxesReward == reward;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                  child: GestureDetector(
                    onTap: locked ? null : () => onPlayBox(index),
                    child: Transform.translate(
                      offset: Offset(0, vertShift),
                      child: Transform.rotate(
                        angle: wobble,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: 108,
                          decoration: BoxDecoration(
                            gradient:
                                locked
                                    ? const LinearGradient(
                                      colors: [
                                        Color(0xFFF1F5F9),
                                        Color(0xFFE2E8F0),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                    : const LinearGradient(
                                      colors: [
                                        Color(0xFFFFE7B3),
                                        Color(0xFFFFC85C),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isWinner ? _DS.gold : Colors.white,
                              width: isWinner ? 2.5 : 2,
                            ),
                            boxShadow:
                                locked
                                    ? null
                                    : [
                                      BoxShadow(
                                        color: _DS.gold.withValues(alpha: 0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                showPreviewValues
                                    ? '🎁'
                                    : locked
                                    ? '🔒'
                                    : '📦',
                                style: const TextStyle(fontSize: 26),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                showPreviewValues
                                    ? '+$reward'
                                    : locked
                                    ? (canPlay ? 'Caja ${index + 1}' : '—')
                                    : 'Caja ${index + 1}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      locked
                                          ? _DS.textMuted
                                          : const Color(0xFF7A4500),
                                  fontWeight: FontWeight.w900,
                                  fontSize: showPreviewValues ? 14 : 12,
                                ),
                              ),
                              if (!locked)
                                const Text(
                                  'Toca',
                                  style: TextStyle(
                                    color: Color(0xFF7A4500),
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Action button
          GestureDetector(
            onTap: canPlay && !isPlayingMiniGame ? onPlayRandom : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient:
                    canPlay
                        ? const LinearGradient(
                          colors: [_DS.teal, _DS.tealDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                        : null,
                color: canPlay ? null : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(_DS.radius),
                boxShadow:
                    canPlay
                        ? [
                          BoxShadow(
                            color: _DS.teal.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                        : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isPlayingMiniGame)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  else
                    Text(
                      canPlay ? '🎲' : '✅',
                      style: const TextStyle(fontSize: 16),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    canPlay ? 'Revelar cajas' : 'Completado por hoy',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: canPlay ? Colors.white : _DS.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MOVEMENTS SECTION ────────────────────────────────────────────────────────

class _MovementsSection extends StatelessWidget {
  final List<Map<String, dynamic>> movements;
  const _MovementsSection({required this.movements});

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _DS.surface,
          borderRadius: BorderRadius.circular(_DS.radiusXl),
          boxShadow: _DS.cardShadow(),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 28,
                color: _DS.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin movimientos',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _DS.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tu historial de monedas aparecerá aquí',
              style: TextStyle(fontSize: 12, color: _DS.textSecondary),
            ),
          ],
        ),
      );
    }

    final visible = movements.length > 10 ? 10 : movements.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(_DS.radiusXl),
        boxShadow: _DS.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _DS.goldLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: _DS.gold,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Historial de movimientos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _DS.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _DS.goldLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${movements.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _DS.goldDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...List.generate(
            visible,
            (i) => _MovementRow(movement: movements[i]),
          ),

          if (movements.length > 10) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _DS.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _DS.border),
              ),
              child: Center(
                child: Text(
                  'Ver ${movements.length - 10} movimientos más',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  final Map<String, dynamic> movement;
  const _MovementRow({required this.movement});

  static const Map<String, (String, Color, Color)> _typeMap = {
    'DAILY_CHECKIN': ('📅', Color(0xFF10B981), Color(0xFFD1FAE5)),
    'MINI_GAME_BOXES': ('📦', Color(0xFFF59E0B), Color(0xFFFEF3C7)),
    'MINI_GAME_MEMORY': ('🧠', Color(0xFF0D9488), Color(0xFFCCFBF1)),
    'MINI_GAME_CATCHER': ('🪙', Color(0xFFE5A93C), Color(0xFFFEF3C7)),
    'MINI_GAME_PINATA': ('🎉', Color(0xFFE05C41), Color(0xFFFFE4E6)),
    'MINI_GAME_JUMP': ('🚀', Color(0xFF6A5AE0), Color(0xFFEDE9FE)),
    'MINI_GAME_CLAW': ('🦾', Color(0xFFB26CFF), Color(0xFFF3E8FF)),
    'MINI_GAME_STACK': ('📦', Color(0xFF4E79FF), Color(0xFFEFF6FF)),
    'MINI_GAME_DODGE': ('⚡', Color(0xFF3E7DD1), Color(0xFFEFF6FF)),
    'REDEMPTION': ('🛍', Color(0xFFEF4444), Color(0xFFFFE4E6)),
    'EARN': ('⭐', Color(0xFF10B981), Color(0xFFD1FAE5)),
  };

  @override
  Widget build(BuildContext context) {
    final description = movement['description'] as String? ?? 'Movimiento';
    final points = movement['points'] as num?;
    final type = movement['movement_type'] as String? ?? '';
    final isPositive = (points ?? 0) >= 0;

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(movement['created_at'].toString()).toLocal();
    } catch (_) {}

    final (emoji, badgeColor, badgeBg) =
        _typeMap[type] ??
        (isPositive
            ? ('⬆', _DS.success, _DS.successLight)
            : ('⬇', _DS.danger, _DS.dangerLight));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _DS.bg,
        borderRadius: BorderRadius.circular(_DS.radius),
        border: Border.all(color: _DS.border),
      ),
      child: Row(
        children: [
          // Emoji icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),

          // Description + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _DS.textPrimary,
                  ),
                ),
                if (parsedDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMM · HH:mm').format(parsedDate),
                    style: const TextStyle(fontSize: 10, color: _DS.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Points badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${isPositive ? "+" : ""}${points?.toInt() ?? 0}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SHARED HELPER WIDGETS ────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  const _StatusPill({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
    ),
  );
}

// ─── LEGACY WIDGETS (kept for compatibility) ──────────────────────────────────

class PointsHeroSection extends StatelessWidget {
  final int currentBalance;
  final String hundredCoinsValue;
  const PointsHeroSection({
    super.key,
    required this.currentBalance,
    required this.hundredCoinsValue,
  });

  @override
  Widget build(BuildContext context) => _BalanceHeroCard(
    currentBalance: currentBalance,
    hundredCoinsValue: hundredCoinsValue,
    currentStreak: 0,
  );
}

class PointsBalanceCard extends StatelessWidget {
  final int currentBalance;
  final String hundredCoinsValue;
  const PointsBalanceCard({
    super.key,
    required this.currentBalance,
    required this.hundredCoinsValue,
  });

  @override
  Widget build(BuildContext context) => _BalanceHeroCard(
    currentBalance: currentBalance,
    hundredCoinsValue: hundredCoinsValue,
    currentStreak: 0,
  );
}

class PointsMovementSection extends StatelessWidget {
  final List<Map<String, dynamic>> movements;
  const PointsMovementSection({super.key, required this.movements});

  @override
  Widget build(BuildContext context) => _MovementsSection(movements: movements);
}
