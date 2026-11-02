import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers/top_customers_desktop_table.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers/top_customers_detail_sheet.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers/top_customers_mobile_list.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers/top_customers_tablet_list.dart';

enum TopCustomersDisplayMode { desktop, tablet, mobile }

/// Tarjeta ejecutiva del Dashboard que presenta el ranking de clientes VIP destacados
class TopCustomersCard extends StatelessWidget {
  final List<CustomerEntity> customers;
  final TopCustomersDisplayMode displayMode;
  final VoidCallback? onHide;

  const TopCustomersCard({
    super.key,
    required this.customers,
    required this.displayMode,
    this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.darkSurface
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: isDark ? [] : AppColors.cardShadow(opacity: 0.04),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          if (customers.isEmpty)
            _buildEmptyState(context)
          else
            _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.amber.withValues(alpha: 0.2),
                  AppColors.amber.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.amberDark,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Clientes que más compran',
                      style: TextStyle(
                        fontSize:
                            displayMode == TopCustomersDisplayMode.desktop
                                ? 16
                                : 15,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark
                                ? const Color(0xFFF8FAFC)
                                : AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppColors.amberDark.withValues(alpha: 0.25)
                                : AppColors.amberLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'VIP',
                        style: TextStyle(
                          color: AppColors.amberDark,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Mayores compradores por volumen de facturación histórica',
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => context.go('/customers'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Text(
              'Ver todos',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            label: const Icon(Icons.arrow_forward_rounded, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? const Color(0xFF1E293B)
                        : AppColors.slateLight.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 32,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Aún no hay clientes registrados con compras completadas.',
              style: TextStyle(
                color:
                    isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (displayMode) {
      case TopCustomersDisplayMode.desktop:
        return TopCustomersDesktopTable(
          customers: customers,
          onCustomerTap:
              (customer) => TopCustomerDetailSheet.show(context, customer),
        );
      case TopCustomersDisplayMode.tablet:
        return TopCustomersTabletList(
          customers: customers,
          onCustomerTap:
              (customer) => TopCustomerDetailSheet.show(context, customer),
        );
      case TopCustomersDisplayMode.mobile:
        return TopCustomersMobileList(
          customers: customers,
          onCustomerTap:
              (customer) => TopCustomerDetailSheet.show(context, customer),
        );
    }
  }
}
