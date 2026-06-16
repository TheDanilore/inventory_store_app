import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/customer_credit_models.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class CreditAccountCard extends StatelessWidget {
  final CreditAccountModel account;
  final VoidCallback onTap;

  const CreditAccountCard({
    super.key,
    required this.account,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = account.usagePercent;
    final isRisk = pct >= 0.8;
    final barColor = account.isMaxedOut
        ? AppColors.danger
        : isRisk
            ? Colors.orange
            : AppColors.teal;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: account.isMaxedOut
              ? AppColors.danger.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabecera ──
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: account.isActive
                        ? AppColors.tealLight
                        : Colors.grey.shade200,
                    child: Text(
                      account.partnerName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: account.isActive
                            ? AppColors.tealDark
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.partnerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (account.partnerDocument != null ||
                            account.partnerPhone != null)
                          Text(
                            [
                              if (account.partnerDocument != null)
                                '${account.partnerDocumentType ?? 'Doc'}: ${account.partnerDocument}',
                              if (account.partnerPhone != null)
                                account.partnerPhone!,
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Badge de estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: account.isActive
                          ? AppColors.successLight
                          : AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      account.isActive ? 'ACTIVO' : 'SUSPENDIDO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: account.isActive
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Montos ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Deuda actual',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'S/ ${account.currentDebt.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: account.currentDebt > 0
                              ? (isRisk
                                  ? AppColors.danger
                                  : AppColors.textPrimary)
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Disponible: S/ ${account.availableCredit.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: account.isActive
                              ? AppColors.teal
                              : AppColors.textMuted,
                        ),
                      ),
                      Text(
                        'Límite: S/ ${account.creditLimit.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Barra de progreso ──
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: AppColors.bg,
                  color: barColor,
                ),
              ),
              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    account.isMaxedOut
                        ? '⚠ Límite alcanzado'
                        : '${(pct * 100).toStringAsFixed(0)}% utilizado',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: account.isMaxedOut
                          ? AppColors.danger
                          : AppColors.textMuted,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
