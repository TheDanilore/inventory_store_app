import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class PosCreditWarningCard extends StatelessWidget {
  final bool clienteSeleccionado;
  final bool creditActivo;
  final double creditDisponible;
  final double totalFinal;
  final Map<String, dynamic>? creditInfo;

  const PosCreditWarningCard({
    super.key,
    required this.clienteSeleccionado,
    required this.creditActivo,
    required this.creditDisponible,
    required this.totalFinal,
    required this.creditInfo,
  });

  @override
  Widget build(BuildContext context) {
    if (!clienteSeleccionado) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.deepOrange.shade50,
          borderRadius: BorderRadius.circular(AppColors.radius),
          border: Border.all(color: Colors.deepOrange.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.deepOrange, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Debes seleccionar un cliente para ventas a crédito.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepOrange,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!creditActivo) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(AppColors.radius),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.block_rounded, color: Colors.red, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Este cliente no tiene línea de crédito activa.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final limit = (creditInfo?['credit_limit'] as num?)?.toDouble() ?? 0.0;
    final isUnlimited = limit <= 0;
    final debt = (creditInfo?['current_debt'] as num?)?.toDouble() ?? 0.0;
    final insuficiente = creditDisponible < totalFinal;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: insuficiente ? Colors.red.shade50 : AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: insuficiente ? Colors.red.shade300 : Colors.grey.shade200,
        ),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                insuficiente
                    ? Icons.error_outline_rounded
                    : Icons.credit_score_rounded,
                color: insuficiente ? Colors.red.shade700 : AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Línea de Crédito del Cliente',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      insuficiente
                          ? Colors.red.shade700
                          : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Disponible:',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      insuficiente
                          ? Colors.red.shade600
                          : AppColors.textSecondary,
                ),
              ),
              Text(
                isUnlimited
                    ? 'Ilimitado'
                    : 'S/ ${creditDisponible.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: insuficiente ? Colors.red.shade700 : AppColors.primary,
                ),
              ),
            ],
          ),
          if (!isUnlimited) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Límite: S/ ${limit.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  'Deuda: S/ ${debt.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        debt > 0 ? Colors.orange.shade700 : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
          if (insuficiente) ...[
            const SizedBox(height: 6),
            Text(
              'El monto total (S/ ${totalFinal.toStringAsFixed(2)}) excede el crédito disponible.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
