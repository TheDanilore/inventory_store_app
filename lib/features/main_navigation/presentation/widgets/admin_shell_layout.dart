import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_sidebar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_desktop_top_bar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_command_palette.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_offline_banner.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/app_drawer.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/core/utils/app_back_handler.dart';

/// Configuración reactiva de la cabecera del ERP.
/// Permite a las pantallas hijas comunicar su título, acciones y botones de navegación
/// al [AdminShellLayout] persistente sin reconstruir la barra lateral ni la cabecera.
class AdminHeaderConfig {
  final String title;
  final String? breadcrumb;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool showSettingsButton;
  final List<PopupMenuEntry<String>>? settingsActions;
  final ValueChanged<String>? onSettingsSelected;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showAppBar;
  final bool showProfileButton;
  final bool showDrawerButton;

  const AdminHeaderConfig({
    required this.title,
    this.breadcrumb,
    this.actions,
    this.showBackButton = false,
    this.onBack,
    this.showSettingsButton = false,
    this.settingsActions,
    this.onSettingsSelected,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showAppBar = true,
    this.showProfileButton = true,
    this.showDrawerButton = true,
  });

  AdminHeaderConfig copyWith({
    String? title,
    String? breadcrumb,
    List<Widget>? actions,
    bool? showBackButton,
    VoidCallback? onBack,
    bool? showSettingsButton,
    List<PopupMenuEntry<String>>? settingsActions,
    ValueChanged<String>? onSettingsSelected,
    Widget? floatingActionButton,
    Widget? bottomNavigationBar,
    bool? showAppBar,
    bool? showProfileButton,
    bool? showDrawerButton,
  }) {
    return AdminHeaderConfig(
      title: title ?? this.title,
      breadcrumb: breadcrumb ?? this.breadcrumb,
      actions: actions ?? this.actions,
      showBackButton: showBackButton ?? this.showBackButton,
      onBack: onBack ?? this.onBack,
      showSettingsButton: showSettingsButton ?? this.showSettingsButton,
      settingsActions: settingsActions ?? this.settingsActions,
      onSettingsSelected: onSettingsSelected ?? this.onSettingsSelected,
      floatingActionButton: floatingActionButton ?? this.floatingActionButton,
      bottomNavigationBar: bottomNavigationBar ?? this.bottomNavigationBar,
      showAppBar: showAppBar ?? this.showAppBar,
      showProfileButton: showProfileButton ?? this.showProfileButton,
      showDrawerButton: showDrawerButton ?? this.showDrawerButton,
    );
  }
}

/// Scope que declara la presencia del Persistent Shell en el árbol de widgets.
class AdminShellScope extends InheritedWidget {
  final ValueNotifier<AdminHeaderConfig> headerNotifier;
  final bool isDesktop;
  final void Function(AdminHeaderConfig config) updateHeader;

  const AdminShellScope({
    super.key,
    required this.headerNotifier,
    required this.isDesktop,
    required this.updateHeader,
    required super.child,
  });

  static AdminShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdminShellScope>();
  }

  static AdminShellScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'AdminShellScope no fue encontrado en el árbol de widgets.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(AdminShellScope oldWidget) {
    return isDesktop != oldWidget.isDesktop ||
        headerNotifier != oldWidget.headerNotifier;
  }
}

