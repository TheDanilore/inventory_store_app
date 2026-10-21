import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/widgets/app_date_range_picker_modal.dart';
import 'package:vibration/vibration.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_time_filter.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Barra de contexto ejecutiva con título, selector de rango de fechas estilo Shopeers,
/// botón de personalización de widgets, recarga y exportación protegida con permisos.
class DashboardExecutiveSubheader extends StatelessWidget {
  final DashboardLoaded state;
  final bool isDesktop;
  final int visibleWidgetsCount;
  final VoidCallback onOpenAddWidgetSheet;
  final VoidCallback onExportReport;

  const DashboardExecutiveSubheader({
    super.key,
    required this.state,
    required this.isDesktop,
    required this.visibleWidgetsCount,
    required this.onOpenAddWidgetSheet,
    required this.onExportReport,
  });

  Future<void> _openCustomDatePicker(
    BuildContext context,
    DashboardLoaded state,
  ) async {
    final now = DateTime.now();
    final picked = await AppDateRangePickerModal.show(
      context,
      initialStartDate:
          state.customStartDate ?? now.subtract(const Duration(days: 7)),
      initialEndDate: state.customEndDate ?? now,
      firstDate: DateTime(2022),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      if (!kIsWeb) {
        Vibration.vibrate(duration: 30, amplitude: 64);
      }
      if (context.mounted) {
        context.read<DashboardCubit>().updateSalesFilter(
          SalesTimeFilter.custom,
          customStartDate: picked.start,
          customEndDate: picked.end,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDesktop) {
      // ── MÓVIL: DISEÑO SIMÉTRICO EN 2 FILAS SHOPEERS ─────────────────────────
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila 1: Título y Botón Exportar (con PermissionGuard)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color:
                          isDark
                              ? const Color(0xFFF8FAFC)
                              : const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Métricas en tiempo real',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              PermissionGuard(
                permission: AppPermissions.reportsExport,
                child: SizedBox(
                  height: 34,
                  child: FilledButton.icon(
                    onPressed: onExportReport,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                    label: const Text('Exportar'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Fila 2: Cápsula de Fecha Shopeers + Botón +Widget
          Row(
            children: [
              Expanded(
                child: _buildShopeersDateRangePill(
                  context,
                  state,
                  isDesktop: false,
                ),
              ),
              const SizedBox(width: 8),

              // Botón Añadir Widget en móvil
              InkWell(
                onTap: onOpenAddWidgetSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkSurfaceElevated : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Widget ($visibleWidgetsCount)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark
                                  ? const Color(0xFFF8FAFC)
                                  : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // ── DESKTOP / TABLET: FILA ÚNICA CON ALTURA 38DP Y RADIO 10DP ─────────────
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Screen Title & Subtitle
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color:
                    isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Métricas clave de rendimiento y control en tiempo real',
              style: TextStyle(
                fontSize: 13,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        // Right: Shopeers Date Range Composite Pill + Actions
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildShopeersDateRangePill(context, state, isDesktop: true),
            const SizedBox(width: 10),

            // Botón Añadir Widget
            Tooltip(
              message: 'Personalizar widgets del dashboard (Atajo: W)',
              child: SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: onOpenAddWidgetSheet,
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        isDark ? AppColors.darkSurfaceElevated : Colors.white,
                    foregroundColor:
                        isDark
                            ? const Color(0xFFF8FAFC)
                            : const Color(0xFF0F172A),
                    side: BorderSide(
                      color:
                          isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(
                    Icons.widgets_outlined,
                    size: 15,
                    color: Color(0xFF2563EB),
                  ),
                  label: Text(
                    'Widgets ($visibleWidgetsCount/7)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Reload Button with Shortcut Hint
            Tooltip(
              message: 'Recargar métricas (Atajo: R)',
              child: SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (!kIsWeb) {
                      Vibration.vibrate(duration: 30, amplitude: 60);
                    }
                    context.read<DashboardCubit>().refresh();
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        isDark ? AppColors.darkSurfaceElevated : Colors.white,
                    foregroundColor:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                    side: BorderSide(
                      color:
                          isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 15,
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                  ),
                  label: const Text(
                    'Actualizar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

            // Botón Exportar Reporte con PermissionGuard
            PermissionGuard(
              permission: AppPermissions.reportsExport,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    onPressed: onExportReport,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.arrow_downward_rounded, size: 15),
                    label: const Text('Exportar'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShopeersDateRangePill(
    BuildContext context,
    DashboardLoaded state, {
    required bool isDesktop,
  }) {
    final now = DateTime.now();
    String rangeLabel = '';
    String presetLabel = '';

    switch (state.salesFilter) {
      case SalesTimeFilter.today:
        rangeLabel = DateFormat('d MMM, yyyy', 'es').format(now);
        presetLabel = 'Hoy';
        break;
      case SalesTimeFilter.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        rangeLabel =
            '${DateFormat('d MMM', 'es').format(startOfWeek)} - ${DateFormat('d MMM, yyyy', 'es').format(endOfWeek)}';
        presetLabel = isDesktop ? 'Esta semana' : 'Semana';
        break;
      case SalesTimeFilter.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        final nextMonth =
            now.month == 12
                ? DateTime(now.year + 1, 1, 1)
                : DateTime(now.year, now.month + 1, 1);
        final endOfMonth = nextMonth.subtract(const Duration(days: 1));
        rangeLabel =
            '${DateFormat('d MMM', 'es').format(startOfMonth)} - ${DateFormat('d MMM, yyyy', 'es').format(endOfMonth)}';
        presetLabel = isDesktop ? 'Este mes' : 'Mes';
        break;
      case SalesTimeFilter.allTime:
        rangeLabel = 'Todo el histórico';
        presetLabel = isDesktop ? 'Histórico' : 'Hist';
        break;
      case SalesTimeFilter.custom:
        if (state.customStartDate != null && state.customEndDate != null) {
          rangeLabel =
              '${DateFormat('d MMM', 'es').format(state.customStartDate!)} - ${DateFormat('d MMM, yyyy', 'es').format(state.customEndDate!)}';
        } else {
          rangeLabel = 'Personalizado';
        }
        presetLabel = isDesktop ? 'Personalizado' : 'Pers';
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: isDesktop ? 38 : 34,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
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
      child: Row(
        mainAxisSize: isDesktop ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Left: Calendar Picker Trigger
          if (isDesktop)
            InkWell(
              onTap: () => _openCustomDatePicker(context, state),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.isSalesLoading)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2563EB),
                          ),
                        ),
                      )
                    else
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      rangeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark
                                ? const Color(0xFFF8FAFC)
                                : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: InkWell(
                onTap: () => _openCustomDatePicker(context, state),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      if (state.isSalesLoading)
                        const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF2563EB),
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: Color(0xFF64748B),
                        ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rangeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? const Color(0xFFF8FAFC)
                                    : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Divider
          Container(
            width: 1,
            height: isDesktop ? 18 : 16,
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          ),

          // Right: Presets Dropdown
          PopupMenuButton<SalesTimeFilter>(
            tooltip: 'Filtro por fecha (Atajos: 1-4)',
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            color: isDark ? AppColors.darkSurface : Colors.white,
            elevation: 8,
            onSelected: (filter) {
              if (filter == SalesTimeFilter.custom) {
                _openCustomDatePicker(context, state);
              } else {
                if (!kIsWeb) {
                  Vibration.vibrate(duration: 30, amplitude: 64);
                }
                context.read<DashboardCubit>().updateSalesFilter(filter);
              }
            },
            itemBuilder:
                (context) => [
                  _buildFilterMenuItem(
                    value: SalesTimeFilter.today,
                    label: 'Hoy',
                    shortcut: '1',
                    isSelected: state.salesFilter == SalesTimeFilter.today,
                    isDark: isDark,
                  ),
                  _buildFilterMenuItem(
                    value: SalesTimeFilter.thisWeek,
                    label: 'Esta semana',
                    shortcut: '2',
                    isSelected: state.salesFilter == SalesTimeFilter.thisWeek,
                    isDark: isDark,
                  ),
                  _buildFilterMenuItem(
                    value: SalesTimeFilter.thisMonth,
                    label: 'Este mes',
                    shortcut: '3',
                    isSelected: state.salesFilter == SalesTimeFilter.thisMonth,
                    isDark: isDark,
                  ),
                  _buildFilterMenuItem(
                    value: SalesTimeFilter.allTime,
                    label: 'Histórico',
                    shortcut: '4',
                    isSelected: state.salesFilter == SalesTimeFilter.allTime,
                    isDark: isDark,
                  ),
                  const PopupMenuDivider(height: 1),
                  _buildFilterMenuItem(
                    value: SalesTimeFilter.custom,
                    label: 'Personalizado...',
                    icon: Icons.date_range_outlined,
                    isSelected: state.salesFilter == SalesTimeFilter.custom,
                    isDark: isDark,
                  ),
                ],
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 10 : 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    presetLabel,
                    style: TextStyle(
                      fontSize: isDesktop ? 12 : 11,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark
                              ? const Color(0xFFF8FAFC)
                              : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<SalesTimeFilter> _buildFilterMenuItem({
    required SalesTimeFilter value,
    required String label,
    String? shortcut,
    IconData? icon,
    required bool isSelected,
    bool isDark = false,
  }) {
    return PopupMenuItem<SalesTimeFilter>(
      value: value,
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color:
                      isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isSelected
                          ? const Color(0xFF2563EB)
                          : (isDark
                              ? const Color(0xFFF8FAFC)
                              : const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          if (shortcut != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                shortcut,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          if (isSelected && shortcut == null)
            const Icon(Icons.check_rounded, size: 16, color: Color(0xFF2563EB)),
        ],
      ),
    );
  }
}
