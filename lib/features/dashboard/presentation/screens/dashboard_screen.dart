import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';

import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/services/file_export_service.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_time_filter.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:inventory_store_app/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:inventory_store_app/features/dashboard/presentation/services/dashboard_export_service.dart';

// Componentes extraídos
import 'package:inventory_store_app/features/dashboard/presentation/widgets/agronomic_greeting_banner.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/birthday_celebration_dialog.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_add_widget_sheet.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_admin_goal_card.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_bento_grid.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_executive_subheader.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_best_sellers_table.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_health_summary_bar.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_kpis_section.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_sales_cards.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_skeleton.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/expiring_batches_card.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers_card.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_command_palette.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<DashboardCubit>(),
      child: const _DashboardScreenContent(),
    );
  }
}

class _DashboardScreenContent extends StatefulWidget {
  const _DashboardScreenContent();

  @override
  State<_DashboardScreenContent> createState() =>
      _DashboardScreenContentState();
}

class _DashboardScreenContentState extends State<_DashboardScreenContent> {
  static const String _prefsKey = 'dashboard_visible_widget_ids';

  Set<String> _visibleWidgets = {
    'kpi_strip',
    'profit_spline',
    'best_sellers',
    'customer_segments',
    'weekly_activity',
    'radial_goal',
    'expiring_batches',
  };