/// Ayudante centralizado para resolver títulos y migas de pan automáticas
/// a partir de la ruta actual de GoRouter.
class AdminShellHelper {
  static const Map<String, String> breadcrumbMap = {
    '/purchase-orders/form': 'Inicio  ›  Órdenes de Compra  ›  Nueva Orden',
    '/purchase-orders': 'Inicio  ›  Órdenes de Compra',
    '/inventory-entries/form':
        'Inicio  ›  Entradas de Inventario  ›  Nueva Entrada',
    '/inventory-entries': 'Inicio  ›  Entradas de Inventario',
    '/inventory-exits/form':
        'Inicio  ›  Salidas de Inventario  ›  Nueva Salida',
    '/inventory-exits': 'Inicio  ›  Salidas de Inventario',
    '/products/product-form': 'Inicio  ›  Productos  ›  Formulario',
    '/products': 'Inicio  ›  Productos',
    '/catalog': 'Inicio  ›  Catálogo',
    '/': 'Inicio  ›  Dashboard',
    '/users/form': 'Inicio  ›  Usuarios  ›  Formulario Usuario',
    '/users': 'Inicio  ›  Usuarios',
    '/customer-credit-movements':
        'Inicio  ›  Créditos Clientes  ›  Movimientos',
    '/customer-credits': 'Inicio  ›  Créditos Clientes',
    '/customers/customer-detail': 'Inicio  ›  Clientes  ›  Detalle',
    '/customers': 'Inicio  ›  Clientes',
    '/supplier-credit-movements':
        'Inicio  ›  Créditos Proveedores  ›  Movimientos',
    '/supplier-credits': 'Inicio  ›  Créditos Proveedores',
    '/suppliers': 'Inicio  ›  Proveedores',
    '/orders': 'Inicio  ›  Pedidos',
    '/kardex': 'Inicio  ›  Kardex',
    '/financial-accounts': 'Inicio  ›  Cuentas Financieras',
    '/categories': 'Inicio  ›  Categorías',
    '/brands': 'Inicio  ›  Marcas',
    '/warehouses': 'Inicio  ›  Almacenes',
    '/attributes': 'Inicio  ›  Atributos',
    '/active-ingredients': 'Inicio  ›  Ingredientes Activos',
    '/business-info': 'Inicio  ›  Información de la Empresa',
    '/points-settings': 'Inicio  ›  Ajustes de Puntos',
    '/inventory': 'Inicio  ›  Inventario',
    '/dashboard': 'Inicio  ›  Dashboard',
    '/all-cash-shifts': 'Inicio  ›  Caja POS  ›  Historial de Turnos',
    '/profile': 'Inicio  ›  Mi Perfil',
  };

  static const Map<String, String> titleMap = {
    '/purchase-orders/form': 'Nueva Orden de Compra',
    '/purchase-orders': 'Órdenes de Compra',
    '/inventory-entries/form': 'Nueva Entrada de Inventario',
    '/inventory-entries': 'Entradas de Inventario',
    '/inventory-exits/form': 'Nueva Salida de Inventario',
    '/inventory-exits': 'Salidas de Inventario',
    '/products/product-form': 'Formulario de Producto',
    '/products': 'Catálogo de Productos',
    '/catalog': 'Catálogo de Productos',
    '/': 'Dashboard General',
    '/users/form': 'Formulario de Usuario',
    '/users': 'Gestión de Usuarios',
    '/customer-credit-movements': 'Movimientos de Crédito Clientes',
    '/customer-credits': 'Créditos de Clientes',
    '/customers/customer-detail': 'Detalle de Cliente',
    '/customers': 'Directorio de Clientes',
    '/supplier-credit-movements': 'Movimientos de Crédito Proveedores',
    '/supplier-credits': 'Créditos de Proveedores',
    '/suppliers': 'Directorio de Proveedores',
    '/orders': 'Gestión de Pedidos',
    '/kardex': 'Kardex de Inventario',
    '/financial-accounts': 'Cuentas Financieras',
    '/categories': 'Categorías de Productos',
    '/brands': 'Marcas de Productos',
    '/warehouses': 'Gestión de Almacenes',
    '/attributes': 'Atributos de Producto',
    '/active-ingredients': 'Ingredientes Activos',
    '/business-info': 'Información de la Empresa',
    '/points-settings': 'Ajustes de Fidelización',
    '/inventory': 'Stock e Inventario',
    '/dashboard': 'Dashboard General',
    '/all-cash-shifts': 'Historial de Turnos de Caja',
    '/profile': 'Mi Perfil',
  };

