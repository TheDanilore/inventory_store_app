import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers/top_customers_rank_badge.dart';

/// Lista en tarjetas adaptada para tablet con touch targets amplios
class TopCustomersTabletList extends StatelessWidget {
  final List<CustomerEntity> customers;
  final ValueChanged<CustomerEntity> onCustomerTap;

  const TopCustomersTabletList({
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (int i = 0; i < customers.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _TabletCustomerCard(
              customer: customers[i],
              rank: i + 1,
              ratio: (customers[i].totalRevenue / maxRevenue).clamp(0.04, 1.0),
              isDark: isDark,
              onTap: () => onCustomerTap(customers[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabletCustomerCard extends StatelessWidget {
  final CustomerEntity customer;
  final int rank;
  final double ratio;
  final bool isDark;
  final VoidCallback onTap;

  const _TabletCustomerCard({
    required this.customer,
    required this.rank,
    required this.ratio,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final averageTicket =
        customer.orderCount > 0
            ? customer.totalRevenue / customer.orderCount
            : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            color: isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
          ),
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
                          .withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    TopCustomerRankBadge(rank: rank, isDark: isDark),
                    const SizedBox(width: 14),
                    TopCustomerAvatar(customer: customer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.fullName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? const Color(0xFFF8FAFC)
                                      : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${customer.orderCount} compras realizadas · Ticket medio S/ ${averageTicket.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color:
                                  isDark
                                      ? const Color(0xFF94A3B8)
                                      : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'S/ ${customer.totalRevenue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color:
                                isDark
                                    ? const Color(0xFF34D399)
                                    : AppColors.tealDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Facturado',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
