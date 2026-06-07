import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_primary_button.dart';

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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Racha diaria',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      hasTodayCheckin
                          ? AppColors.primaryLight
                          : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasTodayCheckin ? 'Completado' : 'Disponible',
                  style: TextStyle(
                    color:
                        hasTodayCheckin
                            ? AppColors.primaryDark
                            : Colors.amber.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade100),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.stars_rounded,
                      color: Colors.amber.shade600,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+$nextCheckinReward',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      streakPreviewLabel,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      claimMessage,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.orange.shade400,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentStreak > 0
                        ? 'Llevas $currentStreak días seguidos reclamando.'
                        : 'Empieza hoy tu racha diaria.',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: hasTodayCheckin ? 'Ya reclamado hoy' : 'Reclamar monedas',
            onPressed: hasTodayCheckin ? null : onClaim,
            loading: isClaimingCheckin,
            icon: Icon(
              hasTodayCheckin ? Icons.check_circle_outline : Icons.touch_app,
              color: hasTodayCheckin ? AppColors.textHint : Colors.white,
            ),
            backgroundColor:
                hasTodayCheckin ? Colors.grey.shade100 : AppColors.primary,
            foregroundColor:
                hasTodayCheckin ? AppColors.textHint : Colors.white,
          ),
        ],
      ),
    );
  }
}
