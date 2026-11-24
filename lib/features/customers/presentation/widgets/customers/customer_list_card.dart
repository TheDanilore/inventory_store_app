import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

/// Tarjeta de cliente optimizada (StatelessWidget, decodificación de avatar acotada
/// y formato de fecha compartido) para dispositivos de baja gama / RAM limitada.
class CustomerListCard extends StatelessWidget {
  final CustomerEntity customer;
  final VoidCallback onTap;

  static final DateFormat _shortDateFormat = DateFormat('dd/MM/yy', 'es');

  const CustomerListCard({
    super.key,
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow(opacity: 0.02),
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
                      mainAxisAlignment: MainAxisAlignment.center,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.slateLight.withValues(
                                    alpha: 0.6,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Text(
                                  'Inactivo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.slate,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (customer.phone != null &&
                            customer.phone!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_rounded,
                                size: 12,
                                color: AppColors.textMuted,
                              ),
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
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _Tag(
                              icon: Icons.shopping_bag_rounded,
                              text: '${customer.orderCount} compras',
                              color: AppColors.info,
                            ),
                            if (customer.currentDebt > 0)
                              _Tag(
                                icon: Icons.warning_rounded,
                                text:
                                    'Debe S/ ${customer.currentDebt.toStringAsFixed(0)}',
                                color: AppColors.danger,
                              ),
                            if (customer.locationsCount > 0)
                              _Tag(
                                icon: Icons.place_rounded,
                                text:
                                    customer.locationsCount == 1
                                        ? '1 ubicación'
                                        : '${customer.locationsCount} ubicaciones',
                                color: AppColors.teal,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'S/ ${customer.totalRevenue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (customer.lastOrderAt != null)
                        Text(
                          'Últ: ${_shortDateFormat.format(customer.lastOrderAt!)}',
                          style: const TextStyle(
                            fontSize: 11,
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
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final CustomerEntity customer;

  const _CustomerAvatar({required this.customer});

  @override
  Widget build(BuildContext context) {
    final url = customer.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade100,
        backgroundImage: CachedNetworkImageProvider(
          url,
          maxWidth: 96,
          maxHeight: 96,
        ),
      );
    }

    final trimmed = customer.fullName.trim();
    final initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
    final baseColor =
        Colors.primaries[customer.fullName.length % Colors.primaries.length];

    return CircleAvatar(
      radius: 24,
      backgroundColor: baseColor.withValues(alpha: 0.2),
      child: Text(
        initial,
        style: TextStyle(
          color: baseColor,
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
  final Color color;

  const _Tag({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
