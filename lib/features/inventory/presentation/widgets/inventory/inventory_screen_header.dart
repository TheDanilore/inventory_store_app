import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_breakpoints.dart';

/// Barra superior camaleónica y multi-dispositivo para Control de Inventario.
/// Gestiona pestañas segmentadas, selector de almacén, indicador de salud de lotes
/// y botones de exportación / refresco rápido.
class AdaptiveInventoryHeader extends StatelessWidget {
  final TabController tabController;
  final InventoryLoaded? loadedState;
  final int urgentCount;
  final VoidCallback onOpenExport;
  final VoidCallback onOpenWarehousePickerMobile;

  const AdaptiveInventoryHeader({
    super.key,
    required this.tabController,
    required this.loadedState,
    required this.urgentCount,
    required this.onOpenExport,
    required this.onOpenWarehousePickerMobile,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color:
                isDark
                    ? AppColors.darkBorder
                    : AppColors.border.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < InventoryBreakpoints.mobile;
          final isDesktop = constraints.maxWidth >= InventoryBreakpoints.split;

          final tabBarWidget = SegmentedTabs(
            controller: tabController,
            urgentCount: urgentCount,
            isDesktop: isDesktop,
            isMobile: isMobile,
          );

          final warehouseSelector =
              isMobile
                  ? MobileWarehouseSelectorButton(
                    selectedName:
                        loadedState?.selectedWarehouseName ??
                        'Todos los almacenes',
                    isSelected:
                        loadedState?.selectedWarehouseId != null &&
                        loadedState!.selectedWarehouseId!.isNotEmpty,
                    onTap: onOpenWarehousePickerMobile,
                  )
                  : DesktopWarehouseDropdown(state: loadedState);

          final exportButton = AdaptiveExportButton(
            onPressed: onOpenExport,
            isCompact: isMobile,
          );

          final refreshButton = QuickRefreshButton(
            onPressed: () {
              context.read<InventoryCubit>().refreshAll();
              AppSnackbar.show(
                context,
                message: 'Actualizando catálogo de inventario...',
                type: SnackbarType.info,
                duration: const Duration(seconds: 2),
              );
            },
          );

          // Diseño Móvil: 2 filas ergonómicas con targets táctiles amplios
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tabBarWidget,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: warehouseSelector),
                    const SizedBox(width: 8),
                    exportButton,
                    const SizedBox(width: 6),
                    refreshButton,
                  ],
                ),
              ],
            );
          }

          // Diseño Tablet y Desktop: Barra lineal horizontal con salud de lotes integrada
          return Row(
            children: [
              tabBarWidget,
              if (urgentCount > 0 && !isMobile) ...[
                const SizedBox(width: 12),
                HealthUrgentBadge(
                  urgentCount: urgentCount,
                  onTap: () {
                    if (tabController.index != 1) {
                      tabController.animateTo(1);
                    }
                  },
                ),
              ],
              const Spacer(),
              warehouseSelector,
              const SizedBox(width: 10),
              exportButton,
              const SizedBox(width: 6),
              refreshButton,
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── PESTAÑAS SEGMENTADAS (LINEAR / STRIPE STYLE) ─────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class SegmentedTabs extends StatelessWidget {
  final TabController controller;
  final int urgentCount;
  final bool isDesktop;
  final bool isMobile;

  const SegmentedTabs({
    super.key,
    required this.controller,
    required this.urgentCount,
    required this.isDesktop,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: BoxConstraints(
        maxWidth: isMobile ? double.infinity : (isDesktop ? 460 : 410),
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow:
              isDark
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                  : AppColors.cardShadow(opacity: 0.05),
          border: Border.all(
            color:
                isDark
                    ? AppColors.darkBorder
                    : AppColors.border.withValues(alpha: 0.6),
          ),
        ),
        dividerColor: Colors.transparent,
        labelColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        unselectedLabelColor:
            isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.1,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: [
          const Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_rounded, size: 16),
                SizedBox(width: 8),
                Text('Stock General'),
              ],
            ),
          ),
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_busy_rounded, size: 16),
                const SizedBox(width: 8),
                const Text('Estado de Lotes'),
                if (urgentCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$urgentCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── CHIP DE SALUD DE LOTES (PUENTE ENTRE VISTAS) ─────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class HealthUrgentBadge extends StatefulWidget {
  final int urgentCount;
  final VoidCallback onTap;

  const HealthUrgentBadge({
    super.key,
    required this.urgentCount,
    required this.onTap,
  });

  @override
  State<HealthUrgentBadge> createState() => _HealthUrgentBadgeState();
}

class _HealthUrgentBadgeState extends State<HealthUrgentBadge> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'Hay ${widget.urgentCount} lotes que requieren retiro o revisión urgente',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color:
                  _isHovered
                      ? AppColors.danger.withValues(alpha: 0.14)
                      : AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    _isHovered
                        ? AppColors.danger
                        : AppColors.danger.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.urgentCount} lotes críticos',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: AppColors.danger,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── SELECTOR DE ALMACÉN DESKTOP / TABLET (DROPDOWN REFINADO) ──────────────────
// ─────────────────────────────────────────────────────────────────────────────

class DesktopWarehouseDropdown extends StatefulWidget {
  final InventoryLoaded? state;

  const DesktopWarehouseDropdown({super.key, this.state});

  @override
  State<DesktopWarehouseDropdown> createState() =>
      _DesktopWarehouseDropdownState();
}

class _DesktopWarehouseDropdownState extends State<DesktopWarehouseDropdown> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warehouses = widget.state?.warehouses ?? [];
    final selectedId = widget.state?.selectedWarehouseId;
    final isSelected = selectedId != null && selectedId.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.04))
                  : (_isHovered
                      ? (isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.surfaceDark)
                      : (isDark
                          ? AppColors.darkSurface
                          : AppColors.background)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : (_isHovered
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : (isDark ? AppColors.darkBorder : AppColors.border)),
          ),
          boxShadow: AppColors.cardShadow(opacity: 0.02),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warehouse_rounded,
              size: 17,
              color:
                  isSelected
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            Text(
              'Almacén:',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selectedId,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                  size: 19,
                ),
                borderRadius: BorderRadius.circular(10),
                dropdownColor:
                    isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Todos los almacenes',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...warehouses.map((wh) {
                    return DropdownMenuItem<String?>(
                      value: wh.id,
                      child: Text(
                        wh.name,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                ],
                onChanged: (newWarehouseId) {
                  String whName = 'Todos los almacenes';
                  if (newWarehouseId != null) {
                    final found = warehouses.where(
                      (w) => w.id == newWarehouseId,
                    );
                    if (found.isNotEmpty) {
                      whName = found.first.name;
                    }
                  }
                  context.read<InventoryCubit>().setWarehouseFilter(
                    newWarehouseId,
                    whName,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── SELECTOR DE ALMACÉN MÓVIL (APPLE HIG BOTÓN TÁCTIL) ────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class MobileWarehouseSelectorButton extends StatelessWidget {
  final String selectedName;
  final bool isSelected;
  final VoidCallback onTap;

  const MobileWarehouseSelectorButton({
    super.key,
    required this.selectedName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44, // Target táctil ergonómico de 44-48dp
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.05))
                  : (isDark ? AppColors.darkSurface : AppColors.background),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warehouse_rounded,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── BOTÓN DE EXPORTACIÓN ADAPTATIVO ──────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class AdaptiveExportButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isCompact;

  const AdaptiveExportButton({
    super.key,
    required this.onPressed,
    this.isCompact = false,
  });

  @override
  State<AdaptiveExportButton> createState() => _AdaptiveExportButtonState();
}

class _AdaptiveExportButtonState extends State<AdaptiveExportButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'Exportar Inventario a Excel (Ctrl + E o presiona E)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCompact ? 12 : 14,
            ),
            decoration: BoxDecoration(
              color:
                  _isHovered
                      ? AppColors.teal.withValues(alpha: 0.15)
                      : (isDark ? AppColors.darkSurface : AppColors.background),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    _isHovered
                        ? AppColors.teal
                        : (isDark ? AppColors.darkBorder : AppColors.border),
              ),
              boxShadow: AppColors.cardShadow(opacity: 0.02),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.table_view_rounded,
                  size: 17,
                  color: AppColors.teal,
                ),
                if (!widget.isCompact) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Exportar Excel',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── BOTÓN DE RECARGA RÁPIDA (FEEDBACK PRO) ───────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class QuickRefreshButton extends StatefulWidget {
  final VoidCallback onPressed;

  const QuickRefreshButton({super.key, required this.onPressed});

  @override
  State<QuickRefreshButton> createState() => _QuickRefreshButtonState();
}

class _QuickRefreshButtonState extends State<QuickRefreshButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'Recargar existencias y lotes (presiona R)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color:
                  _isHovered
                      ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08)
                      : (isDark ? AppColors.darkSurface : AppColors.background),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    _isHovered
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : (isDark ? AppColors.darkBorder : AppColors.border),
              ),
              boxShadow: AppColors.cardShadow(opacity: 0.02),
            ),
            child: Icon(
              Icons.refresh_rounded,
              size: 18,
              color:
                  _isHovered
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
