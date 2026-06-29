import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

/// Skeleton de alta fidelidad para simular tarjetas de producto mientras cargan.
class AdminProductSkeleton extends StatelessWidget {
  const AdminProductSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Simulación de Imagen
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppColors.radius),
              ),
              child: const AppShimmer(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0,
              ),
            ),
          ),
          
          // Simulación de Información y Botones
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Simulación Badge de Stock
                const AppShimmer(width: 60, height: 20, borderRadius: 6),
                const SizedBox(height: 10),
                
                // Simulación Título
                const AppShimmer(width: double.infinity, height: 12, borderRadius: 4),
                const SizedBox(height: 6),
                const AppShimmer(width: 130, height: 12, borderRadius: 4),
                const SizedBox(height: 12),
                
                // Simulación Precio
                const AppShimmer(width: 75, height: 16, borderRadius: 4),
                const SizedBox(height: 16),
                
                // Simulación Fila de Botones Inferiores
                Row(
                  children: [
                    const Expanded(
                      flex: 3,
                      child: AppShimmer(height: 36, borderRadius: 8),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      flex: 1,
                      child: AppShimmer(height: 36, borderRadius: 8),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      flex: 1,
                      child: AppShimmer(height: 36, borderRadius: 8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
