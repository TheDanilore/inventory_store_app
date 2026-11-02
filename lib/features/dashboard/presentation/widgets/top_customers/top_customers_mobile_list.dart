import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers/top_customers_rank_badge.dart';

/// Lista táctil optimizada para teléfonos móviles con target de 48dp mínimo
class TopCustomersMobileList extends StatelessWidget {
  final List<CustomerEntity> customers;
  final ValueChanged<CustomerEntity> onCustomerTap;

  const TopCustomersMobileList({
    super.key,
    required this.customers,
    required this.onCustomerTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxRevenue =
        customers.isNotEmpty && customers.first.totalRevenue > 0
            ? customers.first.totalRevenue
            : 1.0;

    return Column(
      children: [
        for (int i = 0; i < customers.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          _MobileCustomerItem(
            customer: customers[i],
            rank: i + 1,
            ratio: (customers[i].totalRevenue / maxRevenue).clamp(0.04, 1.0),
            isDark: isDark,
            onTap: () => onCustomerTap(customers[i]),
          ),
        ],
      ],
    );
  }
}

class _MobileCustomerItem extends StatelessWidget {
  final CustomerEntity customer;
  final int rank;
  final double ratio;
  final bool isDark;
  final VoidCallback onTap;

  const _MobileCustomerItem({
    required this.customer,
    required this.rank,
    required this.ratio,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    color: (isDark
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF2563EB))
                        .withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  TopCustomerRankBadge(rank: rank, isDark: isDark),
                  const SizedBox(width: 12),
                  TopCustomerAvatar(customer: customer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.fullName,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark
                                    ? const Color(0xFFF8FAFC)
                                    : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? AppColors.primary.withValues(
                                          alpha: 0.2,
                                        )
                                        : AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${customer.orderCount} ord.',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            if (customer.phone != null &&
                                customer.phone!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                customer.phone!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'S/ ${customer.totalRevenue.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color:
                              isDark
                                  ? const Color(0xFF34D399)
                                  : AppColors.tealDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Total facturado',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
