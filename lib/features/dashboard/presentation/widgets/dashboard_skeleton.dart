import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Health summary bar ──────────────────────────────────────────
        AppShimmer(width: double.infinity, height: 52, borderRadius: 16),
        const SizedBox(height: 16),

        // ── Goal card ───────────────────────────────────────────────────
        AppShimmer(width: double.infinity, height: 116, borderRadius: 24),
        const SizedBox(height: 24),

        // ── Section Header: Inventario ──────────────────────────────────
        Row(
          children: [
            AppShimmer(width: 40, height: 40, borderRadius: 10),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmer(width: 120, height: 18, borderRadius: 4),
                const SizedBox(height: 6),
                AppShimmer(width: 200, height: 12, borderRadius: 4),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── KPI Cards row: Catálogo + Stock ─────────────────────────────
        Row(
          children: [
            Expanded(child: AppShimmer(height: 110, borderRadius: 20)),
            const SizedBox(width: 10),
            Expanded(child: AppShimmer(height: 110, borderRadius: 20)),
          ],
        ),
        const SizedBox(height: 10),

        // ── Valorización al público (wide) ──────────────────────────────
        AppShimmer(width: double.infinity, height: 84, borderRadius: 16),
        const SizedBox(height: 10),

        // ── Ganancia Bruta card ──────────────────────────────────────────
        AppShimmer(width: double.infinity, height: 130, borderRadius: 20),
        const SizedBox(height: 10),

        // ── G.Público + G.Mayorista row ──────────────────────────────────
        Row(
          children: [
            Expanded(child: AppShimmer(height: 110, borderRadius: 20)),
            const SizedBox(width: 10),
            Expanded(child: AppShimmer(height: 110, borderRadius: 20)),
          ],
        ),
        const SizedBox(height: 28),

        // ── Section Header: Ventas ──────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AppShimmer(width: 40, height: 40, borderRadius: 10),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppShimmer(width: 140, height: 18, borderRadius: 4),
                    const SizedBox(height: 6),
                    AppShimmer(width: 190, height: 12, borderRadius: 4),
                  ],
                ),
              ],
            ),
            // Filter chips placeholder
            AppShimmer(width: 200, height: 36, borderRadius: 12),
          ],
        ),
        const SizedBox(height: 14),

        // ── Ventas Totales + Ticket Promedio ────────────────────────────
        Row(
          children: [
            Expanded(flex: 2, child: AppShimmer(height: 110, borderRadius: 20)),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: AppShimmer(height: 110, borderRadius: 20)),
          ],
        ),
        const SizedBox(height: 10),

        // ── Ingresos Netos (wide) ───────────────────────────────────────
        AppShimmer(width: double.infinity, height: 84, borderRadius: 16),
        const SizedBox(height: 10),

        // ── Ganancia Bruta Ventas ───────────────────────────────────────
        AppShimmer(width: double.infinity, height: 130, borderRadius: 20),
      ],
    );
  }
}
