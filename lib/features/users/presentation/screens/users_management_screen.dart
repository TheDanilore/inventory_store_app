import 'dart:async';
import 'dart:convert';
import 'dart:developer' as import_developer;
import 'package:inventory_store_app/features/users/domain/usecases/export_users_csv_usecase.dart'
    as import_export;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_cubit.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_state.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/users/users_tab.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabController;
  bool _onlyActive = false;
  String _debouncedQuery = '';
  Timer? _debounce;
  bool _isExporting = false;

  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

  late final UsersCubit _countsCubit;

  @override
  void initState() {
    super.initState();
    _countsCubit = sl<UsersCubit>()..fetchCounts();
    _tabController = TabController(length: 3, vsync: this);
  }

  bool _onScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse &&
        _isFabExtended.value) {
      _isFabExtended.value = false;
    } else if (notification.direction == ScrollDirection.forward &&
        !_isFabExtended.value) {
      _isFabExtended.value = true;
    }
    return false;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _countsCubit.close();
    _isFabExtended.dispose();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _debouncedQuery = value.trim();
      });
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() {
      _debouncedQuery = '';
    });
  }

  String get _currentRoleLabel {
    switch (_tabController.index) {
      case 1:
        return 'Administrador';
      case 2:
        return 'Empleado';
      default:
        return 'Cliente';
    }
  }

  String get _currentRoleConstant {
    switch (_tabController.index) {
      case 1:
        return AppRoles.admin;
      case 2:
        return AppRoles.employee;
      default:
        return AppRoles.customer;
    }
  }

  Future<void> _navigateToCreateUser() async {
    final res = await context.push<bool>(
      '/admin/users/form',
      extra: {'initialRole': _currentRoleConstant},
    );
    if (res == true && mounted) {
      _countsCubit.fetchCounts();
    }
  }

  /// Exporta los usuarios del tab activo a un archivo CSV y lo descarga.
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
          final tabLabel =
              _tabController.index == 0
                  ? 'clientes'
                  : _tabController.index == 1
                  ? 'admins'
                  : 'empleados';
          final fileName =
              'usuarios_${tabLabel}_${DateTime.now().millisecondsSinceEpoch}';

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
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return BlocProvider.value(
      value: _countsCubit,
      child: AdminLayout(
        title: 'Gestión de Usuarios',
        showBackButton: true,
        body: NotificationListener<UserScrollNotification>(
          onNotification: _onScrollNotification,
          child: Column(
            children: [
              // ─── COMMAND BAR & FILTROS ──────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 16,
                  vertical: isDesktop ? 12 : 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child:
                    isDesktop
                        ? _buildDesktopCommandBar()
                        : _buildMobileCommandBar(),
              ),

              // ─── TABS SEGMENTADOS STRIPE / LINEAR ────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BlocSelector<UsersCubit, UsersState, (int, int, int)>(
                    selector:
                        (s) => (s.customerTotal, s.adminTotal, s.employeeTotal),
                    builder: (context, counts) {
                      final (cTotal, aTotal, eTotal) = counts;
                      return AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, _) {
                          return TabBar(
                            controller: _tabController,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: Colors.grey.shade600,
                            indicatorColor: AppColors.primary,
                            indicatorWeight: 3,
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            tabs: [
                              Tab(
                                height: 48,
                                child: _buildTabItem(
                                  icon: Icons.people_outline_rounded,
                                  label: 'Clientes',
                                  count: cTotal,
                                  isSelected: _tabController.index == 0,
                                ),
                              ),
                              Tab(
                                height: 48,
                                child: _buildTabItem(
                                  icon: Icons.admin_panel_settings_outlined,
                                  label: 'Admins',
                                  count: aTotal,
                                  isSelected: _tabController.index == 1,
                                ),
                              ),
                              Tab(
                                height: 48,
                                child: _buildTabItem(
                                  icon: Icons.badge_outlined,
                                  label: 'Empleados',
                                  count: eTotal,
                                  isSelected: _tabController.index == 2,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              // ─── CONTENIDO DE LOS TABS ───────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    BlocProvider(
                      key: const ValueKey(AppRoles.customer),
                      create: (_) => sl<UsersCubit>()..init(AppRoles.customer),
                      child: UsersTab(
                        role: AppRoles.customer,
                        searchQuery: _debouncedQuery,
                        onlyActive: _onlyActive,
                        tabController: _tabController,
                        tabIndex: 0,
                      ),
                    ),
                    BlocProvider(
                      key: const ValueKey(AppRoles.admin),
                      create: (_) => sl<UsersCubit>()..init(AppRoles.admin),
                      child: UsersTab(
                        role: AppRoles.admin,
                        searchQuery: _debouncedQuery,
                        onlyActive: _onlyActive,
                        tabController: _tabController,
                        tabIndex: 1,
                      ),
                    ),
                    BlocProvider(
                      key: const ValueKey(AppRoles.employee),
                      create: (_) => sl<UsersCubit>()..init(AppRoles.employee),
                      child: UsersTab(
                        role: AppRoles.employee,
                        searchQuery: _debouncedQuery,
                        onlyActive: _onlyActive,
                        tabController: _tabController,
                        tabIndex: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // FAB disponible principalmente en móvil o como atajo rápido
        floatingActionButton:
            isDesktop
                ? null
                : FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  onPressed: _navigateToCreateUser,
                  icon: const Icon(
                    Icons.person_add_rounded,
                    color: Colors.white,
                  ),
                  label: ValueListenableBuilder<bool>(
                    valueListenable: _isFabExtended,
                    builder: (context, isExtended, _) {
                      return AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child:
                            isExtended
                                ? AnimatedBuilder(
                                  animation: _tabController,
                                  builder: (context, _) {
                                    return Text(
                                      'Nuevo $_currentRoleLabel',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  },
                                )
                                : const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
      ),
    );
  }

  /// Command Bar para Desktop: Buscador estilizado + Switch + Exportar + Nuevo botón
  Widget _buildDesktopCommandBar() {
    return Row(
      children: [
        // Buscador estilo Pro Tool
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, correo, teléfono o documento...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchCtrl,
                  builder: (context, value, child) {
                    return value.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          color: Colors.grey,
                          onPressed: _clearSearch,
                        )
                        : const SizedBox.shrink();
                  },
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),

        // Filtro Solo Activos
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
                  setState(() {
                    _onlyActive = val;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),

        // Botón Exportar CSV
        OutlinedButton.icon(
          onPressed: _isExporting ? null : _exportToCsv,
          icon:
              _isExporting
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.file_download_outlined, size: 18),
          label: const Text('Exportar CSV'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
            side: BorderSide(color: Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Botón Crear Usuario Contextual
        ElevatedButton.icon(
          onPressed: _navigateToCreateUser,
          icon: const Icon(Icons.add_rounded, size: 19),
          label: Text('Nuevo $_currentRoleLabel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  /// Command Bar para Móvil
  Widget _buildMobileCommandBar() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar usuario...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchCtrl,
                      builder: (context, value, child) {
                        return value.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              color: Colors.grey,
                              onPressed: _clearSearch,
                            )
                            : const SizedBox.shrink();
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isExporting ? null : _exportToCsv,
                child: Tooltip(
                  message: 'Exportar tab actual a CSV',
                  child:
                      _isExporting
                          ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Icon(
                            Icons.file_download_outlined,
                            color: Colors.grey.shade700,
                            size: 20,
                          ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mostrar solo usuarios activos',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: _onlyActive,
                activeThumbColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (val) {
                  setState(() {
                    _onlyActive = val;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Pestaña con pill badge estilizada
  Widget _buildTabItem({
    required IconData icon,
    required String label,
    required int count,
    required bool isSelected,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}
