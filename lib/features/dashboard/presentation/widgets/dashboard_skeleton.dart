import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

/// Esqueleto de carga con espejado milimétrico del Dashboard para eliminar el Cumulative Layout Shift (CLS = 0).
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1100;
        final isTablet = constraints.maxWidth >= 720;

        if (isDesktop) {
          return _buildDesktopSkeleton();
        }
        if (isTablet) {
          return _buildTabletSkeleton();
        }
        return _buildMobileSkeleton();
      },
    );
  }

  Widget _buildDesktopSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Banner Ejecutivo de Bienvenida
        const AppShimmer(width: double.infinity, height: 104, borderRadius: 24),
        const SizedBox(height: 18),

        // 2. Health summary bar
        const AppShimmer(width: double.infinity, height: 48, borderRadius: 16),
        const SizedBox(height: 16),

        // 3. Subheader Ejecutivo (Filtros de Almacén, Tiempo y Botones de Acción)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                AppShimmer(width: 170, height: 36, borderRadius: 20),
                SizedBox(width: 12),
                AppShimmer(width: 280, height: 36, borderRadius: 20),
              ],
            ),
            Row(
              children: const [
                AppShimmer(width: 140, height: 36, borderRadius: 12),
                SizedBox(width: 10),
                AppShimmer(width: 100, height: 36, borderRadius: 12),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 4. Franja de los 4 KPIs principales
        Row(
          children: const [
            Expanded(child: AppShimmer(height: 105, borderRadius: 18)),
            SizedBox(width: 14),
            Expanded(child: AppShimmer(height: 105, borderRadius: 18)),
            SizedBox(width: 14),
            Expanded(child: AppShimmer(height: 105, borderRadius: 18)),
            SizedBox(width: 14),
            Expanded(child: AppShimmer(height: 105, borderRadius: 18)),
          ],
        ),
        const SizedBox(height: 24),

        // 5. Bento Grid en 2 columnas (espejo exacto del diseño cargado)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Columna Izquierda (Ventas, Best Sellers, Top Clientes)
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  AppShimmer(
                    width: double.infinity,
                    height: 340,
                    borderRadius: 20,
                  ),
                  SizedBox(height: 20),
                  AppShimmer(
                    width: double.infinity,
                    height: 280,
                    borderRadius: 20,
                  ),
                  SizedBox(height: 20),
                  AppShimmer(
                    width: double.infinity,
                    height: 260,
                    borderRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),

            // Columna Derecha (Actividad semanal, Meta Radial, Lotes Críticos)
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  AppShimmer(
                    width: double.infinity,
                    height: 290,
                    borderRadius: 20,
                  ),
                  SizedBox(height: 20),
                  AppShimmer(
                    width: double.infinity,
                    height: 240,
                    borderRadius: 20,
                  ),
                  SizedBox(height: 20),
                  AppShimmer(
                    width: double.infinity,
                    height: 240,
                    borderRadius: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabletSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner
        const AppShimmer(width: double.infinity, height: 100, borderRadius: 22),
        const SizedBox(height: 16),

        // Health bar
        const AppShimmer(width: double.infinity, height: 46, borderRadius: 16),
        const SizedBox(height: 14),

        // Subheader
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            AppShimmer(width: 160, height: 34, borderRadius: 18),
            AppShimmer(width: 110, height: 34, borderRadius: 10),
          ],
        ),
        const SizedBox(height: 16),

        // 2x2 KPIs
        Row(
          children: const [
            Expanded(child: AppShimmer(height: 95, borderRadius: 16)),
            SizedBox(width: 12),
            Expanded(child: AppShimmer(height: 95, borderRadius: 16)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: AppShimmer(height: 95, borderRadius: 16)),
            SizedBox(width: 12),
            Expanded(child: AppShimmer(height: 95, borderRadius: 16)),
          ],
        ),
        const SizedBox(height: 20),

        // Bento Cards
        const AppShimmer(width: double.infinity, height: 310, borderRadius: 20),
        const SizedBox(height: 16),
        const AppShimmer(width: double.infinity, height: 260, borderRadius: 20),
        const SizedBox(height: 16),
        const AppShimmer(width: double.infinity, height: 230, borderRadius: 20),
      ],
    );
  }

  Widget _buildMobileSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner
        const AppShimmer(width: double.infinity, height: 112, borderRadius: 20),
        const SizedBox(height: 14),

        // Health bar
        const AppShimmer(width: double.infinity, height: 46, borderRadius: 14),
        const SizedBox(height: 14),

        // Subheader pill
        const AppShimmer(width: double.infinity, height: 36, borderRadius: 16),
        const SizedBox(height: 16),

        // 2x2 KPIs
        Row(
          children: const [
            Expanded(child: AppShimmer(height: 90, borderRadius: 16)),
            SizedBox(width: 10),
            Expanded(child: AppShimmer(height: 90, borderRadius: 16)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(child: AppShimmer(height: 90, borderRadius: 16)),
            SizedBox(width: 10),
            Expanded(child: AppShimmer(height: 90, borderRadius: 16)),
          ],
        ),
        const SizedBox(height: 18),

        // Bento cards en columna móvil
        const AppShimmer(width: double.infinity, height: 260, borderRadius: 18),
        const SizedBox(height: 14),
        const AppShimmer(width: double.infinity, height: 220, borderRadius: 18),
        const SizedBox(height: 14),
        const AppShimmer(width: double.infinity, height: 200, borderRadius: 18),
      ],
    );
  }
}
