import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/providers/app_config_provider.dart';
import 'package:inventory_store_app/features/loyalty/presentation/providers/points_provider.dart';
import 'package:inventory_store_app/features/loyalty/presentation/providers/wallet_provider.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/widgets/points/points_balance_hero_card.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/widgets/points/flying_coin_overlay.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/widgets/points/points_daily_checkin_card.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/widgets/points/points_design_tokens.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/widgets/points/points_game_actions_section.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/widgets/points/points_mini_game_card.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/widgets/points/points_movements_section.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/customer_layout.dart';
import 'package:provider/provider.dart';

class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  final GlobalKey _balanceKey = GlobalKey();
  final GlobalKey _claimButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final config = context.read<AppConfigProvider>();
    await context.read<PointsProvider>().fetchPointsData(config);
  }

  void _playCoinFlyAnimation(GlobalKey startKey) {
    final startBox = startKey.currentContext?.findRenderObject() as RenderBox?;
    final balanceBox =
        _balanceKey.currentContext?.findRenderObject() as RenderBox?;

    if (startBox != null && balanceBox != null) {
      final startOffset = startBox.localToGlobal(
        startBox.size.center(Offset.zero),
      );
      final endOffset = balanceBox.localToGlobal(
        balanceBox.size.center(Offset.zero),
      );

      OverlayEntry? entry;
      entry = OverlayEntry(
        builder:
            (context) => FlyingCoinOverlay(
              startOffset: startOffset,
              endOffset: endOffset,
              onComplete: () {
                entry?.remove();
              },
            ),
      );
      Overlay.of(context).insert(entry);
    }
  }

  void _handleClaim(PointsProvider provider) {
    if (provider.hasTodayCheckin || provider.isClaimingCheckin) return;
    _playCoinFlyAnimation(_claimButtonKey);
    provider.claimDailyCheckin(context.read<WalletProvider>());
  }

  @override
  Widget build(BuildContext context) {
    return CustomerLayout(
      title: 'Mis Monedas',
      showBackButton: true,
      showBottomNav: false,
      showCartIcon: true,
      showWalletChip: false,
      body: Consumer<PointsProvider>(
        builder: (context, provider, child) {
          final config = context.watch<AppConfigProvider>();

          if (!config.loyaltyGlobalEnabled || !config.loyaltyCustomerVisible) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Sistema No Disponible',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'El sistema de monedas se encuentra desactivado en este momento. Vuelve más tarde.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final pointsToSolesRatio = config.getDouble(
            'points_to_soles_ratio',
            0.01,
          );
          final hundredCoinsValue = (100 * pointsToSolesRatio).toStringAsFixed(
            2,
          );

          final claimMessage =
              provider.hasTodayCheckin
                  ? 'Hoy ya reclamaste tus monedas. Vuelve mañana para seguir la racha.'
                  : 'Reclama tus monedas de hoy con un toque y mantén activa tu racha.';

          final d1 = provider.rewardForStreakDay(1);
          final d2 = provider.rewardForStreakDay(2);
          final streakPreviewLabel =
              'Día 1: $d1 monedas. Día 2: $d2 monedas. Sigue la racha para ganar más.';

          return SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child:
                  provider.isLoading
                      ? const Center(
                        key: ValueKey('loading'),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2.5,
                        ),
                      )
                      : RefreshIndicator(
                        key: const ValueKey('content'),
                        color: AppColors.primary,
                        backgroundColor: PointsDS.surface,
                        onRefresh: _loadData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Hero balance card
                              PointsBalanceHeroCard(
                                balanceKey: _balanceKey,
                                currentBalance: provider.currentBalance,
                                hundredCoinsValue: hundredCoinsValue,
                                currentStreak: provider.currentStreak,
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 16),

                                    // 2. Check-in diario
                                    PointsDailyCheckinCard(
                                      claimButtonKey: _claimButtonKey,
                                      hundredCoinsValue: hundredCoinsValue,
                                      claimMessage: claimMessage,
                                      streakPreviewLabel: streakPreviewLabel,
                                      currentStreak: provider.currentStreak,
                                      nextCheckinReward:
                                          provider.nextCheckinReward,
                                      hasTodayCheckin: provider.hasTodayCheckin,
                                      isClaimingCheckin:
                                          provider.isClaimingCheckin,
                                      onClaim: () => _handleClaim(provider),
                                    ),
                                    const SizedBox(height: 16),

                                    // 3. Juegos diarios
                                    const PointsGameActionsSection(),
                                    const SizedBox(height: 16),

                                    // 4. Mini-juego cajas
                                    PointsMiniGameCard(
                                      onCoinFly: _playCoinFlyAnimation,
                                    ),
                                    const SizedBox(height: 16),

                                    // 5. Historial
                                    const PointsMovementsSection(),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
            ),
          );
        },
      ),
    );
  }
}
