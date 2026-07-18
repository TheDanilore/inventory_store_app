import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_cubit.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_state.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/users/users_tab.dart';

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

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

  // We use this top-level cubit solely to fetch global counts for the tabs
  late final UsersCubit _countsCubit;

  @override
  void initState() {
    super.initState();
    _countsCubit = sl<UsersCubit>()..fetchCounts();

    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && _isFabExtended.value) {
        _isFabExtended.value = false;
      } else if (_scrollController.offset <= 10 && !_isFabExtended.value) {
        _isFabExtended.value = true;
      }
    });
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _countsCubit.close();
    _isFabExtended.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _exportToCsv(BuildContext context) {
    AppSnackbar.show(
      context,
      message: 'Exportando base de datos a CSV/Excel (En desarrollo)...',
      type: SnackbarType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _countsCubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Usuarios',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            // ─── BUSCADOR Y FILTROS ──────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onSubmitted: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText:
                                'Buscar por nombre, correo, teléfono o DNI...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.grey.shade400,
                            ),
                            suffixIcon:
                                _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() {});
                                      },
                                    )
                                    : null,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botón de exportar
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.file_download_outlined,
                            color: Colors.green.shade700,
                          ),
                          tooltip: 'Exportar a Excel/CSV',
                          onPressed: () => _exportToCsv(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mostrar solo usuarios activos',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Switch(
                        value: _onlyActive,
                        activeThumbColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) {
                          setState(() {
                            _onlyActive = val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── TABS ──────────────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: Colors.transparent,
                  child: BlocBuilder<UsersCubit, UsersState>(
                    builder: (context, state) {
                      return TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        indicatorColor: Colors.white,
                        indicatorWeight: 3.5,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        tabs: [
                          Tab(
                            iconMargin: const EdgeInsets.only(bottom: 6),
                            icon: const Icon(
                              Icons.people_outline_rounded,
                              size: 20,
                            ),
                            text: 'Clientes (${state.customerTotal})',
                          ),
                          Tab(
                            iconMargin: const EdgeInsets.only(bottom: 6),
                            icon: const Icon(
                              Icons.admin_panel_settings_outlined,
                              size: 20,
                            ),
                            text: 'Admins (${state.adminTotal})',
                          ),
                          Tab(
                            iconMargin: const EdgeInsets.only(bottom: 6),
                            icon: const Icon(Icons.badge_outlined, size: 20),
                            text: 'Empleados (${state.employeeTotal})',
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // ─── LISTAS ────────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  BlocProvider(
                    key: const ValueKey(AppRoles.customer),
                    create: (_) => sl<UsersCubit>()..init(AppRoles.customer),
                    child: UsersTab(
                      role: AppRoles.customer,
                      searchQuery: _searchCtrl.text,
                      onlyActive: _onlyActive,
                      scrollController: _scrollController,
                    ),
                  ),
                  BlocProvider(
                    key: const ValueKey(AppRoles.admin),
                    create: (_) => sl<UsersCubit>()..init(AppRoles.admin),
                    child: UsersTab(
                      role: AppRoles.admin,
                      searchQuery: _searchCtrl.text,
                      onlyActive: _onlyActive,
                      scrollController: _scrollController,
                    ),
                  ),
                  BlocProvider(
                    key: const ValueKey(AppRoles.employee),
                    create: (_) => sl<UsersCubit>()..init(AppRoles.employee),
                    child: UsersTab(
                      role: AppRoles.employee,
                      searchQuery: _searchCtrl.text,
                      onlyActive: _onlyActive,
                      scrollController: _scrollController,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          onPressed: () async {
            String initialRole = AppRoles.customer;
            if (_tabController.index == 1) initialRole = AppRoles.admin;
            if (_tabController.index == 2) initialRole = AppRoles.employee;

            final changed = await context.push<bool?>(
              '/admin/user-form',
              extra: {'initialRole': initialRole},
            );
            if (changed == true) {
              _countsCubit.fetchCounts();
              setState(() {});
            }
          },
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: ValueListenableBuilder<bool>(
            valueListenable: _isFabExtended,
            builder: (context, isExtended, _) {
              return AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child:
                    isExtended
                        ? const Text(
                          'Nuevo',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        : const SizedBox.shrink(),
              );
            },
          ),
        ),
      ),
    );
  }
}
