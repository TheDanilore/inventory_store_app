import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/customer/points_provider.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart';
import 'package:inventory_store_app/screens/customer/widgets/points/points_design_tokens.dart';
import 'package:provider/provider.dart';

class PointsMiniGameCard extends StatelessWidget {
  const PointsMiniGameCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PointsProvider>();
    final config = context.watch<AppConfigProvider>();

    final dailyLimit = config.getDouble('boxes_daily_limit', 1).round();
    final canPlay = provider.boxesPlaysToday < dailyLimit;

    final phase =
        !canPlay
            ? 'done'
            : provider.isPreparingBoxes
            ? 'reveal'
            : provider.boxesRoundReady
            ? 'pick'
            : 'idle';

    final phaseLabel =
        {
          'done': 'Ya completaste el juego de hoy',
          'reveal': 'Mira los premios, luego se mezclarán...',
          'pick': '¡Elige una caja ahora!',
          'idle': 'Toca "Revelar cajas" para comenzar',
        }[phase]!;

    final headerBg =
        phase == 'done'
            ? const Color(0xFFF1F5F9)
            : phase == 'pick'
            ? PointsDS.goldLight
            : PointsDS.tealLight;

    final headerIcon =
        phase == 'done'
            ? Icons.lock_rounded
            : phase == 'pick'
            ? Icons.card_giftcard_rounded
            : Icons.extension_rounded;
    final headerIconColor =
        phase == 'done'
            ? PointsDS.textMuted
            : phase == 'pick'
            ? PointsDS.gold
            : PointsDS.teal;

    final prizePreview =
        provider.boxesRoundReady && provider.miniGameBoxes.isNotEmpty
            ? provider.miniGameBoxes
            : (provider.miniGamePreviewBoxes.isNotEmpty
                ? provider.miniGamePreviewBoxes
                : provider.miniGameBoxes);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PointsDS.surface,
        borderRadius: BorderRadius.circular(PointsDS.radiusXl),
        boxShadow: PointsDS.cardShadow(),
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
                        color: PointsDS.textPrimary,
                      ),
                    ),
                    Text(
                      'Elige la caja con el mejor premio',
                      style: TextStyle(fontSize: 11, color: PointsDS.textMuted),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: '${provider.boxesPlaysToday}/$dailyLimit',
                color: canPlay ? PointsDS.teal : PointsDS.textMuted,
                bgColor: canPlay ? PointsDS.tealLight : const Color(0xFFF1F5F9),
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
                      ? PointsDS.goldLight
                      : phase == 'done'
                      ? const Color(0xFFF1F5F9)
                      : PointsDS.tealLight,
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
                          ? PointsDS.goldDark
                          : phase == 'done'
                          ? PointsDS.textMuted
                          : PointsDS.teal,
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
                              ? PointsDS.goldDark
                              : phase == 'done'
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
                    !canPlay ||
                    provider.isPlayingMiniGame ||
                    !provider.boxesRoundReady;
                final wobble =
                    provider.isPreparingBoxes
                        ? ((provider.boxesShuffleSeed + index) % 3 - 1) * 0.04
                        : 0.0;
                final vertShift =
                    provider.isPreparingBoxes
                        ? ((provider.boxesShuffleSeed + index * 2) % 3 - 1) *
                            5.0
                        : 0.0;
                final isWinner = !canPlay && provider.lastBoxesReward == reward;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                    child: GestureDetector(
                      onTap:
                          locked
                              ? null
                              : () => context
                                  .read<PointsProvider>()
                                  .playBoxMiniGame(
                                    index,
                                    config,
                                    context.read<WalletProvider>(),
                                  ),
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
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder:
                                        (w, anim) => ScaleTransition(
                                          scale: anim,
                                          child: w,
                                        ),
                                    child:
                                        (provider.showBoxesPreviewValues ||
                                                (locked && canPlay == false))
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
                                                            : PointsDS.goldDark,
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w900,
                                                    height: 1,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Icon(
                                                  Icons.monetization_on_rounded,
                                                  size: 14,
                                                  color:
                                                      locked
                                                          ? PointsDS.textMuted
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
                  (canPlay && phase == 'idle' && !provider.isPlayingMiniGame)
                      ? () =>
                          context.read<PointsProvider>().startBoxesRound(config)
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
                  provider.isPlayingMiniGame
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
