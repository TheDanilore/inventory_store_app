import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customers_repository.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers/top_customers_desktop_table.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers/top_customers_detail_sheet.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers/top_customers_mobile_list.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers/top_customers_tablet_list.dart';

enum TopCustomersDisplayMode { desktop, tablet, mobile }

enum TopCustomersCardPeriod { thisMonth, thisYear, allTime }

/// Tarjeta ejecutiva del Dashboard que presenta el ranking de clientes VIP destacados
/// con soporte para filtrado dinámico por Mes, Anual e Histórico
class TopCustomersCard extends StatefulWidget {
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
  State<TopCustomersCard> createState() => _TopCustomersCardState();
}

class _TopCustomersCardState extends State<TopCustomersCard> {
  TopCustomersCardPeriod _selectedPeriod = TopCustomersCardPeriod.allTime;
  List<CustomerEntity>? _customList;
  bool _isLoading = false;

  List<CustomerEntity> get _displayedCustomers =>
      _customList ?? widget.customers;

  Future<void> _changePeriod(TopCustomersCardPeriod period) async {
    if (_selectedPeriod == period && _customList != null) return;
    setState(() {
      _selectedPeriod = period;
      _isLoading = true;
    });

    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    switch (period) {
      case TopCustomersCardPeriod.thisMonth:
        start = DateTime(now.year, now.month, 1);
        final nextM =
            now.month == 12
                ? DateTime(now.year + 1, 1, 1)
                : DateTime(now.year, now.month + 1, 1);
        end = nextM.subtract(const Duration(milliseconds: 1));
        break;
      case TopCustomersCardPeriod.thisYear:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        break;
      case TopCustomersCardPeriod.allTime:
        start = null;
        end = null;
        break;
    }

    try {
      final repo = sl<CustomersRepository>();
      final list = await repo.getTopCustomers(
        5,
        startDate: start,
        endDate: end,
      );
      if (mounted) {
        setState(() {
          _customList = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _customList = widget.customers;
          _isLoading = false;
        });
      }
    }
  }

  String get _periodSubtitle {
    switch (_selectedPeriod) {
      case TopCustomersCardPeriod.thisMonth:
        return 'Mayores compradores por facturación en este mes';
      case TopCustomersCardPeriod.thisYear:
        return 'Mayores compradores por facturación anual (${DateTime.now().year})';
      case TopCustomersCardPeriod.allTime:
        return 'Mayores compradores por volumen de facturación histórica';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customers = _displayedCustomers;

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
          _buildPeriodBar(context, isDark),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (customers.isEmpty)
            _buildEmptyState(context)
          else
            _buildBody(context, customers),
        ],
      ),
    );
  }

  Widget _buildPeriodBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color:
          isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.4)
              : const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Text(
            'FILTRO:',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Este Mes',
            TopCustomersCardPeriod.thisMonth,
            isDark,
          ),
          const SizedBox(width: 6),
          _buildFilterChip('Anual', TopCustomersCardPeriod.thisYear, isDark),
          const SizedBox(width: 6),
          _buildFilterChip('Histórico', TopCustomersCardPeriod.allTime, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    TopCustomersCardPeriod period,
    bool isDark,
  ) {
    final isSelected = _selectedPeriod == period;
    return InkWell(
      onTap: () => _changePeriod(period),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary
                  : (isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color:
                isSelected
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF475569)),
          ),
        ),
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
                            widget.displayMode ==
                                    TopCustomersDisplayMode.desktop
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
                  _periodSubtitle,
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
          FilledButton.tonalIcon(
            onPressed: () => context.push('/customers/top-customers'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.casino_rounded, size: 15),
            label: const Text(
              'Sorteo',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: () => context.push('/customers/top-customers'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Text(
              'Ver ranking',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            label: const Icon(Icons.arrow_forward_rounded, size: 15),
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
              'No se registraron compras de clientes en el período seleccionado.',
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

  Widget _buildBody(BuildContext context, List<CustomerEntity> customers) {
    switch (widget.displayMode) {
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
