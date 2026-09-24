import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_sidebar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_desktop_top_bar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_offline_banner.dart';

/// Configuración reactiva de la cabecera del ERP.
/// Permite a las pantallas hijas comunicar su título, acciones y botones de navegación
/// al [AdminShellLayout] persistente sin reconstruir la barra lateral.
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
    '/': 'Inicio  ›  Catálogo',
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
    '/': 'Catálogo de Productos',
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
    if (path.isEmpty || path == '/') return 'Panel de Administración ERP';
    for (final entry in breadcrumbMap.entries) {
      if (entry.key == '/') continue;
      if (path == entry.key || path.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }
    return 'Panel de Administración ERP';
  }

  static String resolveTitle(String path) {
    if (path.isEmpty || path == '/') return 'Catálogo de Productos';
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
        // Reiniciar configuración base de cabecera con valores automáticos de la ruta
        // para prevenir títulos residuales de la pantalla anterior.
        _headerNotifier.value = AdminHeaderConfig(
          title: AdminShellHelper.resolveTitle(path),
          breadcrumb: AdminShellHelper.resolveBreadcrumb(path),
        );
      }
    } catch (_) {}
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
      developer.log(
        'Error loading sidebar state in AdminShellLayout',
        error: e,
        stackTrace: st,
        name: 'AdminShellLayout',
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
      developer.log(
        'Error saving sidebar state in AdminShellLayout',
        error: e,
        stackTrace: st,
        name: 'AdminShellLayout',
      );
    }
  }

  void _updateHeader(AdminHeaderConfig config) {
    if (_headerNotifier.value != config) {
      _headerNotifier.value = config;
    }
  }

  bool _isPosTerminalRoute(String path) {
    return path == '/pos' || path == '/pos-checkout';
  }

  void _handleDefaultBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    try {
      final currentUri = GoRouterState.of(context).uri;
      final pathSegments = currentUri.pathSegments;

      if (pathSegments.length > 1) {
        final parentPath =
            '/${pathSegments.sublist(0, pathSegments.length - 1).join('/')}';
        context.go(parentPath);
        return;
      }
    } catch (_) {}

    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;

    // Rutas de pantalla completa exclusiva de POS: no renderizan la barra lateral de administración
    if (_isPosTerminalRoute(currentPath)) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;

        if (!isDesktop) {
          // En Mobile / Tablet, el shell delega la navegación a las pantallas hijas
          return AdminShellScope(
            headerNotifier: _headerNotifier,
            isDesktop: false,
            updateHeader: _updateHeader,
            child: widget.child,
          );
        }

        // En Desktop: Shell Persistente con Sidebar y TopBar fijos
        return AdminShellScope(
          headerNotifier: _headerNotifier,
          isDesktop: true,
          updateHeader: _updateHeader,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
            child: Scaffold(
              backgroundColor: AppColors.background,
              body: Row(
                children: [
                  // ── Left Sidebar (Desktop, MONTADO UNA SOLA VEZ) ─────────
                  AdminSidebar(
                    isCollapsed: _isSidebarCollapsed,
                    onToggleCollapse: _toggleSidebar,
                  ),

                  // ── Right Main Area (TopBar + Banner + Child) ───────────
                  Expanded(
                    child: Column(
                      children: [
                        // ── Persistent TopBar Reactiva ───────────────────
                        ValueListenableBuilder<AdminHeaderConfig>(
                          valueListenable: _headerNotifier,
                          builder: (context, header, _) {
                            final displayTitle =
                                header.title.isNotEmpty
                                    ? header.title
                                    : AdminShellHelper.resolveTitle(currentPath);
                            final displayBreadcrumb =
                                (header.breadcrumb != null &&
                                        header.breadcrumb!.isNotEmpty)
                                    ? header.breadcrumb!
                                    : AdminShellHelper.resolveBreadcrumb(
                                      currentPath,
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
                              showSettingsButton: header.showSettingsButton,
                              settingsActions: header.settingsActions,
                              onSettingsSelected: header.onSettingsSelected,
                            );
                          },
                        ),

                        // ── Persistent Offline Banner ────────────────────
                        const AdminOfflineBanner(),

                        // ── Content View (Swapped reactively by GoRouter) ─
                        Expanded(child: widget.child),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
