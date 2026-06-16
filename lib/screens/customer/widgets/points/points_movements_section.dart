import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/providers/customer/points_provider.dart';
import 'package:inventory_store_app/screens/customer/widgets/points/points_design_tokens.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:provider/provider.dart';

class PointsMovementsSection extends StatelessWidget {
  const PointsMovementsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PointsProvider>();
    final movements = provider.movements;

    if (movements.isEmpty && !provider.isLoading) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: PointsDS.surface,
          borderRadius: BorderRadius.circular(PointsDS.radiusXl),
          boxShadow: PointsDS.cardShadow(),
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
                color: PointsDS.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin movimientos',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: PointsDS.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tu historial de monedas aparecerá aquí',
              style: TextStyle(fontSize: 12, color: PointsDS.textSecondary),
            ),
          ],
        ),
      );
    }

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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PointsDS.goldLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: PointsDS.gold,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Historial de movimientos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: PointsDS.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: movements.length,
            itemBuilder: (context, i) => _MovementRow(movement: movements[i]),
          ),

          if (provider.hasMoreMovements) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed:
                    provider.isLoadingMore
                        ? null
                        : () =>
                            context.read<PointsProvider>().loadMoreMovements(),
                style: TextButton.styleFrom(
                  backgroundColor: PointsDS.bg,
                  padding: const EdgeInsets.all(13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: PointsDS.border),
                  ),
                ),
                child:
                    provider.isLoadingMore
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                        : const Text(
                          'Cargar más movimientos',
                          style: TextStyle(
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
    'MINI_GAME_MEMORY': ('🃏', Color(0xFF0D9488), Color(0xFFCCFBF1)),
    'MINI_GAME_CATCHER': ('🌧️', Color(0xFFE5A93C), Color(0xFFFEF3C7)),
    'MINI_GAME_PINATA': ('🪅', Color(0xFFE05C41), Color(0xFFFFE4E6)),
    'MINI_GAME_JUMP': ('👟', Color(0xFF6A5AE0), Color(0xFFEDE9FE)),
    'MINI_GAME_CLAW': ('🕹️', Color(0xFFB26CFF), Color(0xFFF3E8FF)),
    'MINI_GAME_STACK': ('📦', Color(0xFF4E79FF), Color(0xFFEFF6FF)),
    'MINI_GAME_DODGE': ('🏃', Color(0xFF3E7DD1), Color(0xFFEFF6FF)),
    'REDEMPTION': ('🛒', Color(0xFFEF4444), Color(0xFFFFE4E6)),
    'EARN': ('💰', Color(0xFF10B981), Color(0xFFD1FAE5)),
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
            ? ('💰', PointsDS.success, PointsDS.successLight)
            : ('📉', PointsDS.danger, PointsDS.dangerLight));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PointsDS.bg,
        borderRadius: BorderRadius.circular(PointsDS.radius),
        border: Border.all(color: PointsDS.border),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PointsDS.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (parsedDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(parsedDate),
                    style: const TextStyle(
                      fontSize: 11,
                      color: PointsDS.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isPositive ? PointsDS.successLight : PointsDS.dangerLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${isPositive ? '+' : ''}$points',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isPositive ? PointsDS.success : PointsDS.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
