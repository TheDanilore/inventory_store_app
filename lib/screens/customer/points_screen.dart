import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/customer/points_provider.dart';
import 'package:inventory_store_app/screens/customer/widgets/points/points_balance_hero_card.dart';
import 'package:inventory_store_app/screens/customer/widgets/points/points_daily_checkin_card.dart';
import 'package:inventory_store_app/screens/customer/widgets/points/points_design_tokens.dart';
import 'package:inventory_store_app/screens/customer/widgets/points/points_game_actions_section.dart';
import 'package:inventory_store_app/screens/customer/widgets/points/points_mini_game_card.dart';
import 'package:inventory_store_app/screens/customer/widgets/points/points_movements_section.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/customer_layout.dart';
import 'package:provider/provider.dart';

class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
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

  @override
  Widget build(BuildContext context) {
    return CustomerLayout(
      title: 'Mis Monedas',
      showBackButton: true,
      showBottomNav: false,
      showCartIcon: true,
      showWalletChip: true,
      body: Consumer<PointsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            );
          }

          final config = context.watch<AppConfigProvider>();
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
            child: RefreshIndicator(
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
                      currentBalance: provider.currentBalance,
                      hundredCoinsValue: hundredCoinsValue,
                      currentStreak: provider.currentStreak,
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),

                          // 2. Check-in diario
                          PointsDailyCheckinCard(
                            hundredCoinsValue: hundredCoinsValue,
                            claimMessage: claimMessage,
                            streakPreviewLabel: streakPreviewLabel,
                            currentStreak: provider.currentStreak,
                            nextCheckinReward: provider.nextCheckinReward,
                            hasTodayCheckin: provider.hasTodayCheckin,
                            isClaimingCheckin: provider.isClaimingCheckin,
                            onClaim: () => provider.claimDailyCheckin(),
                          ),
                          const SizedBox(height: 16),

                          // 3. Juegos diarios
                          const PointsGameActionsSection(),
                          const SizedBox(height: 16),

                          // 4. Mini-juego cajas
                          const PointsMiniGameCard(),
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
          );
        },
      ),
    );
  }
}