  static String resolveBreadcrumb(String path) {
    if (path.isEmpty || path == '/') return 'Inicio  ›  Dashboard';
    for (final entry in breadcrumbMap.entries) {
      if (entry.key == '/') continue;
      if (path == entry.key || path.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }
    return 'Panel de Administración ERP';
  }

  static String resolveTitle(String path) {
    if (path.isEmpty || path == '/') return 'Dashboard General';
    for (final entry in titleMap.entries) {
      if (entry.key == '/') continue;
      if (path == entry.key || path.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }
    return 'Panel ERP';
  }
}

/// Contenedor de Shell Persistente para el ERP.
/// Se ubica en [ShellRoute] en `app_router.dart`.
///
/// En Desktop (>= 1024px):
/// - Monta [AdminSidebar] una sola vez; nunca se destruye ni parpadea al navegar.
/// - Mantiene [AdminDesktopTopBar] reactiva al contenido del hijo.
/// - Ofrece cero parpadeos blancos (cero `SizedBox.shrink()`).
///
/// En Rutas Terminales de POS (`/pos`, `/pos-checkout`):
/// - Retorna directamente el contenido hijo para otorgarle pantalla completa al POS.
///
/// En Móvil/Tablet (< 1024px):
/// - Delega la AppBar y Drawer a las pantallas hijas a través de [AdminLayout].
class AdminShellLayout extends StatefulWidget {
  final Widget child;

  const AdminShellLayout({super.key, required this.child});

  /// Cache en memoria sincrónico para evitar parpadeos blancos en arranque
  static bool cachedSidebarCollapsed = false;
  static bool hasLoadedFromPrefs = false;

  @override
  State<AdminShellLayout> createState() => _AdminShellLayoutState();
}

class _AdminShellLayoutState extends State<AdminShellLayout> {
  static const _sidebarCollapsedKey = 'admin_sidebar_collapsed';

  bool _isSidebarCollapsed = AdminShellLayout.cachedSidebarCollapsed;
  late final ValueNotifier<AdminHeaderConfig> _headerNotifier;
  String _currentPath = '';

  @override
  void initState() {
    super.initState();
    _headerNotifier = ValueNotifier<AdminHeaderConfig>(
      const AdminHeaderConfig(title: 'Panel ERP'),
    );
    if (!AdminShellLayout.hasLoadedFromPrefs) {
      _loadSidebarState();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final path = GoRouterState.of(context).uri.path;
      if (_currentPath != path) {
        _currentPath = path;
        AppBackHandler.recordRoute(path);
        final isRoot = path.isEmpty || path == '/' || path == '/dashboard';
        // Reiniciar configuración base de cabecera con valores automáticos de la ruta
        // para prevenir títulos residuales de la pantalla anterior.
        _headerNotifier.value = AdminHeaderConfig(
          title: AdminShellHelper.resolveTitle(path),
          breadcrumb: AdminShellHelper.resolveBreadcrumb(path),
          actions: const [],
          showBackButton: !isRoot,
          showDrawerButton: true,
          showProfileButton: true,
          showAppBar: true,
        );
      }
    } catch (e, st) {
      LoggerService.w(
        'Error resolviendo ruta en didChangeDependencies',
        error: e,
        stackTrace: st,
        tag: 'AdminShellLayout',
      );
    }
  }

  @override
  void dispose() {
    _headerNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadSidebarState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final collapsed = prefs.getBool(_sidebarCollapsedKey) ?? false;
      AdminShellLayout.cachedSidebarCollapsed = collapsed;
      AdminShellLayout.hasLoadedFromPrefs = true;
      if (mounted && _isSidebarCollapsed != collapsed) {
        setState(() {
          _isSidebarCollapsed = collapsed;
        });
      }
    } catch (e, st) {
      LoggerService.e(
        'Error loading sidebar state in AdminShellLayout',
        error: e,
        stackTrace: st,
        tag: 'AdminShellLayout',
      );
      AdminShellLayout.hasLoadedFromPrefs = true;
    }
  }

  Future<void> _toggleSidebar() async {
    final newValue = !_isSidebarCollapsed;
    AdminShellLayout.cachedSidebarCollapsed = newValue;
    setState(() => _isSidebarCollapsed = newValue);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sidebarCollapsedKey, newValue);
    } catch (e, st) {
      LoggerService.e(
        'Error saving sidebar state in AdminShellLayout',
        error: e,
        stackTrace: st,
        tag: 'AdminShellLayout',
      );
    }
  }

  void _updateHeader(AdminHeaderConfig config) {
    if (_headerNotifier.value != config) {
      _headerNotifier.value = config;
    }
  }

  void _handleDefaultBack(BuildContext context) {
    AppBackHandler.handleBack(
      context,
      onCustomBack: _headerNotifier.value.onBack,
    );
  }

  void _openProfile(BuildContext context) {
    final user = context.read<AuthCubit>().state.currentUser;
    if (user == null) {
      context.go('/login');
    } else {
      context.push('/profile');
    }
  }

  static bool _isRefreshWidget(Widget w) {
    if (w is IconButton) {
      final icon = w.icon;
      if (icon is Icon &&
          (icon.icon == Icons.refresh_rounded || icon.icon == Icons.refresh)) {
        return true;
      }
      final tooltip = w.tooltip?.toLowerCase() ?? '';
      if (tooltip.contains('actualizar') ||
          tooltip.contains('refrescar') ||
          tooltip.contains('recargar')) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;

        if (!isDesktop) {
          // ── Mobile / Tablet: Persistent Shell con AppBar, Drawer y SafeArea ──
          return AdminShellScope(
            headerNotifier: _headerNotifier,
            isDesktop: false,
            updateHeader: _updateHeader,
            child: ValueListenableBuilder<AdminHeaderConfig>(
              valueListenable: _headerNotifier,
              builder: (context, header, _) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final isRoot =
                    _currentPath.isEmpty ||
                    _currentPath == '/' ||
                    _currentPath == '/dashboard';
                final showBack =
                    header.showBackButton && !isRoot ||
                    header.showBackButton && header.onBack != null;

                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness:
                        isDark ? Brightness.light : Brightness.dark,
                    statusBarBrightness:
                        isDark ? Brightness.dark : Brightness.light,
                  ),
                  child: AppPopScope(
                    onCustomBack: header.onBack,
                    child: Scaffold(
                      backgroundColor: AppColors.bg(context),
                      endDrawer:
                          header.showDrawerButton
                              ? const AppDrawer(isAdmin: true)
                              : null,
                      appBar:
                          header.showAppBar
                              ? AppBar(
                                backgroundColor:
                                    isDark
                                        ? AppColors.darkSurface
                                        : AppColors.surface,
                                elevation: 0,
                                shadowColor: Colors.black.withValues(
                                  alpha: 0.06,
                                ),
                                surfaceTintColor: Colors.transparent,
                                titleSpacing: 0,
                                leadingWidth: showBack ? 52 : 46,
                                leading:
                                    showBack
                                        ? Align(
                                          alignment: Alignment.centerLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 12,
                                            ),
                                            child: AdminAppBarIconButton(
                                              icon:
                                                  Icons
                                                      .arrow_back_ios_new_rounded,
                                              tooltip: 'Volver',
                                              onTap:
                                                  header.onBack ??
                                                  () => _handleDefaultBack(
                                                    context,
                                                  ),
                                            ),
                                          ),
                                        )
                                        : Padding(
                                          padding: const EdgeInsets.only(
                                            left: 14,
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 32,
                                              height: 32,
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color:
                                                    isDark
                                                        ? const Color(
                                                          0xFF1E293B,
                                                        )
                                                        : const Color(
                                                          0xFFEFF6FF,
                                                        ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      isDark
                                                          ? const Color(
                                                            0xFF334155,
                                                          )
                                                          : const Color(
                                                            0xFFDBEAFE,
                                                          ),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Image.asset(
                                                'assets/logo_icon.png',
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        ),
                                title:
                                    showBack
                                        ? Padding(
                                          padding: const EdgeInsets.only(
                                            left: 4,
                                          ),
                                          child: Text(
                                            header.title.isNotEmpty
                                                ? header.title
                                                : AdminShellHelper.resolveTitle(
                                                  _currentPath,
                                                ),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  isDark
                                                      ? AppColors
                                                          .darkTextPrimary
                                                      : AppColors.textPrimary,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        )
                                        : Padding(
                                          padding: const EdgeInsets.only(
                                            left: 4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'DANILORE',
                                                style: TextStyle(
                                                  fontSize: 16.5,
                                                  fontWeight: FontWeight.w900,
                                                  color:
                                                      isDark
                                                          ? AppColors
                                                              .darkTextPrimary
                                                          : const Color(
                                                            0xFF0F172A,
                                                          ),
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'ONE',
                                                style: TextStyle(
                                                  fontSize: 16.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF2563EB),
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                actions: [
                                  if (header.actions != null)
                                    ...header.actions!.where(
                                      (a) => !_isRefreshWidget(a),
                                    ),
                                  if (header.actions != null &&
                                      header.actions!
                                          .where((a) => !_isRefreshWidget(a))
                                          .isNotEmpty)
                                    const SizedBox(width: 6),

                                  if (header.showSettingsButton &&
                                      header.settingsActions != null &&
                                      header.settingsActions!.isNotEmpty) ...[
                                    AdminSettingsMenuButton(
                                      items: header.settingsActions!,
                                      onSelected: header.onSettingsSelected,
                                    ),
                                    const SizedBox(width: 6),
                                  ],

                                  if (header.showDrawerButton)
                                    Builder(
                                      builder:
                                          (context) => AdminAppBarIconButton(
                                            icon: Icons.menu_rounded,
                                            tooltip: 'Menú principal',
                                            onTap:
                                                () =>
                                                    Scaffold.of(
                                                      context,
                                                    ).openEndDrawer(),
                                          ),
                                    ),

                                  if (header.showProfileButton) ...[
                                    const SizedBox(width: 6),
                                    AdminProfileAvatar(
                                      onTap: () => _openProfile(context),
                                    ),
                                  ],

                                  const SizedBox(width: 12),
                                ],
                              )
                              : null,
                      body: SafeArea(
                        top: !header.showAppBar,
                        bottom: false,
                        child: Column(
                          children: [
                            const RepaintBoundary(child: AdminOfflineBanner()),
                            Expanded(child: widget.child),
                          ],
                        ),
                      ),
                      floatingActionButton: header.floatingActionButton,
                      bottomNavigationBar: header.bottomNavigationBar,
                    ),
                  ),
                );
              },
            ),
          );
        }

        // ── Desktop: Shell Persistente con Sidebar y TopBar fijos ────────────
        return AdminShellScope(
          headerNotifier: _headerNotifier,
          isDesktop: true,
          updateHeader: _updateHeader,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.keyK,
                control: true,
              ): () {
                AdminCommandPaletteDialog.show(context);
              },
              const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
                AdminCommandPaletteDialog.show(context);
              },
            },
            child: AppPopScope(
              onCustomBack: _headerNotifier.value.onBack,
              child: Builder(
                builder: (context) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness:
                          isDark ? Brightness.light : Brightness.dark,
                      statusBarBrightness:
                          isDark ? Brightness.dark : Brightness.light,
                    ),
                    child: Scaffold(
                      backgroundColor: AppColors.bg(context),
                      body: Row(
                        children: [
                          // ── Left Sidebar (Desktop, MONTADO UNA SOLA VEZ) ───
                          RepaintBoundary(
                            child: AdminSidebar(
                              isCollapsed: _isSidebarCollapsed,
                              onToggleCollapse: _toggleSidebar,
                            ),
                          ),

                          // ── Right Main Area (TopBar + Banner + Child) ─────
                          Expanded(
                            child: Column(
                              children: [
                                // ── Persistent TopBar Reactiva ───────────────
                                RepaintBoundary(
                                  child: ValueListenableBuilder<
                                    AdminHeaderConfig
                                  >(
                                    valueListenable: _headerNotifier,
                                    builder: (context, header, _) {
                                      final displayTitle =
                                          header.title.isNotEmpty
                                              ? header.title
                                              : AdminShellHelper.resolveTitle(
                                                _currentPath,
                                              );
                                      final displayBreadcrumb =
                                          (header.breadcrumb != null &&
                                                  header.breadcrumb!.isNotEmpty)
                                              ? header.breadcrumb!
                                              : AdminShellHelper.resolveBreadcrumb(
                                                _currentPath,
                                              );

                                      return AdminDesktopTopBar(
                                        isSidebarCollapsed: _isSidebarCollapsed,
                                        onToggleSidebar: _toggleSidebar,
                                        showBackButton: header.showBackButton,
                                        onBack:
                                            header.onBack ??
                                            () => _handleDefaultBack(context),
                                        title: displayTitle,
                                        breadcrumbText: displayBreadcrumb,
                                        actions: header.actions,
                                        showSettingsButton:
                                            header.showSettingsButton,
                                        settingsActions: header.settingsActions,
                                        onSettingsSelected:
                                            header.onSettingsSelected,
                                      );
                                    },
                                  ),
                                ),

                                // ── Persistent Offline Banner ────────────────
                                const RepaintBoundary(
                                  child: AdminOfflineBanner(),
                                ),

                                // ── Content View (Swapped reactively by GoRouter)
                                Expanded(
                                  child: RepaintBoundary(child: widget.child),
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
            ),
          ),
        );
      },
    );
  }
}

/// Botón circular para la AppBar móvil
class AdminAppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const AdminAppBarIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final button = Material(
      color: isDark ? const Color(0xFF1E293B) : AppColors.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            size: 18,
            color:
                isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Botón de opciones para la AppBar móvil
class AdminSettingsMenuButton extends StatelessWidget {
  final List<PopupMenuEntry<String>> items;
  final PopupMenuItemSelected<String>? onSelected;

  const AdminSettingsMenuButton({
    super.key,
    required this.items,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      tooltip: 'Opciones',
      offset: const Offset(0, 45),
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.more_vert_rounded,
          size: 18,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Avatar / botón de perfil con CachedNetworkImage
class AdminProfileAvatar extends StatelessWidget {
  final VoidCallback? onTap;
  const AdminProfileAvatar({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatarBody = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BlocSelector<
        AuthCubit,
        AuthState,
        ({ViewState viewState, String? avatarUrl, String? fullName})
      >(
        selector:
            (state) => (
              viewState: state.viewState,
              avatarUrl: state.currentUser?.avatarUrl,
              fullName: state.currentUser?.fullName,
            ),
        builder: (context, data) {
          if (data.viewState == ViewState.loading &&
              data.avatarUrl == null &&
              (data.fullName ?? '').isEmpty) {
            return const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            );
          }

          if (data.avatarUrl != null && data.avatarUrl!.isNotEmpty) {
            return CachedNetworkImage(
              imageUrl: data.avatarUrl!,
              memCacheWidth: 96,
              memCacheHeight: 96,
              fit: BoxFit.cover,
              width: 38,
              height: 38,
              placeholder: (ctx, url) => _initialsWidget(data.fullName),
              errorWidget: (ctx, url, error) => _initialsWidget(data.fullName),
            );
          }
          return _initialsWidget(data.fullName);
        },
      ),
    );

    return Tooltip(
      message: 'Perfil',
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: AppColors.cardShadow(opacity: 0.2),
        ),
        child: Material(
          color: Colors.transparent,
          child:
              onTap != null
                  ? InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(10),
                    child: avatarBody,
                  )
                  : avatarBody,
        ),
      ),
    );
  }

  Widget _initialsWidget(String? fullName) {
    String initials = '?';
    final name = (fullName ?? '').trim();
    if (name.isNotEmpty) {
      final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
      initials =
          parts.length >= 2
              ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
              : name[0].toUpperCase();
    }

    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
