import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_state.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/close_shift_sheet.dart';

class AllCashShiftsScreen extends StatelessWidget {
  const AllCashShiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CashShiftsCubit>(
      create: (_) => sl<CashShiftsCubit>(),
      child: const _AllCashShiftsBody(),
    );
  }
}

class _AllCashShiftsBody extends StatefulWidget {
  const _AllCashShiftsBody();

  @override
  State<_AllCashShiftsBody> createState() => _AllCashShiftsBodyState();
}

class _AllCashShiftsBodyState extends State<_AllCashShiftsBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashShiftsCubit>().loadProfiles();
      context.read<CashShiftsCubit>().fetchShifts();
    });
  }

  Future<void> _handleCloseShift(CashShiftEntity shift) async {
    final cubit = context.read<CashShiftsCubit>();
    final expected = await cubit.calcExpected(
      shift.id,
      shift.accountId ?? '',
      shift.openingAmount,
    );
    if (!mounted) return;

    final success = await CloseShiftSheet.show(
      context,
      shift: shift,
      expectedAmount: expected,
    );
    if (success == true && mounted) {
      cubit.fetchShifts();
    }
  }

  void _showShiftDetailAdaptive(BuildContext context, CashShiftEntity shift) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (dialogCtx) => _ShiftDetailDialog(
          shift: shift,
          onCloseShift: shift.isOpen ? () {
            Navigator.pop(dialogCtx);
            _handleCloseShift(shift);
          } : null,
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => _ShiftDetailSheet(
          shift: shift,
          onCloseShift: shift.isOpen ? () {
            Navigator.pop(sheetCtx);
            _handleCloseShift(shift);
          } : null,
        ),
      );
    }
  }

  void _showUserPickerAdaptive(CashShiftsCubit cubit, CashShiftsState state) {
    if (state.isLoadingProfiles) return;

    final isDesktop = MediaQuery.of(context).size.width >= 720;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.group_rounded, color: AppColors.primary, size: 20),
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
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _buildUserOption(
                  cubit,
                  state,
                  title: 'Todos los usuarios',
                  value: null,
                  icon: Icons.group_rounded,
                ),
                const Divider(height: 16),
                ...state.profiles.map(
                  (p) => _buildUserOption(
                    cubit,
                    state,
                    title: p['full_name'] as String,
                    value: p['id'] as String,
                    icon: Icons.person_rounded,
                  ),
                ),
              ],
            ),
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
      _showUserPickerBottomSheet(cubit, state);
    }
  }

  void _showUserPickerBottomSheet(CashShiftsCubit cubit, CashShiftsState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Filtrar por Usuario',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        _buildUserOption(
                          cubit,
                          state,
                          title: 'Todos los usuarios',
                          value: null,
                          icon: Icons.group_rounded,
                        ),
                        const Divider(height: 20),
                        ...state.profiles.map(
                          (p) => _buildUserOption(
                            cubit,
                            state,
                            title: p['full_name'] as String,
                            value: p['id'] as String,
                            icon: Icons.person_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserOption(
    CashShiftsCubit cubit,
    CashShiftsState state, {
    required String title,
    required String? value,
    required IconData icon,
  }) {
    final isSelected = state.profileFilter == value;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: () {
        cubit.setProfileFilter(value);
        Navigator.pop(context);
      },
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isSelected
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
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isSelected ? AppColors.primary.withValues(alpha: 0.05) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CashShiftsCubit>();

    return AdminLayout(
      title: 'Historial de Turnos',
      showBackButton: true,
      actions: [
        IconButton(
          onPressed: () => cubit.fetchShifts(),
          tooltip: 'Actualizar listado',
          icon: const Icon(Icons.refresh_rounded, size: 20),
        ),
      ],
      body: BlocBuilder<CashShiftsCubit, CashShiftsState>(
        builder: (context, state) {
          final isDesktop = MediaQuery.of(context).size.width >= 900;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  // ── 1. KPI Cards Bar ─────────────────────────────────
                  _buildKpiBar(context, state),
                  const SizedBox(height: 12),

                  // ── 2. Unified Control Bar (Filters & Controls) ──────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildControlToolbar(context, cubit, state, isDesktop),
                  ),
                  const SizedBox(height: 12),

                  // ── 3. Main Shift Content (Table / Cards) ─────────────
                  Expanded(
                    child: state.isLoading && state.shifts.isEmpty
                        ? const _ShiftsSkeleton()
                        : state.shifts.isEmpty
                            ? _buildEmptyState(context)
                            : Column(
                                children: [
                                  Expanded(
                                    child: RefreshIndicator(
                                      onRefresh: () async => cubit.fetchShifts(),
                                      child: isDesktop
                                          ? _buildDesktopDataTable(context, state)
                                          : _buildMobileCardList(context, state),
                                    ),
                                  ),
                                  // Paginación corporativa
                                  if (state.totalPages > 1)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        border: Border(
                                          top: BorderSide(
                                            color: Theme.of(context)
                                                .dividerColor
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                      ),
                                      child: AdminPageBlocks(
                                        currentPage: state.currentPage,
                                        totalPages: state.totalPages,
                                        onPageChanged: (page) => cubit.setPage(page),
                                      ),
                                    ),
                                ],
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 1. KPI Cards Bar ────────────────────────────────────────────────────────
  Widget _buildKpiBar(BuildContext context, CashShiftsState state) {
    final total = state.totalCount > 0 ? state.totalCount : state.shifts.length;
    final openCount = state.totalOpenCount > 0
        ? state.totalOpenCount
        : state.shifts.where((s) => s.status == CashShiftStatus.open).length;
    final closedCount = state.totalClosedCount > 0
        ? state.totalClosedCount
        : state.shifts.where((s) => s.status == CashShiftStatus.closed).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          if (isNarrow) {
            return Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    title: 'Registros',
                    value: '$total',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiCard(
                    title: 'Abiertos',
                    value: '$openCount',
                    icon: Icons.play_circle_fill_rounded,
                    color: AppColors.success,
                    isPulsing: openCount > 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiCard(
                    title: 'Cerrados',
                    value: '$closedCount',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: 'Total Registros',
                  value: '$total turnos',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: 'Turnos Abiertos',
                  value: '$openCount en curso',
                  icon: Icons.play_circle_fill_rounded,
                  color: AppColors.success,
                  isPulsing: openCount > 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: 'Turnos Cerrados',
                  value: '$closedCount completados',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── 2. Unified Control Toolbar (Zero-Clutter) ───────────────────────────────
  Widget _buildControlToolbar(
    BuildContext context,
    CashShiftsCubit cubit,
    CashShiftsState state,
    bool isDesktop,
  ) {
    final theme = Theme.of(context);
    String selectedUserName = 'Todos los usuarios';
    if (state.profileFilter != null) {
      final p = state.profiles
          .where((p) => p['id'] == state.profileFilter)
          .firstOrNull;
      if (p != null) selectedUserName = p['full_name'] as String;
    }

    if (isDesktop) {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4), width: 0.5),
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
            // Segmented Status Chips
            _buildStatusChip(cubit, state, 'Todos', 'Todos'),
            const SizedBox(width: 6),
            _buildStatusChip(cubit, state, 'OPEN', 'Abiertos'),
            const SizedBox(width: 6),
            _buildStatusChip(cubit, state, 'CLOSED', 'Cerrados'),

            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: theme.dividerColor.withValues(alpha: 0.4)),
            const SizedBox(width: 16),

            // Compact User Selector
            InkWell(
              onTap: () => _showUserPickerAdaptive(cubit, state),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: state.profileFilter != null
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: state.profileFilter != null
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : theme.dividerColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.profileFilter == null ? Icons.group_rounded : Icons.person_rounded,
                      size: 16,
                      color: state.profileFilter != null ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        state.isLoadingProfiles ? 'Cargando...' : selectedUserName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: state.profileFilter != null ? FontWeight.w700 : FontWeight.w500,
                          color: state.profileFilter != null ? AppColors.primary : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: state.profileFilter != null ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            if (state.profileFilter != null) ...[
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                tooltip: 'Limpiar filtro de usuario',
                visualDensity: VisualDensity.compact,
                onPressed: () => cubit.setProfileFilter(null),
              ),
            ],

            const Spacer(),

            // Total indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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

    // Mobile / Tablet Compact Stacked Toolbar
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip(cubit, state, 'Todos', 'Todos'),
                      const SizedBox(width: 6),
                      _buildStatusChip(cubit, state, 'OPEN', 'Abiertos'),
                      const SizedBox(width: 6),
                      _buildStatusChip(cubit, state, 'CLOSED', 'Cerrados'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _showUserPickerAdaptive(cubit, state),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    state.profileFilter == null ? Icons.group_rounded : Icons.person_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.isLoadingProfiles ? 'Cargando usuarios...' : selectedUserName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    CashShiftsCubit cubit,
    CashShiftsState state,
    String status,
    String label,
  ) {
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
            color: isSelected ? AppColors.primary : Theme.of(context).dividerColor.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ── 3. Desktop High-Density Data Table (Stripe Style) ────────────────────────
  Widget _buildDesktopDataTable(BuildContext context, CashShiftsState state) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Container(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  children: const [
                    SizedBox(width: 110, child: Text('ESTADO', style: _tableHeaderStyle)),
                    Expanded(flex: 3, child: Text('CAJA / CUENTA', style: _tableHeaderStyle)),
                    Expanded(flex: 2, child: Text('RESPONSABLE', style: _tableHeaderStyle)),
                    Expanded(flex: 2, child: Text('APERTURA', style: _tableHeaderStyle)),
                    Expanded(flex: 2, child: Text('CIERRE', style: _tableHeaderStyle)),
                    Expanded(flex: 2, child: Text('DIFERENCIA', style: _tableHeaderStyle)),
                    SizedBox(width: 140, child: Text('ACCIONES', style: _tableHeaderStyle, textAlign: TextAlign.right)),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5),

              // Animated Data Rows
              AnimationLimiter(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.shifts.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    thickness: 0.5,
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                  itemBuilder: (context, index) {
                    final shift = state.shifts[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 250),
                      child: SlideAnimation(
                        verticalOffset: 12.0,
                        child: FadeInAnimation(
                          child: _DesktopTableRow(
                            shift: shift,
                            onTap: () => _showShiftDetailAdaptive(context, shift),
                            onClose: shift.isOpen ? () => _handleCloseShift(shift) : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 4. Mobile Apple HIG Card List ───────────────────────────────────────────
  Widget _buildMobileCardList(BuildContext context, CashShiftsState state) {
    return AnimationLimiter(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: state.shifts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final shift = state.shifts[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 250),
            child: SlideAnimation(
              verticalOffset: 16.0,
              child: FadeInAnimation(
                child: _MobileShiftCard(
                  shift: shift,
                  onTap: () => _showShiftDetailAdaptive(context, shift),
                  onClose: shift.isOpen ? () => _handleCloseShift(shift) : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.point_of_sale_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron turnos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Prueba cambiando los filtros de estado o de usuario.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Table Header Style ────────────────────────────────────────────────
const _tableHeaderStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.6,
  color: AppColors.textSecondary,
);

// ── Desktop Table Row (Hoverable & Tabular) ──────────────────────────────────
class _DesktopTableRow extends StatefulWidget {
  final CashShiftEntity shift;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _DesktopTableRow({
    required this.shift,
    required this.onTap,
    this.onClose,
  });

  @override
  State<_DesktopTableRow> createState() => _DesktopTableRowState();
}

class _DesktopTableRowState extends State<_DesktopTableRow> {
  bool _isHovered = false;
  bool _isClosing = false;

  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;
    final isOpen = shift.isOpen;
    final theme = Theme.of(context);

    final diff = shift.differenceAmount ?? 0.0;
    final hasDiff = shift.differenceAmount != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          color: _isHovered
              ? theme.colorScheme.primary.withValues(alpha: 0.03)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              // Estado Badge (Con dot indicador)
              SizedBox(
                width: 110,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusBadge(isOpen: isOpen),
                ),
              ),

              // Caja / Cuenta
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isOpen ? AppColors.success : AppColors.textSecondary)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.point_of_sale_rounded,
                        size: 16,
                        color: isOpen ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shift.accountName ?? 'Caja General',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (shift.notes != null && shift.notes!.isNotEmpty)
                            Text(
                              shift.notes!,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Responsable
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      child: Text(
                        (shift.openedByName?.isNotEmpty == true)
                            ? shift.openedByName![0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shift.openedByName ?? 'Desconocido',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Apertura (Monto + Fecha)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'S/ ${shift.openingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM HH:mm').format(shift.openedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Cierre
              Expanded(
                flex: 2,
                child: isOpen
                    ? Text(
                        'En curso...',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.success.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'S/ ${(shift.actualAmount ?? 0.0).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (shift.closedAt != null)
                            Text(
                              DateFormat('dd/MM HH:mm').format(shift.closedAt!),
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
              ),

              // Diferencia
              Expanded(
                flex: 2,
                child: !isOpen && hasDiff
                    ? Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: diff == 0
                                  ? AppColors.slateLight
                                  : (diff > 0
                                      ? AppColors.success.withValues(alpha: 0.12)
                                      : AppColors.danger.withValues(alpha: 0.12)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              diff == 0
                                  ? 'S/ 0.00'
                                  : (diff > 0
                                      ? '+S/ ${diff.toStringAsFixed(2)}'
                                      : '-S/ ${diff.abs().toStringAsFixed(2)}'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: diff == 0
                                    ? AppColors.textSecondary
                                    : (diff > 0 ? AppColors.success : AppColors.danger),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '-',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
              ),

              // Acciones
              SizedBox(
                width: 140,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isOpen && widget.onClose != null)
                      FilledButton.icon(
                        onPressed: _isClosing
                            ? null
                            : () async {
                                setState(() => _isClosing = true);
                                widget.onClose!();
                                if (mounted) setState(() => _isClosing = false);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.amberDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isClosing
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.lock_clock_rounded, size: 14),
                        label: const Text(
                          'Cerrar',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      )
                    else
                      IconButton(
                        onPressed: widget.onTap,
                        icon: const Icon(Icons.chevron_right_rounded, size: 18),
                        tooltip: 'Ver detalle de arqueo',
                        color: theme.colorScheme.onSurfaceVariant,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mobile Apple HIG Card ───────────────────────────────────────────────────
class _MobileShiftCard extends StatefulWidget {
  final CashShiftEntity shift;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _MobileShiftCard({
    required this.shift,
    required this.onTap,
    this.onClose,
  });

  @override
  State<_MobileShiftCard> createState() => _MobileShiftCardState();
}

class _MobileShiftCardState extends State<_MobileShiftCard> {
  bool _isClosing = false;

  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;
    final isOpen = shift.isOpen;
    final theme = Theme.of(context);
    final diff = shift.differenceAmount ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.35),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isOpen ? AppColors.success : AppColors.textSecondary)
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.point_of_sale_rounded,
                      size: 18,
                      color: isOpen ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.accountName ?? 'Caja General',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM, HH:mm').format(shift.openedAt),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•  ${shift.openedByName?.split(' ')[0] ?? 'Cajero'}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(isOpen: isOpen),
                ],
              ),

              const SizedBox(height: 12),
              Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withValues(alpha: 0.3)),
              const SizedBox(height: 12),

              // Financial Values Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apertura',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'S/ ${shift.openingAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isOpen) ...[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cierre',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'S/ ${(shift.actualAmount ?? 0.0).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Diferencia',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            diff == 0
                                ? 'S/ 0.00'
                                : (diff > 0
                                    ? '+S/ ${diff.toStringAsFixed(2)}'
                                    : '-S/ ${diff.abs().toStringAsFixed(2)}'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              color: diff == 0
                                  ? AppColors.textSecondary
                                  : (diff > 0 ? AppColors.success : AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              // Button to close if open
              if (isOpen && widget.onClose != null) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _isClosing
                      ? null
                      : () async {
                          setState(() => _isClosing = true);
                          widget.onClose!();
                          if (mounted) setState(() => _isClosing = false);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amberDark,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isClosing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.lock_clock_rounded, size: 16),
                  label: const Text(
                    'Cerrar Turno de Caja',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status Badge with Glowing Dot ────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool isOpen;

  const _StatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.slateLight.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOpen
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOpen ? AppColors.success : AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'ABIERTO' : 'CERRADO',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isOpen ? const Color(0xFF065F46) : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── KPI Card Widget ──────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isPulsing;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isPulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shift Detail Dialog (Desktop) ───────────────────────────────────────────
class _ShiftDetailDialog extends StatelessWidget {
  final CashShiftEntity shift;
  final VoidCallback? onCloseShift;

  const _ShiftDetailDialog({required this.shift, this.onCloseShift});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ShiftDetailContent(shift: shift),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                  if (onCloseShift != null) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.amberDark),
                      onPressed: onCloseShift,
                      icon: const Icon(Icons.lock_clock_rounded, size: 16),
                      label: const Text('Cerrar Turno Ahora'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shift Detail Sheet (Mobile) ──────────────────────────────────────────────
class _ShiftDetailSheet extends StatelessWidget {
  final CashShiftEntity shift;
  final VoidCallback? onCloseShift;

  const _ShiftDetailSheet({required this.shift, this.onCloseShift});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ShiftDetailContent(shift: shift),
              const SizedBox(height: 20),
              if (onCloseShift != null)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amberDark,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onCloseShift,
                  icon: const Icon(Icons.lock_clock_rounded, size: 18),
                  label: const Text('Cerrar Turno Ahora', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Reusable Detail Content Body ─────────────────────────────────────────────
class _ShiftDetailContent extends StatelessWidget {
  final CashShiftEntity shift;

  const _ShiftDetailContent({required this.shift});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = shift.isOpen;
    final diff = shift.differenceAmount ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title & Status
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isOpen ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.point_of_sale_rounded,
                color: isOpen ? AppColors.success : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shift.accountName ?? 'Caja General',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'ID: ${shift.id.substring(0, shift.id.length > 8 ? 8 : shift.id.length)}...',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            _StatusBadge(isOpen: isOpen),
          ],
        ),
        const SizedBox(height: 20),

        // Timeline Info Container
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              _buildDetailRow(
                'Apertura:',
                '${DateFormat('dd/MM/yyyy HH:mm').format(shift.openedAt)} (${shift.openedByName ?? 'Desconocido'})',
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Cierre:',
                isOpen
                    ? 'Turno actualmente en curso'
                    : (shift.closedAt != null
                        ? '${DateFormat('dd/MM/yyyy HH:mm').format(shift.closedAt!)} (${shift.closedByName ?? 'Desconocido'})'
                        : 'No registrado'),
              ),
              if (shift.notes != null && shift.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDetailRow('Notas:', shift.notes!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Financial Breakdown Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'RESUMEN FINANCIERO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _buildAmountRow('Monto Inicial (Apertura)', shift.openingAmount),
              if (!isOpen) ...[
                const SizedBox(height: 8),
                if (shift.expectedAmount != null)
                  _buildAmountRow('Monto Esperado', shift.expectedAmount!),
                const SizedBox(height: 8),
                _buildAmountRow('Monto Real al Cierre', shift.actualAmount ?? 0.0),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Diferencia de Caja:',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      diff == 0
                          ? 'S/ 0.00 (Cuadrada)'
                          : (diff > 0
                              ? '+S/ ${diff.toStringAsFixed(2)} (Sobrante)'
                              : '-S/ ${diff.abs().toStringAsFixed(2)} (Faltante)'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: diff == 0
                            ? AppColors.textSecondary
                            : (diff > 0 ? AppColors.success : AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(
          'S/ ${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ── Shimmer Skeleton Loader ─────────────────────────────────────────────────
class _ShiftsSkeleton extends StatelessWidget {
  const _ShiftsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const AppShimmer(height: 64, borderRadius: 14.0),
    );
  }
}
