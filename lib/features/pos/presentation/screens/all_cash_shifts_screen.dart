import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_state.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/close_shift_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/cash_shifts/shifts_kpi_bar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/cash_shifts/shifts_control_toolbar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/cash_shifts/shift_list_items.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/cash_shifts/shift_detail_widgets.dart';

// ── Entry Point ───────────────────────────────────────────────────────────────

/// Pantalla de historial de turnos de caja.
///
/// Soporta modo embebido (dentro del POS) y modo standalone con [AdminLayout].
/// Los controles sensibles (cerrar turno, filtrar por usuario) están protegidos
/// visualmente con [PermissionGuard]; la validación real ocurre en el backend.
class AllCashShiftsScreen extends StatelessWidget {
  final bool isEmbedded;
  final VoidCallback? onBack;
  final CashShiftsCubit? cubit;

  const AllCashShiftsScreen({
    super.key,
    this.isEmbedded = false,
    this.onBack,
    this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _AllCashShiftsBody(isEmbedded: isEmbedded, onBack: onBack),
      );
    }
    return BlocProvider<CashShiftsCubit>(
      create: (_) => sl<CashShiftsCubit>(),
      child: _AllCashShiftsBody(isEmbedded: isEmbedded, onBack: onBack),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _AllCashShiftsBody extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onBack;

  const _AllCashShiftsBody({this.isEmbedded = false, this.onBack});

  @override
  State<_AllCashShiftsBody> createState() => _AllCashShiftsBodyState();
}

class _AllCashShiftsBodyState extends State<_AllCashShiftsBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<CashShiftsCubit>();
      if (cubit.state.profiles.isEmpty) cubit.loadProfiles();
      if (cubit.state.shifts.isEmpty) cubit.fetchShifts();
    });
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

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
      if (shift.accountId != null) {
        try {
          context.read<PosCubit>().checkActiveShift(shift.accountId!);
        } catch (_) {}
      }
    }
  }

  void _showShiftDetail(CashShiftEntity shift) {
    // La acción de cierre solo se pasa si el usuario tiene permiso; el widget
    // interno añade otro PermissionGuard como segunda capa visual.
    final canClose = context.hasPermission(AppPermissions.posCashShiftClose);
    final onClose =
        (shift.isOpen && canClose)
            ? () {
              Navigator.pop(context);
              _handleCloseShift(shift);
            }
            : null;

    final isDesktop = MediaQuery.of(context).size.width >= 720;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => ShiftDetailDialog(shift: shift, onCloseShift: onClose),
      );
    } else {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ShiftDetailSheet(shift: shift, onCloseShift: onClose),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CashShiftsCubit>();

    final shiftContent = BlocBuilder<CashShiftsCubit, CashShiftsState>(
      builder: (context, state) {
        final isDesktop = MediaQuery.of(context).size.width >= 900;

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => cubit.fetchShifts(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (widget.isEmbedded)
                      SliverToBoxAdapter(child: _EmbeddedHeader(cubit: cubit)),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    // 1. KPI Bar
                    SliverToBoxAdapter(child: ShiftsKpiBar(state: state)),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // 2. Control Toolbar (filtros + fecha + usuario)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ShiftsControlToolbar(
                          cubit: cubit,
                          state: state,
                          isDesktop: isDesktop,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // 3. List content
                    if (state.isLoading && state.shifts.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _ShiftsSkeleton(),
                      )
                    else if (state.shifts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
                    else
                      SliverToBoxAdapter(
                        child:
                            isDesktop
                                ? _DesktopTable(
                                  state: state,
                                  onDetail: _showShiftDetail,
                                  onClose: _handleCloseShift,
                                )
                                : _MobileCardList(
                                  state: state,
                                  onDetail: _showShiftDetail,
                                  onClose: _handleCloseShift,
                                ),
                      ),
                  ],
                ),
              ),
            ),

            // Paginación
            if (state.totalPages > 1)
              _PaginationBar(state: state, cubit: cubit),
          ],
        );
      },
    );

    if (widget.isEmbedded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: shiftContent),
      );
    }

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
      body: shiftContent,
    );
  }
}

// ── Sub-widgets (pequeños, solo usados en esta pantalla) ──────────────────────

class _EmbeddedHeader extends StatelessWidget {
  final CashShiftsCubit cubit;
  const _EmbeddedHeader({required this.cubit});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF142B1A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              color: Color(0xFF142B1A),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Historial de Turnos de Caja',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Supervisa aperturas, cierres, arqueos y montos esperados',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
                        AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => cubit.fetchShifts(),
            tooltip: 'Actualizar listado',
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _DesktopTable extends StatelessWidget {
  final CashShiftsState state;
  final ValueChanged<CashShiftEntity> onDetail;
  final ValueChanged<CashShiftEntity> onClose;

  const _DesktopTable({
    required this.state,
    required this.onDetail,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.4),
            width: 0.5,
          ),
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
              // Header
              Container(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text('ESTADO', style: _tableHeaderStyle),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('CAJA / CUENTA', style: _tableHeaderStyle),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('RESPONSABLE', style: _tableHeaderStyle),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('APERTURA', style: _tableHeaderStyle),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('CIERRE', style: _tableHeaderStyle),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('DIFERENCIA', style: _tableHeaderStyle),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        'ACCIONES',
                        style: _tableHeaderStyle,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5),
              for (int i = 0; i < state.shifts.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                RepaintBoundary(
                  child: ShiftDesktopTableRow(
                    key: ValueKey(state.shifts[i].id),
                    shift: state.shifts[i],
                    onTap: () => onDetail(state.shifts[i]),
                    onClose:
                        state.shifts[i].isOpen
                            ? () => onClose(state.shifts[i])
                            : null,
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

const _tableHeaderStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.6,
  color: AppColors.textSecondary,
);

class _MobileCardList extends StatelessWidget {
  final CashShiftsState state;
  final ValueChanged<CashShiftEntity> onDetail;
  final ValueChanged<CashShiftEntity> onClose;

  const _MobileCardList({
    required this.state,
    required this.onDetail,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: state.shifts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final shift = state.shifts[index];
        return ShiftMobileCard(
          key: ValueKey(shift.id),
          shift: shift,
          onTap: () => onDetail(shift),
          onClose: shift.isOpen ? () => onClose(shift) : null,
        );
      },
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final CashShiftsState state;
  final CashShiftsCubit cubit;
  const _PaginationBar({required this.state, required this.cubit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: AdminPageBlocks(
        currentPage: state.currentPage,
        totalPages: state.totalPages,
        onPageChanged: (page) => cubit.setPage(page),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.point_of_sale_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
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
