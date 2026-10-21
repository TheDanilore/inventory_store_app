import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_date_range_picker_modal.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_state.dart';
import 'package:intl/intl.dart';

/// Barra de control unificada (filtros de estado, fecha y usuario) para
/// la pantalla de historial de turnos de caja.
class ShiftsControlToolbar extends StatelessWidget {
  final CashShiftsCubit cubit;
  final CashShiftsState state;
  final bool isDesktop;

  const ShiftsControlToolbar({
    super.key,
    required this.cubit,
    required this.state,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yy');

    String selectedUserName = 'Todos los usuarios';
    if (state.profileFilter != null) {
      final p =
          state.profiles
              .where((p) => p['id'] == state.profileFilter)
              .firstOrNull;
      if (p != null) {
        selectedUserName =
            (p['full_name'] as String?)?.trim().isNotEmpty == true
                ? p['full_name'] as String
                : 'Usuario sin nombre';
      }
    }

    final hasDateFilter = state.dateFrom != null || state.dateTo != null;
    final dateLabel =
        hasDateFilter
            ? '${state.dateFrom != null ? dateFormat.format(state.dateFrom!) : '…'} — ${state.dateTo != null ? dateFormat.format(state.dateTo!) : '…'}'
            : 'Fecha';

    Future<void> pickDateRange() async {
      final now = DateTime.now();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final maxDate = DateTime(now.year + 1, 12, 31);
      final picked = await AppDateRangePickerModal.show(
        context,
        firstDate: DateTime(2020),
        lastDate: maxDate,
        initialStartDate:
            (state.dateFrom != null)
                ? (state.dateFrom!.isBefore(DateTime(2020))
                    ? DateTime(2020)
                    : state.dateFrom!)
                : now.subtract(const Duration(days: 30)),
        initialEndDate:
            (state.dateTo != null)
                ? (state.dateTo!.isAfter(maxDate) ? maxDate : state.dateTo!)
                : todayEnd,
      );
      if (picked != null) {
        cubit.setDateRange(picked.start, picked.end);
      }
    }

    if (isDesktop) {
      return _DesktopToolbar(
        cubit: cubit,
        state: state,
        theme: theme,
        hasDateFilter: hasDateFilter,
        dateLabel: dateLabel,
        selectedUserName: selectedUserName,
        pickDateRange: pickDateRange,
      );
    }

    return _MobileToolbar(
      cubit: cubit,
      state: state,
      theme: theme,
      hasDateFilter: hasDateFilter,
      dateLabel: dateLabel,
      selectedUserName: selectedUserName,
      pickDateRange: pickDateRange,
    );
  }
}

// ── Desktop Toolbar ───────────────────────────────────────────────────────────
class _DesktopToolbar extends StatelessWidget {
  final CashShiftsCubit cubit;
  final CashShiftsState state;
  final ThemeData theme;
  final bool hasDateFilter;
  final String dateLabel;
  final String selectedUserName;
  final VoidCallback pickDateRange;

