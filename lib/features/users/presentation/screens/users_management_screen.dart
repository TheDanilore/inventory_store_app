import 'dart:async';
import 'dart:convert';
import 'dart:developer' as import_developer;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/shortcut_utils.dart';
import 'package:inventory_store_app/core/widgets/admin_kpi_metrics_bar.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/users/domain/usecases/export_users_csv_usecase.dart'
    as import_export;
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_cubit.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_state.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/users/users_tab.dart';

class UsersManagementScreen extends StatelessWidget {
  const UsersManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) =>
              sl<UsersCubit>()
                ..init('staff')
                ..fetchCounts()
                ..fetchUsers(),
      child: const _UsersManagementContent(),
    );
  }
}

class _UsersManagementContent extends StatefulWidget {
  const _UsersManagementContent();

  @override
  State<_UsersManagementContent> createState() =>
      _UsersManagementContentState();
}

class _UsersManagementContentState extends State<_UsersManagementContent> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _onlyActive = false;
  bool _isTableView = true;
  String _debouncedQuery = '';
  Timer? _debounce;
  bool _isExporting = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _focusSearch() {
    _searchFocusNode.requestFocus();
  }

  void _unfocusSearch() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final trimmed = value.trim();
      setState(() {
        _debouncedQuery = trimmed;
      });
      context.read<UsersCubit>().fetchUsers(
        searchQuery: trimmed,
        onlyActive: _onlyActive,
        page: 0,
      );
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() {
      _debouncedQuery = '';
    });
    context.read<UsersCubit>().fetchUsers(
      searchQuery: '',
      onlyActive: _onlyActive,
      page: 0,
    );
  }

  String get _currentRoleLabel => 'Colaborador';
  String get _currentRoleConstant => 'staff';

  Future<void> _navigateToCreateUser() async {
    await context.push<bool>(
      '/users/form',
      extra: {'initialRole': AppRoles.employee},
    );
  }

  /// Exporta los usuarios a un archivo CSV y lo descarga.
  Future<void> _exportToCsv() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final role = _currentRoleConstant;
      final useCase = sl<import_export.ExportUsersCsvUseCase>();

      final result = await useCase(
        role: role,
        searchQuery: _debouncedQuery,
        onlyActive: _onlyActive,
      );

      if (!mounted) return;

      await result.match(
        (failure) async {
          AppSnackbar.show(
            context,
            message: 'Error al exportar: ${failure.message}',
            type: SnackbarType.error,
          );
        },
        (csvString) async {
          if (csvString.isEmpty) {
            AppSnackbar.show(
              context,
              message: 'No hay usuarios encontrados para exportar.',
              type: SnackbarType.warning,
            );
            return;
          }

          final bytes = utf8.encode(csvString);
          final fileName =
              'usuarios_colaboradores_${DateTime.now().millisecondsSinceEpoch}';

          await FileSaver.instance.saveFile(
            name: fileName,
            bytes: bytes,
            fileExtension: 'csv',
            mimeType: MimeType.csv,
          );

          if (mounted) {
            AppSnackbar.show(
              context,
              message: 'Exportado correctamente: $fileName.csv',
              type: SnackbarType.success,
            );
          }
        },
      );
    } catch (e, st) {
      import_developer.log(
        '🔴 [CSV Export] Error al exportar: $e',
        error: e,
        stackTrace: st,
        name: 'UsersManagementScreen',
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al exportar: ${e.toString()}',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    return PermissionGuard(
      permission: AppPermissions.usersView,
      fallback: const AdminLayout(
        title: 'Gestión de Usuarios',
        body: Center(
          child: Text('No tienes permisos para ver la gestión de usuarios.'),
        ),
      ),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true):
              _focusSearch,
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
              _focusSearch,
          const SingleActivator(LogicalKeyboardKey.keyK, alt: true):
              _focusSearch,
          const SingleActivator(LogicalKeyboardKey.keyN, control: true):
              _navigateToCreateUser,
          const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
              _navigateToCreateUser,
          const SingleActivator(LogicalKeyboardKey.keyN, alt: true):
              _navigateToCreateUser,
          const SingleActivator(LogicalKeyboardKey.escape): _unfocusSearch,
        },
        child: Focus(
          autofocus: true,
          child: AdminLayout(
            title: 'Gestión de Usuarios',
            body: BlocBuilder<UsersCubit, UsersState>(
              builder: (context, state) {
                // Cálculo de KPIs en tiempo real
                final totalStaff =
                    state.totalCount > 0
                        ? state.totalCount
                        : (state.adminTotal + state.employeeTotal > 0
                            ? (state.adminTotal + state.employeeTotal)
                            : state.currentUsers.length);
                final activeCount =
                    state.currentUsers.where((u) => u.isActive).length;
                final activePct =
                    state.currentUsers.isNotEmpty
                        ? ((activeCount / state.currentUsers.length) * 100)
                            .toStringAsFixed(0)
                        : '100';
                final adminCount =
                    state.adminTotal > 0
                        ? state.adminTotal
                        : state.currentUsers
                            .where(
                              (u) =>
                                  u.allRoles.contains(AppRoles.admin) ||
                                  u.role == AppRoles.admin,
                            )
                            .length;
                final staffCount =
                    state.employeeTotal > 0
                        ? state.employeeTotal
                        : state.currentUsers
                            .where(
                              (u) =>
                                  u.allRoles.any(
                                    (r) =>
                                        r == AppRoles.employee ||
                                        r == AppRoles.cashier ||
                                        r == 'cajero' ||
                                        r == 'empleado',
                                  ) ||
                                  u.role == AppRoles.employee ||
                                  u.role == AppRoles.cashier,
                            )
                            .length;

                return Column(
                  children: [
                    // ─── 1. BENTO KPI METRICS BAR ─────────────────────────────────
                    AdminKpiMetricsBar(
                      isDesktop: isDesktop,
                      isLoading:
                          state is UsersLoading && state.currentUsers.isEmpty,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        isDesktop ? 12 : 10,
                        16,
                        4,
                      ),
                      items: [
                        AdminKpiItem.primary(
                          title: 'Total Personal',
                          value: '$totalStaff',
                          subtitle: 'Colaboradores registrados',
                          icon: Icons.badge_outlined,
                        ),
                        AdminKpiItem.green(
                          title: 'Personal Activo',
                          value: '$activeCount',
                          subtitle: '$activePct% habilitados',
                          icon: Icons.check_circle_outline_rounded,
                        ),
                        AdminKpiItem.purple(
                          title: 'Administradores',
                          value: '$adminCount',
                          subtitle: 'Control total de sistema',
                          icon: Icons.admin_panel_settings_outlined,
                        ),
                        AdminKpiItem.teal(
                          title: 'Cajeros y Operación',
                          value: '$staffCount',
                          subtitle: 'Punto de venta y almacén',
                          icon: Icons.point_of_sale_rounded,
                        ),
                      ],
                    ),

                    // ─── 2. TOOLBAR PRO UNIFICADO ─────────────────────────────────
                    AdminProToolbar(
                      searchController: _searchCtrl,
                      searchFocusNode: _searchFocusNode,
                      searchHint:
                          'Buscar por nombre, correo, teléfono o documento...',
                      onSearchChanged: _onSearchChanged,
                      onClearSearch: _clearSearch,
                      searchOnSubmitOnly: false,
                      isDesktop: isDesktop,
                      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      viewToggleConfig: AdminProViewToggleConfig(
                        isTableView: _isTableView,
                        onToggleTableView:
                            (isTable) => setState(() => _isTableView = isTable),
                      ),
                      filterWidgets: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Solo activos',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: _onlyActive,
                                activeThumbColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() => _onlyActive = val);
                                  context.read<UsersCubit>().fetchUsers(
                                    searchQuery: _debouncedQuery,
                                    onlyActive: val,
                                    page: 0,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      filterGroups: [
                        AdminFilterGroup<bool?>(
                          title: 'Estado',
                          icon: Icons.toggle_on_outlined,
                          selected: _onlyActive ? true : null,
                          defaultValue: null,
                          onSelected: (v) {
                            final onlyAct = v == true;
                            setState(() => _onlyActive = onlyAct);
                            context.read<UsersCubit>().fetchUsers(
                              searchQuery: _debouncedQuery,
                              onlyActive: onlyAct,
                              page: 0,
                            );
                          },
                          options: const [
                            AdminFilterOption<bool?>(
                              value: null,
                              label: 'Todos',
                            ),
                            AdminFilterOption<bool?>(
                              value: true,
                              label: 'Solo Activos',
                              icon: Icons.check_circle_rounded,
                              color: AppColors.successDark,
                            ),
                            AdminFilterOption<bool?>(
                              value: false,
                              label: 'Inactivos',
                              icon: Icons.pause_circle_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ],
                      trailingActions: [
                        OutlinedButton.icon(
                          onPressed: _isExporting ? null : _exportToCsv,
                          icon:
                              _isExporting
                                  ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.file_download_outlined,
                                    size: 16,
                                  ),
                          label: const Text('Exportar CSV'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                      primaryAction:
                          context.hasPermission(AppPermissions.usersCreate)
                              ? AdminProToolbarAction(
                                label: 'Nuevo Colaborador',
                                icon: Icons.person_add_rounded,
                                onPressed: _navigateToCreateUser,
                                keyHint: 'N',
                              )
                              : null,
                      onRefresh: () {
                        context.read<UsersCubit>().fetchCounts();
                        context.read<UsersCubit>().fetchUsers();
                      },
                      refreshTooltip: 'Actualizar lista [R]',
                    ),

                    // ─── 3. TABLA EJECUTIVA PRO (STAFF) ───────────────────────────
                    Expanded(
                      child: UsersTab(
                        role: 'staff',
                        searchQuery: _debouncedQuery,
                        onlyActive: _onlyActive,
                        isTableView: _isTableView,
                      ),
                    ),
                  ],
                );
              },
            ),

            // FAB disponible en móvil para crear nuevo usuario
            floatingActionButton:
                isDesktop || !context.hasPermission(AppPermissions.usersCreate)
                    ? null
                    : FloatingActionButton.extended(
                      backgroundColor: AppColors.primary,
                      onPressed: _navigateToCreateUser,
                      tooltip:
                          'Nuevo ($_currentRoleLabel) (${AppShortcutLabels.newRecord})',
                      icon: const Icon(
                        Icons.person_add_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Nuevo $_currentRoleLabel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}