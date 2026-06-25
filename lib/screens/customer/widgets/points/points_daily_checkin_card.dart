import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/customer/widgets/points/points_design_tokens.dart';

class PointsDailyCheckinCard extends StatelessWidget {
  final String hundredCoinsValue;
  final String claimMessage;
  final String streakPreviewLabel;
  final int currentStreak;
  final int nextCheckinReward;
  final bool hasTodayCheckin;
  final bool isClaimingCheckin;
  final VoidCallback onClaim;
  final GlobalKey? claimButtonKey;

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
    this.claimButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PointsDS.surface,
        borderRadius: BorderRadius.circular(PointsDS.radiusXl),
        border: Border.all(
          color: hasTodayCheckin ? PointsDS.successLight : PointsDS.goldLight,
          width: 1.5,
        ),
        boxShadow: PointsDS.cardShadow(),
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
                      color:
                          hasTodayCheckin
                              ? PointsDS.successLight
                              : PointsDS.goldLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasTodayCheckin
                          ? Icons.check_circle_rounded
                          : Icons.calendar_today_rounded,
                      size: 18,
                      color: hasTodayCheckin ? PointsDS.success : PointsDS.gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Racha diaria',
                    style: TextStyle(
                      color: PointsDS.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              _StatusPill(
                label: hasTodayCheckin ? 'COMPLETADO' : 'PENDIENTE',
                color:
                    hasTodayCheckin ? PointsDS.successDark : PointsDS.goldDark,
                bgColor:
                    hasTodayCheckin
                        ? PointsDS.successLight
                        : PointsDS.goldLight,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Message
          Text(
            claimMessage,
            style: const TextStyle(
              color: PointsDS.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Action Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PointsDS.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PointsDS.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasTodayCheckin
                            ? 'Próxima recompensa'
                            : 'Recompensa de hoy',
                        style: const TextStyle(
                          color: PointsDS.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '+$nextCheckinReward',
                            style: const TextStyle(
                              color: PointsDS.gold,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'monedas',
                            style: TextStyle(
                              color: PointsDS.goldDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Botón
                ElevatedButton(
                  key: claimButtonKey,
                  onPressed:
                      (hasTodayCheckin || isClaimingCheckin) ? null : onClaim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hasTodayCheckin ? PointsDS.bg : PointsDS.gold,
                    foregroundColor:
                        hasTodayCheckin ? PointsDS.textMuted : Colors.white,
                    elevation: hasTodayCheckin ? 0 : 4,
                    shadowColor: PointsDS.gold.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      isClaimingCheckin
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            hasTodayCheckin ? 'Vuelve mañana' : 'Reclamar',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                ),
              ],
            ),
          ),

          if (!hasTodayCheckin) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: PointsDS.textMuted,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    streakPreviewLabel,
                    style: const TextStyle(
                      color: PointsDS.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
