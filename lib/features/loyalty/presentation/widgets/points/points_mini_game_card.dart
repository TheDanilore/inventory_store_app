import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/points_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/points_state.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/points/points_design_tokens.dart';

class PointsMiniGameCard extends StatefulWidget {
  final void Function(GlobalKey startKey)? onCoinFly;

  const PointsMiniGameCard({super.key, this.onCoinFly});

  @override
  State<PointsMiniGameCard> createState() => _PointsMiniGameCardState();
}

class _PointsMiniGameCardState extends State<PointsMiniGameCard> {
  final List<GlobalKey> _boxKeys = List.generate(3, (_) => GlobalKey());

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PointsCubit, PointsState>(
      builder: (context, state) {
        final config = context.watch<AppConfigCubit>();

        final dailyLimit = config.getDouble('boxes_daily_limit', 1).round();
        final canPlay = state.boxesPlaysToday < dailyLimit;

        final phase =
            state.isPreparingBoxes
                ? 'reveal'
                : state.boxesRoundReady
                ? 'pick'
                : 'idle';

        final phaseLabel =
            {
              'reveal': 'Mira los premios, luego se mezclarán...',
              'pick': '¡Elige una caja ahora!',
              'idle':
                  canPlay
                      ? 'Toca "Revelar cajas" para comenzar'
                      : 'Límite alcanzado. ¡Juega por diversión!',
            }[phase]!;

        final headerBg =
            phase == 'pick' ? PointsDS.goldLight : PointsDS.tealLight;

        final headerIcon =
            phase == 'pick'
                ? Icons.card_giftcard_rounded
                : Icons.extension_rounded;
        final headerIconColor = phase == 'pick' ? PointsDS.gold : PointsDS.teal;

        final prizePreview =
            state.boxesRoundReady && state.miniGameBoxes.isNotEmpty
                ? state.miniGameBoxes
                : (state.miniGamePreviewBoxes.isNotEmpty
                    ? state.miniGamePreviewBoxes
                    : state.miniGameBoxes);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: PointsDS.surface,
            borderRadius: BorderRadius.circular(PointsDS.radiusXl),
            boxShadow: PointsDS.cardShadow(),
          ),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: headerBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          headerIcon,
                          size: 18,
                          color: headerIconColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Cajas Misteriosas',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: PointsDS.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (canPlay)
                    _StatusPill(
                      label:
                          '${dailyLimit - state.boxesPlaysToday} disponible(s)',
                      color: PointsDS.tealDark,
                      bgColor: PointsDS.tealLight,
                    )
                  else
                    const _StatusPill(
                      label: 'Por diversión',
                      color: PointsDS.textSecondary,
                      bgColor: PointsDS.bg,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Phase Label
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      phase == 'idle'
                          ? PointsDS.bg
                          : (phase == 'pick'
                              ? PointsDS.goldLight.withValues(alpha: 0.5)
                              : PointsDS.tealLight.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      phase == 'idle'
                          ? Icons.info_outline_rounded
                          : (phase == 'pick'
                              ? Icons.touch_app_rounded
                              : Icons.visibility_rounded),
                      size: 16,
                      color:
                          phase == 'idle'
                              ? PointsDS.textSecondary
                              : (phase == 'pick'
                                  ? PointsDS.goldDark
                                  : PointsDS.tealDark),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        phaseLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              phase == 'idle'
                                  ? PointsDS.textMuted
                                  : PointsDS.tealDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Box row
              if (prizePreview.isNotEmpty)
                Row(
                  children: List.generate(prizePreview.length, (index) {
                    final reward = prizePreview[index];
                    final locked =
                        state.isPlayingMiniGame || !state.boxesRoundReady;
                    final wobble =
                        state.isPreparingBoxes
                            ? ((state.boxesShuffleSeed + index) % 3 - 1) * 0.04
                            : 0.0;
                    final vertShift =
                        state.isPreparingBoxes
                            ? ((state.boxesShuffleSeed + index * 2) % 3 - 1) *
                                5.0
                            : 0.0;
                    final isWinner =
                        phase == 'idle' &&
                        state.lastBoxesReward == reward &&
                        state.lastBoxesReward != null;

                    return Expanded(
                      key: _boxKeys[index],
                      child: Padding(
                        padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                        child: GestureDetector(
                          onTap:
                              locked
                                  ? null
                                  : () async {
                                    final wasForFun =
                                        !canPlay || state.profileId == null;
                                    final picked = await context
                                        .read<PointsCubit>()
                                        .playBoxMiniGame(index, config);
                                    if (picked != null) {
                                      if (wasForFun) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '¡Sacaste $picked monedas! (Modo diversión)',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              backgroundColor: PointsDS.teal,
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        if (widget.onCoinFly != null) {
                                          widget.onCoinFly!(_boxKeys[index]);
                                        }
                                      }
                                    }
                                  },
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
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        isWinner
                                            ? PointsDS.success
                                            : (locked
                                                ? PointsDS.border
                                                : PointsDS.gold),
                                    width: isWinner ? 3 : 1,
                                  ),
                                  boxShadow:
                                      locked
                                          ? []
                                          : [
                                            BoxShadow(
                                              color: PointsDS.gold.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                ),
                                child: Stack(
                                  children: [
                                    if (isWinner)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: PointsDS.success,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    Center(
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        transitionBuilder:
                                            (w, anim) => ScaleTransition(
                                              scale: anim,
                                              child: w,
                                            ),
                                        child:
                                            (state.showBoxesPreviewValues ||
                                                    (locked && phase == 'idle'))
                                                ? Column(
                                                  key: const ValueKey('value'),
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      '+$reward',
                                                      style: TextStyle(
                                                        color:
                                                            locked
                                                                ? PointsDS
                                                                    .textSecondary
                                                                : PointsDS
                                                                    .goldDark,
                                                        fontSize: 22,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        height: 1,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Icon(
                                                      Icons
                                                          .monetization_on_rounded,
                                                      size: 14,
                                                      color:
                                                          locked
                                                              ? PointsDS
                                                                  .textMuted
                                                              : PointsDS.gold,
                                                    ),
                                                  ],
                                                )
                                                : Icon(
                                                  Icons.help_center_rounded,
                                                  key: const ValueKey('box'),
                                                  size: 42,
                                                  color:
                                                      locked
                                                          ? PointsDS.textMuted
                                                          : PointsDS.goldDark
                                                              .withValues(
                                                                alpha: 0.7,
                                                              ),
                                                ),
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

              // Primary button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      (phase == 'idle' && !state.isPlayingMiniGame)
                          ? () => context.read<PointsCubit>().startBoxesRound(
                            config,
                          )
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PointsDS.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      state.isPlayingMiniGame
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'Revelar Cajas',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
