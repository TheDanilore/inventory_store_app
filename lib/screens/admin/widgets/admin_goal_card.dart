import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class AdminGoalCard extends StatelessWidget {
  final double currentAmount;
  final double targetAmount;
  final VoidCallback? onAddPressed;

  const AdminGoalCard({
    super.key,
    required this.currentAmount,
    required this.targetAmount,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final rawProgress = targetAmount > 0 ? (currentAmount / targetAmount) : 0.0;
    final progress = rawProgress.clamp(0.0, 1.0);
    final int percentage = (rawProgress * 100).clamp(0, 100).toInt();
    final remainingAmount = (targetAmount - currentAmount).clamp(
      0,
      double.infinity,
    );
    final hasReachedGoal = currentAmount >= targetAmount && targetAmount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 10,
      ), // Margen ajustado para alinearse con las otras cards
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Gráfico circular de progreso
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.amber.shade400,
                  ),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Textos e información
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'MI META DE AHORRO',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'S/ ${currentAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'de S/ ${targetAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasReachedGoal
                      ? 'Meta cumplida. ¡Excelente trabajo!'
                      : 'Te faltan S/ ${remainingAmount.toStringAsFixed(2)} para tu meta.',
                  style: TextStyle(
                    color:
                        hasReachedGoal
                            ? Colors.greenAccent.shade100
                            : Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message:
                onAddPressed == null
                    ? 'Configura esta acción para abonar a la meta.'
                    : 'Configurar Meta',
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                ), // Cambié el icono a 'edit' que tiene más sentido
                onPressed: onAddPressed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
