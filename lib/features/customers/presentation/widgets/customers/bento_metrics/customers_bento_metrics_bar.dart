import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_kpi_metrics_bar.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_state.dart';

/// Barra de métricas Bento KPI Fintech para el directorio de clientes
class CustomersBentoMetricsBar extends StatelessWidget {
  final bool isMobile;
  final bool isTablet;

  const CustomersBentoMetricsBar({
    super.key,
    required this.isMobile,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomersStatsCubit, CustomersStatsState>(
      builder: (context, state) {
        final isLoading = state is CustomersStatsLoading;
        final total =
            state is CustomersStatsLoaded ? state.totalCustomersCount : 0;
        final active =
            state is CustomersStatsLoaded ? state.activeCustomersCount : 0;
        final revenue =
            state is CustomersStatsLoaded ? state.totalRevenue : 0.0;
        final debt = state is CustomersStatsLoaded ? state.totalDebt : 0.0;
        final activePct =
            total > 0 ? ((active / total) * 100).toStringAsFixed(0) : '0';

        return AdminKpiMetricsBar(
          isLoading: isLoading,
          isDesktop: !isMobile,
          isMobileGrid: true,
          padding: EdgeInsets.fromLTRB(16, isMobile ? 10 : 12, 16, 6),
          items: [
            AdminKpiItem(
              title: 'TOTAL CLIENTES',
              value: '$total',
              subtitle: 'Directorio activo',
              icon: Icons.people_alt_rounded,
              accentColor: AppColors.primary,
              gradientColors: const [Colors.white, Color(0xFFF8FAFC)],
              iconGradient: const [Color(0xFF334155), Color(0xFF1E293B)],
              borderColor: const Color(0xFFE2E8F0),
              glowColor: const Color(0x1F0F172A),
            ),
            AdminKpiItem(
              title: 'CLIENTES ACTIVOS',
              value: '$active',
              subtitle: '$activePct% de cartera',
              icon: Icons.verified_user_rounded,
              accentColor: AppColors.successDark,
              gradientColors: const [Colors.white, Color(0xFFECFDF5)],
              iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
              borderColor: const Color(0xFFA7F3D0),
              glowColor: const Color(0x2E10B981),
            ),
            AdminKpiItem(
              title: 'FACTURACIÓN',
              value: _formatCompactMoney(revenue),
              subtitle: 'Ingresos históricos',
              icon: Icons.trending_up_rounded,
              accentColor: AppColors.info,
              gradientColors: const [Colors.white, Color(0xFFF0F9FF)],
              iconGradient: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
              borderColor: const Color(0xFFBAE6FD),
              glowColor: const Color(0x2E0EA5E9),
            ),
            AdminKpiItem(
              title: 'CUENTAS POR COBRAR',
              value: _formatCompactMoney(debt),
              subtitle: debt > 0 ? 'Saldos pendientes' : 'Al día',
              icon: Icons.account_balance_wallet_rounded,
              accentColor: debt > 0 ? AppColors.danger : AppColors.tealDark,
              gradientColors: [
                Colors.white,
                debt > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDFA),
              ],
              iconGradient:
                  debt > 0
                      ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
                      : const [Color(0xFF0D9488), Color(0xFF0F766E)],
              borderColor:
                  debt > 0 ? const Color(0xFFFECACA) : const Color(0xFF99F6E4),
              glowColor:
                  debt > 0 ? const Color(0x2EEF4444) : const Color(0x2E0D9488),
              valueColor: debt > 0 ? AppColors.danger : AppColors.textPrimary,
              isAlert: debt > 0,
            ),
          ],
        );
      },
    );
  }

  static String _formatCompactMoney(double value) {
    if (value >= 1000000) {
      return 'S/ ${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return 'S/ ${(value / 1000).toStringAsFixed(1)}K';
    }
    return 'S/ ${value.toStringAsFixed(0)}';
  }
}
