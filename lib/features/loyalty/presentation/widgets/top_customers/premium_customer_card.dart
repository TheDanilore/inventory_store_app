import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class PremiumCustomerCard extends StatefulWidget {
  final CustomerEntity customer;
  final int position;

  const PremiumCustomerCard({
    super.key,
    required this.customer,
    required this.position,
  });

  @override
  State<PremiumCustomerCard> createState() => _PremiumCustomerCardState();
}

class _PremiumCustomerCardState extends State<PremiumCustomerCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatCurrency = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    final isTop3 = widget.position <= 3;
    Color? borderColor;
    List<Color>? gradientColors;
    Widget? medalIcon;

    if (widget.position == 1) {
      borderColor = const Color(0xFFFFD700); // Oro
      gradientColors = [
        const Color(0xFFFFD700).withValues(alpha: 0.15),
        const Color(0xFFFFD700).withValues(alpha: 0.02),
      ];
      medalIcon = const Text('🥇', style: TextStyle(fontSize: 24));
    } else if (widget.position == 2) {
      borderColor = const Color(0xFFC0C0C0); // Plata
      gradientColors = [
        const Color(0xFFC0C0C0).withValues(alpha: 0.15),
        const Color(0xFFC0C0C0).withValues(alpha: 0.02),
      ];
      medalIcon = const Text('🥈', style: TextStyle(fontSize: 24));
    } else if (widget.position == 3) {
      borderColor = const Color(0xFFCD7F32); // Bronce
      gradientColors = [
        const Color(0xFFCD7F32).withValues(alpha: 0.15),
        const Color(0xFFCD7F32).withValues(alpha: 0.02),
      ];
      medalIcon = const Text('🥉', style: TextStyle(fontSize: 24));
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          gradient:
              isTop3
                  ? LinearGradient(
                    colors: gradientColors!,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                borderColor ??
                theme.colorScheme.outlineVariant.withValues(
                  alpha: _isHovered ? 0.8 : 0.3,
                ),
            width: isTop3 ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (borderColor ?? theme.colorScheme.shadow).withValues(
                alpha: _isHovered ? 0.15 : 0.03,
              ),
              blurRadius: _isHovered ? 20 : 12,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              context.push(
                '/admin/customer-detail/${widget.customer.id}',
                extra: widget.customer,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Posición / Medalla
                  SizedBox(
                    width: 40,
                    child: Center(
                      child:
                          medalIcon ??
                          Text(
                            '#${widget.position}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage:
                        widget.customer.avatarUrl != null
                            ? CachedNetworkImageProvider(
                              widget.customer.avatarUrl!,
                            )
                            : null,
                    child:
                        widget.customer.avatarUrl == null
                            ? Text(
                              widget.customer.fullName[0].toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 18,
                              ),
                            )
                            : null,
                  ),
                  const SizedBox(width: 16),

                  // Info del Cliente
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.customer.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cliente Destacado',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Monto Total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        formatCurrency.format(widget.customer.totalRevenue),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Comprado',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
