import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/points/points_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/points/points_state.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/points/points_design_tokens.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class PointsMovementsSection extends StatelessWidget {
  const PointsMovementsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PointsCubit, PointsState>(
      builder: (context, state) {
        final movements = state.movements;

        if (movements.isEmpty && !state.isLoading) {
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
                itemBuilder:
                    (context, i) => _MovementRow(movement: movements[i]),
              ),

              if (state.hasMoreMovements) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed:
                        state.isLoadingMore
                            ? null
                            : () =>
                                context.read<PointsCubit>().loadMoreMovements(),
                    style: TextButton.styleFrom(
                      backgroundColor: PointsDS.bg,
                      padding: const EdgeInsets.all(13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: PointsDS.border),
                      ),
                    ),
                    child:
                        state.isLoadingMore
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
      },
    );
  }
}

class _MovementRow extends StatelessWidget {
  final Map<String, dynamic> movement;
  const _MovementRow({required this.movement});

  static const Map<String, (IconData, Color, Color)> _typeMap = {
    'DAILY_CHECKIN': (
      Icons.event_available_rounded,
      Color(0xFF10B981),
      Color(0xFFD1FAE5),
    ),
    'CHECKIN': (
      Icons.event_available_rounded,
      Color(0xFF10B981),
      Color(0xFFD1FAE5),
    ),
    'MINI_GAME_BOXES': (
      Icons.inbox_rounded,
      Color(0xFFF59E0B),
      Color(0xFFFEF3C7),
    ),
    'MINI_GAME_MEMORY': (
      Icons.extension_rounded,
      Color(0xFF0D9488),
      Color(0xFFCCFBF1),
    ),
    'MINI_GAME_CATCHER': (
      Icons.monetization_on_rounded,
      Color(0xFFE5A93C),
      Color(0xFFFEF3C7),
    ),
    'MINI_GAME_PINATA': (
      Icons.card_giftcard_rounded,
      Color(0xFFE05C41),
      Color(0xFFFFE4E6),
    ),
    'MINI_GAME_JUMP': (
      Icons.directions_run_rounded,
      Color(0xFF6A5AE0),
      Color(0xFFEDE9FE),
    ),
    'MINI_GAME_CLAW': (
      Icons.toys_rounded,
      Color(0xFFB26CFF),
      Color(0xFFF3E8FF),
    ),
    'MINI_GAME_STACK': (
      Icons.layers_rounded,
      Color(0xFF4E79FF),
      Color(0xFFEFF6FF),
    ),
    'MINI_GAME_DODGE': (
      Icons.rocket_launch_rounded,
      Color(0xFF3E7DD1),
      Color(0xFFEFF6FF),
    ),
    'REDEMPTION': (
      Icons.shopping_cart_checkout_rounded,
      Color(0xFFEF4444),
      Color(0xFFFFE4E6),
    ),
    'EARN': (
      Icons.account_balance_wallet_rounded,
      Color(0xFF10B981),
      Color(0xFFD1FAE5),
    ),
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

    final (icon, badgeColor, badgeBg) =
        _typeMap[type] ??
        (isPositive
            ? (
              Icons.monetization_on_rounded,
              PointsDS.success,
              PointsDS.successLight,
            )
            : (
              Icons.trending_down_rounded,
              PointsDS.danger,
              PointsDS.dangerLight,
            ));

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
          // Icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(child: Icon(icon, color: badgeColor, size: 20)),
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
                    DateFormat('dd MMM yyyy, hh:mm a', 'es').format(parsedDate),
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
