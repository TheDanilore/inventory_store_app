import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_active_warehouses_usecase.dart';

/// Pill interactivo moderno para filtrar métricas del Dashboard por Almacén.
/// Por defecto muestra "Todos (Global)", y permite filtrar por un almacén activo específico.
class DashboardWarehouseFilterPill extends StatefulWidget {
  final DashboardLoaded state;
  final bool isDesktop;

  const DashboardWarehouseFilterPill({
    super.key,
    required this.state,
    this.isDesktop = true,
  });

  @override
  State<DashboardWarehouseFilterPill> createState() =>
      _DashboardWarehouseFilterPillState();
}

class _DashboardWarehouseFilterPillState
    extends State<DashboardWarehouseFilterPill> {
  List<WarehouseEntity> _warehouses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    try {
      final useCase = sl<GetActiveWarehousesUseCase>();
      final warehouses = await useCase();
      if (!mounted) return;
      setState(() {
        _warehouses = warehouses;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedId = widget.state.selectedWarehouseId;
    final isFiltered = selectedId != null;

    final String displayLabel;
    if (isFiltered) {
      final match = _warehouses.where((w) => w.id == selectedId).firstOrNull;
      displayLabel =
          match?.name ?? widget.state.selectedWarehouseName ?? 'Almacén';
    } else {
      displayLabel = widget.isDesktop ? 'Todos los Almacenes' : 'Global';
    }

    final Color activeBorder =
        isFiltered
            ? AppColors.primary
            : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0));
    final Color activeBg =
        isFiltered
            ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08)
            : (isDark ? AppColors.darkSurfaceElevated : Colors.white);

    return Container(
      height: widget.isDesktop ? 38 : 34,
      decoration: BoxDecoration(
        color: activeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: activeBorder, width: isFiltered ? 1.4 : 1),
        boxShadow:
            isDark
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
      ),
      child: PopupMenuButton<String?>(
        tooltip: 'Filtrar por almacén',
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          ),
        ),
        color: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 8,
        onSelected: (id) {
          AppFeedbackService.lightImpact();
          if (id == null) {
            context.read<DashboardCubit>().updateWarehouseFilter(
              warehouseId: null,
              warehouseName: null,
            );
          } else {
            final w =
                _warehouses.where((element) => element.id == id).firstOrNull;
            context.read<DashboardCubit>().updateWarehouseFilter(
              warehouseId: id,
              warehouseName: w?.name,
            );
          }
        },
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String?>>[
            PopupMenuItem<String?>(
              value: null,
              height: 38,
              child: Row(
                children: [
                  const Icon(
                    Icons.public_rounded,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Todos los Almacenes (Global)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            selectedId == null
                                ? FontWeight.w700
                                : FontWeight.w500,
                        color:
                            selectedId == null
                                ? const Color(0xFF2563EB)
                                : (isDark
                                    ? const Color(0xFFF8FAFC)
                                    : const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                  if (selectedId == null)
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                ],
              ),
            ),
          ];

          if (_warehouses.isNotEmpty) {
            items.add(const PopupMenuDivider(height: 1));
            for (final w in _warehouses) {
              final isThisSelected = selectedId == w.id;
              items.add(
                PopupMenuItem<String?>(
                  value: w.id,
                  height: 38,
                  child: Row(
                    children: [
                      Icon(
                        Icons.warehouse_rounded,
                        size: 16,
                        color:
                            isThisSelected
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          w.name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isThisSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                            color:
                                isThisSelected
                                    ? const Color(0xFF2563EB)
                                    : (isDark
                                        ? const Color(0xFFF8FAFC)
                                        : const Color(0xFF0F172A)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isThisSelected)
                        const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                    ],
                  ),
                ),
              );
            }
          }

          return items;
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.isDesktop ? 10 : 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                )
              else
                Icon(
                  isFiltered ? Icons.warehouse_rounded : Icons.public_rounded,
                  size: 14,
                  color:
                      isFiltered ? AppColors.primary : const Color(0xFF64748B),
                ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  displayLabel,
                  style: TextStyle(
                    fontSize: widget.isDesktop ? 12 : 11,
                    fontWeight: isFiltered ? FontWeight.w700 : FontWeight.w600,
                    color:
                        isFiltered
                            ? (isDark ? Colors.white : AppColors.primary)
                            : (isDark
                                ? const Color(0xFFF8FAFC)
                                : const Color(0xFF0F172A)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              if (isFiltered)
                InkWell(
                  onTap: () {
                    AppFeedbackService.lightImpact();
                    context.read<DashboardCubit>().updateWarehouseFilter(
                      warehouseId: null,
                      warehouseName: null,
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isDark ? Colors.white70 : AppColors.primary,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: Color(0xFF64748B),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
