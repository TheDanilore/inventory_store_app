import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_state.dart';

/// Píldora individual de filtro.
class KardexFilterPill extends StatelessWidget {
  final String label;
  final String? shortcut;
  final bool isSelected;
  final VoidCallback onTap;

  const KardexFilterPill({
    super.key,
    required this.label,
    this.shortcut,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            if (shortcut != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 0.5,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  shortcut!,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color:
                        isSelected ? AppColors.primary : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila horizontal de filtros por tipo de operación (Ingresos, Salidas, Ventas, Devoluciones)
/// optimizada con `BlocSelector` para prevenir rebuilds de toda la barra.
class KardexTypeFilterRow extends StatelessWidget {
  const KardexTypeFilterRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Filtrar tipo:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        BlocSelector<KardexCubit, KardexState, String>(
          selector: (state) => state is KardexLoaded ? state.typeFilter : 'ALL',
          builder: (context, typeFilter) {
            final cubit = context.read<KardexCubit>();
            return Wrap(
              spacing: 6,
              children: [
                KardexFilterPill(
                  label: 'Todos',
                  shortcut: '1',
                  isSelected: typeFilter == 'ALL',
                  onTap: () => cubit.setTypeFilter('ALL'),
                ),
                KardexFilterPill(
                  label: 'Ingresos',
                  shortcut: '2',
                  isSelected: typeFilter == 'ENTRY',
                  onTap: () => cubit.setTypeFilter('ENTRY'),
                ),
                KardexFilterPill(
                  label: 'Salidas',
                  shortcut: '3',
                  isSelected: typeFilter == 'EXIT',
                  onTap: () => cubit.setTypeFilter('EXIT'),
                ),
                KardexFilterPill(
                  label: 'Ventas',
                  shortcut: '4',
                  isSelected: typeFilter == 'SALE',
                  onTap: () => cubit.setTypeFilter('SALE'),
                ),
                KardexFilterPill(
                  label: 'Devoluciones',
                  shortcut: '5',
                  isSelected: typeFilter == 'RETURN',
                  onTap: () => cubit.setTypeFilter('RETURN'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
