import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';

/// Skeleton Shimmer adaptativo de alta fidelidad para el módulo de Usuarios.
/// Se adapta automáticamente si está en modo Tabla Ejecutiva (Desktop)
/// o en modo Tarjetas (Móvil / Grid).
class UsersSkeleton extends StatelessWidget {
  final bool? isTableView;
  final int itemCount;

  const UsersSkeleton({super.key, this.isTableView, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 640;
    final showTable = isTableView ?? isDesktop;

    if (showTable) {
      return _buildTableSkeleton(context);
    }
    return _buildCardsSkeleton(context);
  }

  /// Shimmer en formato Tabla Pro con las mismas columnas que UsersTab:
  /// Checkbox | Usuario | Contacto | Documento | Roles | Estado | Acciones
  Widget _buildTableSkeleton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AppTableShimmer(
        minWidth: 960,
        showCheckbox: true,
        rowCount: itemCount.clamp(4, 10),
        columns: const [
          // 1. Usuario (Avatar + Nombre + Subtítulo)
          AppShimmerColumn(flex: 3, alignment: Alignment.centerLeft),
          // 2. Contacto (Email + Teléfono)
          AppShimmerColumn(flex: 3, alignment: Alignment.centerLeft),
          // 3. Documento (DNI/RUC)
          AppShimmerColumn(fixedWidth: 110, alignment: Alignment.centerLeft),
          // 4. Roles (Badge)
          AppShimmerColumn(fixedWidth: 130, alignment: Alignment.centerLeft),
          // 5. Estado (Pill + Switch)
          AppShimmerColumn(fixedWidth: 120, alignment: Alignment.centerLeft),
          // 6. Acciones (Ver, Editar, Más)
          AppShimmerColumn(fixedWidth: 124, alignment: Alignment.centerRight),
        ],
      ),
    );
  }

  /// Shimmer en formato Tarjetas Ejecutivas para Móvil o vista Grid.
  Widget _buildCardsSkeleton(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: itemCount.clamp(4, 8),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.1),
            boxShadow: AppColors.cardShadow(opacity: 0.03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila Superior: Avatar + Info Usuario + Badge Estado
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar circular
                  const AppShimmer(width: 44, height: 44, isCircular: true),
                  const SizedBox(width: 12),

                  // Nombre y Correo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmer(width: 140, height: 15, borderRadius: 6),
                        SizedBox(height: 6),
                        AppShimmer(width: 180, height: 12, borderRadius: 5),
                      ],
                    ),
                  ),

                  // Badge de estado Activo/Inactivo
                  const AppShimmer(width: 52, height: 20, borderRadius: 6),
                ],
              ),
              const SizedBox(height: 12),

              // Divisor sutil
              Container(height: 1, color: const Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // Fila Inferior: Chips de Rol, Almacén y Switch
              Row(
                children: [
                  // Rol Pill
                  const AppShimmer(width: 58, height: 22, borderRadius: 6),
                  const SizedBox(width: 8),

                  // Almacén Chip
                  const AppShimmer(width: 90, height: 22, borderRadius: 6),
                  const Spacer(),

                  // Switch de activación
                  const AppShimmer(width: 38, height: 20, borderRadius: 10),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
