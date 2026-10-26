import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/top_customers/premium_customer_card.dart';

/// Fila del ranking (puesto 4 en adelante). Muestra una barra con el peso
/// del cliente respecto al #1 para leer el ranking de un vistazo.
class RankedCustomerRow extends StatelessWidget {
  final CustomerEntity customer;
  final int position;
  final double maxRevenue;
  final bool showShare;

  const RankedCustomerRow({
    super.key,
    required this.customer,
    required this.position,
    required this.maxRevenue,
    this.showShare = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final share =
        maxRevenue <= 0
            ? 0.0
            : (customer.totalRevenue.toDouble() / maxRevenue).clamp(0.0, 1.0);

    final orders =
        customer.orderCount == 1
            ? '1 compra'
            : '${customer.orderCount} compras';
    final last =
        customer.lastOrderAt != null
            ? ' · Últ. ${DateFormat('dd/MM/yy', 'es').format(customer.lastOrderAt!)}'
            : '';

    return InkWell(
      onTap:
          () => context.go(
            '/customers/customer-detail/${customer.id}',
            extra: customer,
          ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              child: Text(
                '#$position',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TopCustomerAvatar(customer: customer, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$orders$last',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (showShare) ...[
              const SizedBox(width: 16),
              SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 16),
            Text(
              currency.format(customer.totalRevenue),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
