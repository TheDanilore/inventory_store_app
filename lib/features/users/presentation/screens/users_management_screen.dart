import 'dart:async';
import 'dart:convert';
import 'dart:developer' as import_developer;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/shortcut_utils.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/users/domain/usecases/export_users_csv_usecase.dart'
    as import_export;
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_cubit.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/users/users_tab.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _onlyActive = false;
  String _debouncedQuery = '';
  Timer? _debounce;
  bool _isExporting = false;

  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
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
    _isFabExtended.dispose();
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
    final isDesktop = MediaQuery.of(context).size.width >= 900;

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
            body: NotificationListener<UserScrollNotification>(
              onNotification: _onScrollNotification,
              child: Column(
                children: [
                  // ─── COMMAND BAR & FILTROS ──────────────────────────────────────────
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

                  // ─── LISTADO DE USUARIOS (STAFF) ──────────────────────────────────
                  Expanded(
                    child: BlocProvider(
                      key: const ValueKey('staff_users'),
                      create: (_) => sl<UsersCubit>()..init('staff'),
                      child: UsersTab(
                        role: 'staff',
                        searchQuery: _debouncedQuery,
                        onlyActive: _onlyActive,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // FAB disponible principalmente en móvil o como atajo rápido
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
                      label: ValueListenableBuilder<bool>(
                        valueListenable: _isFabExtended,
                        builder: (context, isExtended, _) {
                          return AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child:
                                isExtended
                                    ? Text(
                                      'Nuevo $_currentRoleLabel',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                    : const SizedBox.shrink(),
                          );
                        },
                      ),
                    ),
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
              focusNode: _searchFocusNode,
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
                    if (value.text.isNotEmpty) {
                      return IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        color: Colors.grey,
                        onPressed: _clearSearch,
                      );
                    }
                    return Tooltip(
                      message: 'Atajo: ${AppShortcutLabels.search}',
                    );
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

        // Botón Crear Usuario Contextual (protegido por permisos)
        if (context.hasPermission(AppPermissions.usersCreate)) ...[
          const SizedBox(width: 12),
          Tooltip(
            message:
                'Crear nuevo $_currentRoleLabel (${AppShortcutLabels.newRecord})',
            child: ElevatedButton.icon(
              onPressed: _navigateToCreateUser,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text('Nuevo $_currentRoleLabel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
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
                  focusNode: _searchFocusNode,
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
                  message: 'Exportar lista a CSV',
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
}
