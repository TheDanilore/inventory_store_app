import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

/// Avatar reutilizable (foto o inicial) para todo el módulo de Top Clientes.
class TopCustomerAvatar extends StatelessWidget {
  final CustomerEntity customer;
  final double radius;
  const TopCustomerAvatar({
    super.key,
    required this.customer,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final url = customer.avatarUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    final name = customer.fullName.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: hasPhoto ? CachedNetworkImageProvider(url) : null,
      child:
          hasPhoto
              ? null
              : Text(
                initial,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontSize: radius * 0.8,
                ),
              ),
    );
  }
}

/// Tarjeta de podio (puestos 1, 2 y 3). El #1 se muestra más grande
/// ([featured]) con acento dorado; plata y bronce para 2 y 3.
class PremiumCustomerCard extends StatefulWidget {
  final CustomerEntity customer;
  final int position; // 1, 2 o 3
  final bool featured;

  const PremiumCustomerCard({
    super.key,
    required this.customer,
    required this.position,
    this.featured = false,
  });

  @override
  State<PremiumCustomerCard> createState() => _PremiumCustomerCardState();
}

class _PremiumCustomerCardState extends State<PremiumCustomerCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final c = widget.customer;
    final featured = widget.featured;

    final Color accent;
    final String medal;
    switch (widget.position) {
      case 1:
        accent = const Color(0xFFF5B301);
        medal = '🥇';
        break;
      case 2:
        accent = const Color(0xFF94A3B8);
        medal = '🥈';
        break;
      default:
        accent = const Color(0xFFCD7F32);
        medal = '🥉';
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accent.withValues(alpha: 0.20), theme.colorScheme.surface],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: accent.withValues(alpha: 0.75),
            width: featured ? 2 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: _hovered ? 0.30 : 0.14),
              blurRadius: _hovered ? 28 : 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap:
                () =>
                    context.go('/customers/customer-detail/${c.id}', extra: c),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, featured ? 24 : 18, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(medal, style: TextStyle(fontSize: featured ? 36 : 28)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 2),
                    ),
                    child: TopCustomerAvatar(
                      customer: c,
                      radius: featured ? 38 : 30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    c.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: featured ? 17 : 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.orderCount == 1 ? '1 compra' : '${c.orderCount} compras',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      currency.format(c.totalRevenue),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: featured ? 20 : 16,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
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