  @override
  void initState() {
    super.initState();
    _loadVisibleWidgets();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<DashboardCubit>();
      if (cubit.state is DashboardInitial) {
        cubit.loadDashboardData();
      } else {
        cubit.loadDashboardData(background: true);
      }

      final authUser = context.read<AuthCubit>().state.currentUser;
      BirthdayCelebrationDialog.checkAndShow(context, authUser);
    });
  }

  Future<void> _loadVisibleWidgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey);
      if (list != null && list.isNotEmpty && mounted) {
        setState(() {
          _visibleWidgets = list.where((id) => id != 'ai_assistant').toSet();
        });
      }
    } catch (e, st) {
      LoggerService.e(
        'Error cargando widgets visibles del dashboard desde preferencias',
        tag: 'DASHBOARD_SCREEN',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _saveVisibleWidgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _visibleWidgets.toList());
    } catch (e, st) {
      LoggerService.e(
        'Error guardando widgets visibles del dashboard en preferencias',
        tag: 'DASHBOARD_SCREEN',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _toggleWidget(String id, bool isVisible) {
    setState(() {
      if (isVisible) {
        _visibleWidgets.add(id);
      } else {
        _visibleWidgets.remove(id);
      }
    });
    _saveVisibleWidgets();
  }

  void _resetWidgetsToDefault() {
    setState(() {
      _visibleWidgets = {
        'kpi_strip',
        'profit_spline',
        'best_sellers',
        'customer_segments',
        'weekly_activity',
        'radial_goal',
        'expiring_batches',
      };
    });
    _saveVisibleWidgets();
  }

  void _openAddWidgetSheet() {
    DashboardAddWidgetSheet.show(
      context,
      visibleWidgetIds: _visibleWidgets,
      onToggleWidget: _toggleWidget,
      onResetDefaults: _resetWidgetsToDefault,
    );
  }

  Future<void> _handleExportReport() async {
    // Validación adicional de permisos UI
    if (!context.isAdmin &&
        !context.hasPermission(AppPermissions.reportsExport)) {
      AppSnackbar.show(
        context,
        message: 'No cuentas con permiso para exportar reportes.',
        type: SnackbarType.warning,
      );
      return;
    }

    final cubit = context.read<DashboardCubit>();
    final state = cubit.state;
    if (state is DashboardLoaded) {
      AppSnackbar.show(
        context,
        message: 'Generando reporte consolidado del dashboard...',
        type: SnackbarType.info,
        duration: const Duration(seconds: 2),
      );
      try {
        final result = await DashboardExportService.exportConsolidatedReport(
          state,
        );
        if (!mounted) return;
        switch (result.outcome) {
          case FileExportOutcome.saved:
            AppSnackbar.show(
              context,
              message: 'Reporte consolidado descargado exitosamente.',
              type: SnackbarType.success,
              duration: const Duration(seconds: 3),
            );
            break;
          case FileExportOutcome.cancelled:
            AppSnackbar.show(
              context,
              message: 'Exportación cancelada.',
              type: SnackbarType.warning,
              duration: const Duration(seconds: 3),
            );
            break;
          case FileExportOutcome.failed:
            AppSnackbar.show(
              context,
              message: 'Error al exportar reporte consolidado: ${result.error}',
              type: SnackbarType.error,
              duration: const Duration(seconds: 4),
            );
            break;
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Error al exportar reporte consolidado: $e',
            type: SnackbarType.error,
            duration: const Duration(seconds: 4),
          );
        }
      }
    } else {
      AppSnackbar.show(
        context,
        message: 'Espere a que carguen las métricas para exportar',
        type: SnackbarType.warning,
      );
    }
  }

  bool _isTextFieldFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    return primaryFocus != null && primaryFocus.context?.widget is EditableText;
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        // Atajo R: Recargar Dashboard
        const SingleActivator(LogicalKeyboardKey.keyR): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().refresh();
        },
        // Atajo W: Abrir panel Add Widget
        const SingleActivator(LogicalKeyboardKey.keyW): () {
          if (_isTextFieldFocused()) return;
          _openAddWidgetSheet();
        },
        // Atajos 1-4: Filtros temporales de ventas
        const SingleActivator(LogicalKeyboardKey.digit1): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().updateSalesFilter(
            SalesTimeFilter.today,
          );
        },
        const SingleActivator(LogicalKeyboardKey.digit2): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().updateSalesFilter(
            SalesTimeFilter.thisWeek,
          );
        },
        const SingleActivator(LogicalKeyboardKey.digit3): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().updateSalesFilter(
            SalesTimeFilter.thisMonth,
          );
        },
        const SingleActivator(LogicalKeyboardKey.digit4): () {
          if (_isTextFieldFocused()) return;
          context.read<DashboardCubit>().updateSalesFilter(
            SalesTimeFilter.allTime,
          );
        },
        // Atajo G o M: Abrir meta de ahorro
        const SingleActivator(LogicalKeyboardKey.keyG): () {
          if (_isTextFieldFocused()) return;
          final cfg = context.read<AppConfigCubit>();
          AdminGoalHelper.openGoalDialog(
            context,
            cfg.getDouble('admin_goal_current', 0.0),
            cfg.getDouble('admin_goal_target', 2600.0),
          );
        },
        const SingleActivator(LogicalKeyboardKey.keyM): () {
          if (_isTextFieldFocused()) return;
          final cfg = context.read<AppConfigCubit>();
          AdminGoalHelper.openGoalDialog(
            context,
            cfg.getDouble('admin_goal_current', 0.0),
            cfg.getDouble('admin_goal_target', 2600.0),
          );
        },
        // Atajo / : Abrir barra de comandos global
        const SingleActivator(LogicalKeyboardKey.slash): () {
          if (_isTextFieldFocused()) return;
          AdminCommandPaletteDialog.show(context);
        },
      },
      child: Focus(
        autofocus: true,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            AppFeedbackService.mediumImpact();
            await context.read<DashboardCubit>().refresh();
          },
          child: BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, state) {
              if (state is DashboardInitial || state is DashboardLoading) {
                return const SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: DashboardSkeleton(),
                );
              }

              if (state is DashboardError) {
                return _buildErrorState(state.message);
              }

              if (state is DashboardLoaded) {
                return Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 1100;
                        final isTablet = constraints.maxWidth >= 720;

                        if (isDesktop) {
                          return _buildDesktopLayout(context, state);
                        }
                        if (isTablet) {
                          return _buildTabletLayout(context, state);
                        }
                        return _buildMobileLayout(context, state);
                      },
                    ),
                    if (state.isBackgroundLoading)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          minHeight: 2.5,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed:
                  () => context.read<DashboardCubit>().loadDashboardData(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar conexión'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DESKTOP LAYOUT
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(BuildContext context, DashboardLoaded state) {
    final canViewInventory = context.hasAnyPermission(const [
      AppPermissions.inventoryView,
      AppPermissions.reportsInventory,
    ]);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Banner Ejecutivo de Bienvenida
                const AgronomicGreetingBanner()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 20),

                // 2. Alerta de Salud Operativa (Inventario)
                if (canViewInventory &&
                    (state.inventory.lowStockProducts > 0 ||
                        state.criticalBatches.isNotEmpty)) ...[
                  DashboardHealthSummaryBar(
                        lowStockCount: state.inventory.lowStockProducts,
                        criticalBatchesCount: state.criticalBatches.length,
                      )
                      .animate()
                      .fadeIn(delay: 60.ms, duration: 350.ms)
                      .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 16),
                ],

                // 3. Subheader Ejecutivo
                DashboardExecutiveSubheader(
                  state: state,
                  isDesktop: true,
                  visibleWidgetsCount: _visibleWidgets.length,
                  onOpenAddWidgetSheet: _openAddWidgetSheet,
                  onExportReport: _handleExportReport,
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: 20),

                // 4. Strip Superior de 4 KPIs
                if (_visibleWidgets.contains('kpi_strip')) ...[
                  DashboardKpisSection(state: state, isTabletOrMobile: false)
                      .animate()
                      .fadeIn(delay: 160.ms, duration: 450.ms)
                      .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 24),
                ],

                // 5. Bento Grid Modular
                DashboardBentoGrid(
                  state: state,
                  visibleWidgets: _visibleWidgets,
                  onToggleWidget: _toggleWidget,
                  onOpenAddWidgetSheet: _openAddWidgetSheet,
                ).animate().fadeIn(delay: 220.ms, duration: 500.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TABLET LAYOUT
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTabletLayout(BuildContext context, DashboardLoaded state) {
    final canViewInventory = context.hasAnyPermission(const [
      AppPermissions.inventoryView,
      AppPermissions.reportsInventory,
    ]);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AgronomicGreetingBanner()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 16),

                if (canViewInventory &&
                    (state.inventory.lowStockProducts > 0 ||
                        state.criticalBatches.isNotEmpty)) ...[
                  DashboardHealthSummaryBar(
                        lowStockCount: state.inventory.lowStockProducts,
                        criticalBatchesCount: state.criticalBatches.length,
                      )
                      .animate()
                      .fadeIn(delay: 60.ms, duration: 350.ms)
                      .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 14),
                ],

                DashboardExecutiveSubheader(
                  state: state,
                  isDesktop: false,
                  visibleWidgetsCount: _visibleWidgets.length,
                  onOpenAddWidgetSheet: _openAddWidgetSheet,
                  onExportReport: _handleExportReport,
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: 16),

                if (_visibleWidgets.contains('kpi_strip')) ...[
                  DashboardKpisSection(state: state, isTabletOrMobile: true)
                      .animate()
                      .fadeIn(delay: 160.ms, duration: 450.ms)
                      .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 20),
                ],

                DashboardBentoGrid(
                  state: state,
                  visibleWidgets: _visibleWidgets,
                  onToggleWidget: _toggleWidget,
                  onOpenAddWidgetSheet: _openAddWidgetSheet,
                ).animate().fadeIn(delay: 220.ms, duration: 500.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context, DashboardLoaded state) {
    final canViewSales = context.hasAnyPermission(const [
      AppPermissions.reportsSales,
      AppPermissions.reportsFinancial,
      AppPermissions.reportsView,
    ]);
    final canViewInventory = context.hasAnyPermission(const [
      AppPermissions.inventoryView,
      AppPermissions.reportsInventory,
    ]);

    final mobileWidgets = <Widget>[
      const AgronomicGreetingBanner()
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
      const SizedBox(height: 14),

      if (canViewInventory &&
          (state.inventory.lowStockProducts > 0 ||
              state.criticalBatches.isNotEmpty)) ...[
        DashboardHealthSummaryBar(
              lowStockCount: state.inventory.lowStockProducts,
              criticalBatchesCount: state.criticalBatches.length,
            )
            .animate()
            .fadeIn(delay: 60.ms, duration: 350.ms)
            .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
      ],

      DashboardExecutiveSubheader(
        state: state,
        isDesktop: false,
        visibleWidgetsCount: _visibleWidgets.length,
        onOpenAddWidgetSheet: _openAddWidgetSheet,
        onExportReport: _handleExportReport,
      ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

      if (_visibleWidgets.contains('kpi_strip'))
        DashboardKpisSection(state: state, isTabletOrMobile: true)
            .animate()
            .fadeIn(delay: 160.ms, duration: 450.ms)
            .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),

      if (_visibleWidgets.contains('profit_spline') &&
          state.overview != null &&
          canViewSales)
        SalesTrendCard(
          overview: state.overview!,
        ).animate().fadeIn(delay: 200.ms, duration: 450.ms),

      if (_visibleWidgets.contains('customer_segments') &&
          state.topCustomers.isNotEmpty &&
          canViewSales)
        TopCustomersCard(
          customers: state.topCustomers,
          displayMode: TopCustomersDisplayMode.mobile,
        ).animate().fadeIn(delay: 220.ms, duration: 450.ms),

      if (_visibleWidgets.contains('weekly_activity') &&
          state.overview != null &&
          canViewSales)
        WeeklyActivityCard(
          overview: state.overview!,
        ).animate().fadeIn(delay: 240.ms, duration: 450.ms),

      if (_visibleWidgets.contains('radial_goal') &&
          (context.isAdmin || canViewSales))
        const DashboardAdminGoalCard().animate().fadeIn(
          delay: 260.ms,
          duration: 450.ms,
        ),

      if (_visibleWidgets.contains('best_sellers') && canViewSales)
        DashboardBestSellersTable(
          bestSellers: state.sales.bestSellers,
          criticalBatches: state.criticalBatches,
        ).animate().fadeIn(delay: 280.ms, duration: 450.ms),

      if (_visibleWidgets.contains('expiring_batches') && canViewInventory)
        ExpiringBatchesCard(
          batches: state.criticalBatches,
        ).animate().fadeIn(delay: 300.ms, duration: 450.ms),
    ];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate(_withSpacers(mobileWidgets, 16)),
          ),
        ),
      ],
    );
  }

  List<Widget> _withSpacers(List<Widget> list, double spacing) {
    if (list.isEmpty) return [];
    final res = <Widget>[];
    for (int i = 0; i < list.length; i++) {
      res.add(list[i]);
      if (i < list.length - 1) {
        res.add(SizedBox(height: spacing));
      }
    }
    return res;
  }
}