  const _DesktopToolbar({
    required this.cubit,
    required this.state,
    required this.theme,
    required this.hasDateFilter,
    required this.dateLabel,
    required this.selectedUserName,
    required this.pickDateRange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.4),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatusChip(
            cubit: cubit,
            state: state,
            status: 'Todos',
            label: 'Todos',
          ),
          const SizedBox(width: 6),
          _StatusChip(
            cubit: cubit,
            state: state,
            status: 'OPEN',
            label: 'Abiertos',
          ),
          const SizedBox(width: 6),
          _StatusChip(
            cubit: cubit,
            state: state,
            status: 'CLOSED',
            label: 'Cerrados',
          ),
          const SizedBox(width: 14),
          _Divider(),
          const SizedBox(width: 14),
          _DateRangeButton(
            hasDateFilter: hasDateFilter,
            dateLabel: dateLabel,
            onTap: pickDateRange,
            theme: theme,
          ),
          if (hasDateFilter) ...[
            const SizedBox(width: 2),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 14),
              tooltip: 'Limpiar filtro de fecha',
              visualDensity: VisualDensity.compact,
              onPressed: () => cubit.setDateRange(null, null),
            ),
          ],
          const SizedBox(width: 12),
          _Divider(),
          const SizedBox(width: 12),
          // Filtro de usuario solo visible para quienes pueden ver usuarios
          PermissionGuard(
            anyPermissions: const [
              AppPermissions.usersView,
              AppPermissions.reportsView,
              AppPermissions.reportsFinancial,
            ],
            child: _UserFilterButton(
              cubit: cubit,
              state: state,
              selectedUserName: selectedUserName,
              theme: theme,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${state.shifts.length} de ${state.totalCount > 0 ? state.totalCount : state.shifts.length} registros',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile Toolbar ────────────────────────────────────────────────────────────
class _MobileToolbar extends StatelessWidget {
  final CashShiftsCubit cubit;
  final CashShiftsState state;
  final ThemeData theme;
  final bool hasDateFilter;
  final String dateLabel;
  final String selectedUserName;
  final VoidCallback pickDateRange;

  const _MobileToolbar({
    required this.cubit,
    required this.state,
    required this.theme,
    required this.hasDateFilter,
    required this.dateLabel,
    required this.selectedUserName,
    required this.pickDateRange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusChip(
                  cubit: cubit,
                  state: state,
                  status: 'Todos',
                  label: 'Todos',
                ),
                const SizedBox(width: 6),
                _StatusChip(
                  cubit: cubit,
                  state: state,
                  status: 'OPEN',
                  label: 'Abiertos',
                ),
                const SizedBox(width: 6),
                _StatusChip(
                  cubit: cubit,
                  state: state,
                  status: 'CLOSED',
                  label: 'Cerrados',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: pickDateRange,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:
                    hasDateFilter
                        ? AppColors.primary.withValues(alpha: 0.07)
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      hasDateFilter
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : theme.dividerColor.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color:
                        hasDateFilter
                            ? AppColors.primary
                            : AppColors.textSecondary,
                    size: 17,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasDateFilter ? dateLabel : 'Filtrar por fecha',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            hasDateFilter ? FontWeight.w700 : FontWeight.w600,
                        color:
                            hasDateFilter
                                ? AppColors.primary
                                : theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasDateFilter)
                    GestureDetector(
                      onTap: () => cubit.setDateRange(null, null),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Filtro de usuario solo visible para quienes pueden ver usuarios
          PermissionGuard(
            anyPermissions: const [
              AppPermissions.usersView,
              AppPermissions.reportsView,
              AppPermissions.reportsFinancial,
            ],
            child: _UserFilterButton(
              cubit: cubit,
              state: state,
              selectedUserName: selectedUserName,
              theme: theme,
              isMobile: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final CashShiftsCubit cubit;
  final CashShiftsState state;
  final String status;
  final String label;

  const _StatusChip({
    required this.cubit,
    required this.state,
    required this.status,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = state.filterStatus == status;
    return InkWell(
      onTap: () => cubit.setFilterStatus(status),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.primary
                    : Theme.of(context).dividerColor.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color:
                isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  final bool hasDateFilter;
  final String dateLabel;
  final VoidCallback onTap;
  final ThemeData theme;

  const _DateRangeButton({
    required this.hasDateFilter,
    required this.dateLabel,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color:
              hasDateFilter
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                hasDateFilter
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : theme.dividerColor.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 15,
              color:
                  hasDateFilter ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              dateLabel,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: hasDateFilter ? FontWeight.w700 : FontWeight.w500,
                color:
                    hasDateFilter
                        ? AppColors.primary
                        : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color:
                  hasDateFilter ? AppColors.primary : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón compacto de selector de usuario con soporte para modal desktop/mobile.
class _UserFilterButton extends StatelessWidget {
  final CashShiftsCubit cubit;
  final CashShiftsState state;
  final String selectedUserName;
  final ThemeData theme;
  final bool isMobile;

  const _UserFilterButton({
    required this.cubit,
    required this.state,
    required this.selectedUserName,
    required this.theme,
    this.isMobile = false,
  });

  void _showUserPicker(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    if (isDesktop) {
      showDialog(
        context: context,
        builder:
            (dialogCtx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.group_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Filtrar por Usuario',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                height: 320,
                child: _UserOptionList(cubit: cubit, state: state),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (ctx) => DraggableScrollableSheet(
              initialChildSize: 0.55,
              minChildSize: 0.35,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                return Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Filtrar por Usuario',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _UserOptionList(
                          cubit: cubit,
                          state: state,
                          scrollController: scrollController,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = state.profileFilter != null;

    if (isMobile) {
      return InkWell(
        onTap: () => _showUserPicker(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? Icons.person_rounded : Icons.group_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.isLoadingProfiles
                      ? 'Cargando usuarios...'
                      : selectedUserName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _showUserPicker(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  isActive
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    isActive
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : theme.dividerColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.person_rounded : Icons.group_rounded,
                  size: 16,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    state.isLoadingProfiles ? 'Cargando...' : selectedUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color:
                          isActive
                              ? AppColors.primary
                              : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (isActive) ...[
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: 'Limpiar filtro de usuario',
            visualDensity: VisualDensity.compact,
            onPressed: () => cubit.setProfileFilter(null),
          ),
        ],
      ],
    );
  }
}

class _UserOptionList extends StatelessWidget {
  final CashShiftsCubit cubit;
  final CashShiftsState state;
  final ScrollController? scrollController;

  const _UserOptionList({
    required this.cubit,
    required this.state,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        _UserOption(
          cubit: cubit,
          state: state,
          title: 'Todos los usuarios',
          value: null,
          icon: Icons.group_rounded,
        ),
        const Divider(height: 16),
        ...state.profiles.map(
          (p) => _UserOption(
            cubit: cubit,
            state: state,
            title:
                (p['full_name'] as String?)?.trim().isNotEmpty == true
                    ? p['full_name'] as String
                    : 'Usuario sin nombre',
            value: p['id'] as String,
            icon: Icons.person_rounded,
          ),
        ),
      ],
    );
  }
}

class _UserOption extends StatelessWidget {
  final CashShiftsCubit cubit;
  final CashShiftsState state;
  final String title;
  final String? value;
  final IconData icon;

  const _UserOption({
    required this.cubit,
    required this.state,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = state.profileFilter == value;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: () {
        cubit.setProfileFilter(value);
        Navigator.pop(context);
      },
      leading: CircleAvatar(
        radius: 18,
        backgroundColor:
            isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : colorScheme.surfaceContainerHighest,
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? AppColors.primary : colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? AppColors.primary : colorScheme.onSurface,
        ),
      ),
      trailing:
          isSelected
              ? const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              )
              : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isSelected ? AppColors.primary.withValues(alpha: 0.05) : null,
    );
  }
}
