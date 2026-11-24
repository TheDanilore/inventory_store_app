import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_kpi_metrics_bar.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_state.dart';

class SuppliersKpiSection extends StatelessWidget {
  final bool isWide;

  const SuppliersKpiSection({super.key, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SuppliersCubit, SuppliersState, SupplierStatsEntity>(
      selector: (state) => state.stats,
      builder: (context, stats) {
        final total = stats.totalSuppliers;
        final active = stats.activeSuppliers;
        final withRuc = stats.withTaxIdCount;
        final activePct =
            total > 0 ? ((active / total) * 100).toStringAsFixed(0) : '100';

        return Padding(
          padding: EdgeInsets.fromLTRB(
            isWide ? 24 : 16,
            isWide ? 14 : 12,
            isWide ? 24 : 16,
            4,
          ),
          child: AdminKpiMetricsBar(
            isDesktop: isWide,
            padding: EdgeInsets.zero,
            items: [
              AdminKpiItem(
                title: 'Total Proveedores',
                value: '$total',
                subtitle: 'Empresas registradas',
                icon: Icons.storefront_rounded,
                accentColor: AppColors.primary,
                gradientColors: const [Colors.white, Color(0xFFF8FAFC)],
                iconGradient: const [Color(0xFF334155), Color(0xFF1E293B)],
                borderColor: const Color(0xFFE2E8F0),
                glowColor: const Color(0x1F0F172A),
              ),
              AdminKpiItem(
                title: 'Proveedores Activos',
                value: '$active',
                subtitle: '$activePct% habilitados',
                icon: Icons.check_circle_outline_rounded,
                accentColor: AppColors.successDark,
                gradientColors: const [Colors.white, Color(0xFFECFDF5)],
                iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
                borderColor: const Color(0xFFA7F3D0),
                glowColor: const Color(0x2E10B981),
              ),
              AdminKpiItem(
                title: 'Facturación / RUC',
                value: '$withRuc',
                subtitle: 'Identificaciones cargadas',
                icon: Icons.receipt_long_rounded,
                accentColor: AppColors.tealDark,
                gradientColors: const [Colors.white, Color(0xFFF0FDFA)],
                iconGradient: const [Color(0xFF0D9488), Color(0xFF0F766E)],
                borderColor: const Color(0xFF99F6E4),
                glowColor: const Color(0x2E0D9488),
              ),
            ],
          ),
        );
      },
    );
  }
}
