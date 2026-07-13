import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/points_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/points_state.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/points/points_balance_hero_card.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/points/flying_coin_overlay.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/points/points_daily_checkin_card.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/points/points_design_tokens.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/points/points_game_actions_section.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/points/points_mini_game_card.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/points/points_movements_section.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

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
    final config = context.read<AppConfigCubit>();
    await context.read<PointsCubit>().fetchPointsData(config);
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

  void _handleClaim(PointsState state) {
    if (state.hasTodayCheckin || state.isClaimingCheckin) return;
    _playCoinFlyAnimation(_claimButtonKey);
    context.read<PointsCubit>().claimDailyCheckin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PointsDS.bg,
      body: BlocBuilder<PointsCubit, PointsState>(
        builder: (context, state) {
          final config = context.watch<AppConfigCubit>();

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
                      'El sistema de recompensas no está activo en este momento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state.errorMessage != null && state.currentBalance == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.15),
                              PointsDS.bg,
                            ],
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          const SizedBox(height: 20),
                          Builder(builder: (context) {
                            final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
                            final hundredCoinsValue = (100 * pointsToSolesRatio).toStringAsFixed(2);
                            return PointsBalanceHeroCard(
                              balanceKey: _balanceKey,
                              currentBalance: state.currentBalance,
                              hundredCoinsValue: hundredCoinsValue,
                              currentStreak: state.currentStreak,
                            );
                          }),
                          const SizedBox(height: 20),
                          Builder(builder: (context) {
                            final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
                            final hundredCoinsValue = (100 * pointsToSolesRatio).toStringAsFixed(2);
                            return PointsDailyCheckinCard(
                              claimButtonKey: _claimButtonKey,
                              currentStreak: state.currentStreak,
                              hasTodayCheckin: state.hasTodayCheckin,
                              nextCheckinReward: state.nextCheckinReward,
                              isClaimingCheckin: state.isClaimingCheckin,
                              hundredCoinsValue: hundredCoinsValue,
                              claimMessage: 'Reclama tu bono diario de puntos',
                              streakPreviewLabel: 'Días seguidos: ${state.currentStreak}',
                              onClaim: () => _handleClaim(state),
                            );
                          }),
                          const SizedBox(height: 24),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: PointsMiniGameCard(),
                          ),
                          const SizedBox(height: 24),
                          const PointsGameActionsSection(),
                          const SizedBox(height: 24),
                          const PointsMovementsSection(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

