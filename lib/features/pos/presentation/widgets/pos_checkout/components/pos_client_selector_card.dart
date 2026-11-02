import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Tier 2: Tarjeta / Pill selector de cliente a ancho completo con botón + Nuevo Express.
class PosClientSelectorCard extends StatelessWidget {
  final bool hasClient;
  final String displayName;
  final Map<String, dynamic>? creditInfo;
  final bool isCredito;
  final bool isLoyaltyEnabled;
  final int saldoActualCliente;
  final VoidCallback onTap;
  final VoidCallback onClearClient;
  final VoidCallback onNewClientTap;

  const PosClientSelectorCard({
    super.key,
    required this.hasClient,
    required this.displayName,
    required this.creditInfo,
    required this.isCredito,
    required this.isLoyaltyEnabled,
    required this.saldoActualCliente,
    required this.onTap,
    required this.onClearClient,
    required this.onNewClientTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color:
                hasClient
                    ? AppColors.teal.withValues(alpha: 0.07)
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              hoverColor: AppColors.teal.withValues(alpha: 0.05),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        hasClient
                            ? AppColors.teal.withValues(alpha: 0.35)
                            : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color:
                            hasClient
                                ? AppColors.teal.withValues(alpha: 0.15)
                                : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasClient
                            ? Icons.person_rounded
                            : Icons.person_outline_rounded,
                        size: 14,
                        color:
                            hasClient
                                ? AppColors.tealDark
                                : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  hasClient ? FontWeight.w700 : FontWeight.w600,
                              color:
                                  hasClient
                                      ? AppColors.tealDark
                                      : AppColors.textPrimary,
                            ),
                          ),
                          if (hasClient && creditInfo != null && isCredito)
                            Text(
                              ((creditInfo!['credit_limit'] as num?)
                                              ?.toDouble() ??
                                          0) <=
                                      0
                                  ? 'Crédito: Ilimitado (∞)'
                                  : 'Crédito: S/ ${(creditInfo!['credit_limit'] ?? 0)}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: AppColors.textMuted,
                                height: 1.1,
                              ),
                            )
                          else if (!hasClient)
                            const Text(
                              'Venta rápida',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: AppColors.textMuted,
                                height: 1.1,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (hasClient &&
                        isLoyaltyEnabled &&
                        saldoActualCliente > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.amber.shade300,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '$saldoActualCliente pts',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    if (hasClient) ...[
                      Tooltip(
                        message: 'Quitar cliente',
                        child: InkWell(
                          onTap: onClearClient,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.unfold_more_rounded,
                        size: 15,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Nuevo Cliente Express',
          child: Material(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onNewClientTap,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Nuevo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
