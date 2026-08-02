import 'dart:async';
import 'dart:convert';
import 'dart:developer' as import_developer;
import 'package:inventory_store_app/features/users/domain/usecases/export_users_csv_usecase.dart'
    as import_export;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
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
  // _debouncedQuery es el valor enviado a los tabs (tarda 500ms en actualizarse)
  String _debouncedQuery = '';
  Timer? _debounce;
  bool _isExporting = false;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

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
    _debounce?.cancel();
    _countsCubit.close();
    _isFabExtended.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Retrasa 500ms la propagación real de la query a los tabs
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
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

  /// Exporta los usuarios del tab activo a un archivo CSV y lo descarga.
  Future<void> _exportToCsv() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    // Muestra diálogo de progreso no cancelable
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Expanded(child: Text('Generando CSV desde servidor...')),
                ],
              ),
            ),
      );
    }

    try {
      final role =
          _tabController.index == 0
              ? AppRoles.customer
              : _tabController.index == 1
              ? AppRoles.admin
              : AppRoles.employee;

      final useCase = sl<import_export.ExportUsersCsvUseCase>();

      final result = await useCase(
        role: role,
        searchQuery: _debouncedQuery,
        onlyActive: _onlyActive,
      );

      if (!mounted) return;

      result.fold(
        (failure) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al exportar: ${failure.message}'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        },
        (csvString) async {
          if (csvString.isEmpty) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No hay usuarios encontrados para exportar.'),
              ),
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
            name: '$fileName.csv',
            bytes: bytes,
            mimeType: MimeType.csv,
          );

          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Exportado: $fileName.csv'),
                backgroundColor: Colors.green.shade600,
                duration: const Duration(seconds: 4),
              ),
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
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _countsCubit,
      child: AdminLayout(
        title: 'Gestión de Usuarios',
        showBackButton: true,
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
                          onChanged: _onSearchChanged,
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
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _searchCtrl,
                                  builder: (context, value, child) {
                                    return value.text.isNotEmpty
                                        ? IconButton(
                                          icon: const Icon(
                                            Icons.clear_rounded,
                                            color: Colors.grey,
                                          ),
                                          onPressed: _clearSearch,
                                        )
                                        : const SizedBox.shrink();
                                  },
                                ),
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
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _isExporting ? null : _exportToCsv,
                          child: Tooltip(
                            message: 'Exportar tab actual a CSV',
                            child:
                                _isExporting
                                    ? Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    )
                                    : Icon(
                                      Icons.file_download_outlined,
                                      color: Colors.green.shade700,
                                    ),
                          ),
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
                  child: BlocSelector<UsersCubit, UsersState, (int, int, int)>(
                    selector:
                        (s) => (s.customerTotal, s.adminTotal, s.employeeTotal),
                    builder: (context, counts) {
                      final (cTotal, aTotal, eTotal) = counts;
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
                            text: 'Clientes ($cTotal)',
                          ),
                          Tab(
                            iconMargin: const EdgeInsets.only(bottom: 6),
                            icon: const Icon(
                              Icons.admin_panel_settings_outlined,
                              size: 20,
                            ),
                            text: 'Admins ($aTotal)',
                          ),
                          Tab(
                            iconMargin: const EdgeInsets.only(bottom: 6),
                            icon: const Icon(Icons.badge_outlined, size: 20),
                            text: 'Empleados ($eTotal)',
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
                      searchQuery: _debouncedQuery,
                      onlyActive: _onlyActive,
                      scrollController: _scrollController,
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
                      scrollController: _scrollController,
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
                      scrollController: _scrollController,
                      tabController: _tabController,
                      tabIndex: 2,
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

            context.go(
              '/admin/users/form',
              extra: {'initialRole': initialRole},
            );
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
