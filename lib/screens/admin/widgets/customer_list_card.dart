import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/admin/customers_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:intl/intl.dart';

class CustomerListCard extends StatelessWidget {
  final CustomerSummary customer;
  final VoidCallback onTap;

  const CustomerListCard({
    super.key,
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _CustomerAvatar(customer: customer),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customer.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!customer.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Inactivo',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (customer.phone != null && customer.phone!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.phone_rounded, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              customer.phone!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Tag(
                            icon: Icons.shopping_bag_rounded,
                            text: '${customer.orderCount} compras',
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          if (customer.currentDebt > 0)
                            _Tag(
                              icon: Icons.warning_rounded,
                              text: 'Debe S/ ${customer.currentDebt.toStringAsFixed(0)}',
                              color: Colors.red,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total Gastado',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'S/ ${customer.totalSpent.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (customer.lastOrderAt != null)
                      Text(
                        'Últ: ${DateFormat('dd/MM/yy').format(customer.lastOrderAt!)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final CustomerSummary customer;

  const _CustomerAvatar({required this.customer});

  @override
  Widget build(BuildContext context) {
    if (customer.avatarUrl != null && customer.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade100,
        backgroundImage: CachedNetworkImageProvider(customer.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.primaries[customer.fullName.length % Colors.primaries.length].withValues(alpha: 0.2),
      child: Text(
        customer.fullName[0].toUpperCase(),
        style: TextStyle(
          color: Colors.primaries[customer.fullName.length % Colors.primaries.length],
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final MaterialColor color;

  const _Tag({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
