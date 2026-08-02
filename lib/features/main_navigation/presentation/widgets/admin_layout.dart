import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/core/network/network_state.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/offline_games_suggestion.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/app_drawer.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_sidebar.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/core/network/network_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminLayout extends StatefulWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showBackButton;
  final bool showProfileButton;
  final bool showSettingsButton;
  final bool showDrawerButton;
  final bool showAppBar;
  final List<PopupMenuEntry<String>>? settingsActions;
  final ValueChanged<String>? onSettingsSelected;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  /// Texto de migas de pan explícito. Si se provee, tiene prioridad sobre
  /// la detección automática por ruta (_buildBreadcrumbText), que es frágil
  /// porque depende de que el path contenga ciertas palabras clave.
  final String? breadcrumb;

  const AdminLayout({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showBackButton = false,
    this.showProfileButton = true,
    this.showSettingsButton = false,
    this.showDrawerButton = true,
    this.showAppBar = true,
    this.settingsActions,
    this.onSettingsSelected,
    this.actions,
    this.onBack,
    this.breadcrumb,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  static const _sidebarCollapsedKey = 'admin_sidebar_collapsed';
  static bool _sidebarCollapsedCache = false;
  static bool _isCacheLoaded = false;

  late bool _isSidebarCollapsed;

  @override
  void initState() {
    super.initState();
    _isSidebarCollapsed = _sidebarCollapsedCache;
    if (!_isCacheLoaded) {
      _loadSidebarState();
    }
  }

  Future<void> _loadSidebarState() async {
    final prefs = await SharedPreferences.getInstance();
    final collapsed = prefs.getBool(_sidebarCollapsedKey) ?? false;
    _sidebarCollapsedCache = collapsed;
    _isCacheLoaded = true;
    if (mounted && collapsed != _isSidebarCollapsed) {
      setState(() => _isSidebarCollapsed = collapsed);
    } else if (mounted && !_isSidebarCollapsed) {
      // Just trigger a rebuild to remove the "loading" blocker if any
      setState(() {});
    }
  }

  void _openProfile(BuildContext context) {
    // Usa AuthCubit (fuente de verdad) en lugar del SDK de Supabase
    // para evitar navegar con tokens expirados pero cacheados.
    final user = context.read<AuthCubit>().state.currentUser;
    if (user == null) {
      context.go('/login');
    } else {
      context.push('/admin/profile');
    }
  }

  Future<void> _toggleSidebar() async {
    final newValue = !_isSidebarCollapsed;
    _sidebarCollapsedCache = newValue;
    setState(() => _isSidebarCollapsed = newValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sidebarCollapsedKey, newValue);
  }

  @override
  Widget build(BuildContext context) {
    // Avoid layout jitter by waiting for SharedPreferences on the very first load
    if (!_isCacheLoaded) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;

          if (isDesktop) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: Row(
                children: [
                  // ── Left Sidebar (Desktop) ─────────────────────────────────
                  AdminSidebar(
                    isCollapsed: _isSidebarCollapsed,
                    onToggleCollapse: _toggleSidebar,
                  ),

                  // ── Right Main Area (TopBar + Body) ─────────────────────────
                  Expanded(
                    child: Column(
                      children: [
                        // ── TopBar ERP ───────────────────────────────────────
                        _buildDesktopTopBar(context),

                        // ── Offline Banner ───────────────────────────────────
                        _buildOfflineBanner(),

                        // ── Content View ─────────────────────────────────────
                        Expanded(child: widget.body),
                      ],
                    ),
                  ),
                ],
              ),
              floatingActionButton: widget.floatingActionButton,
            );
          }

          // ── Mobile / Tablet Layout ──────────────────────────────────────────
          return Scaffold(
            backgroundColor: AppColors.background,
            endDrawer:
                widget.showDrawerButton ? const AppDrawer(isAdmin: true) : null,
            appBar:
                widget.showAppBar
                    ? AppBar(
                      backgroundColor: AppColors.surface,
                      elevation: 0,
                      shadowColor: Colors.black.withValues(alpha: 0.06),
                      surfaceTintColor: Colors.transparent,
                      titleSpacing: 0,
                      title: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      leadingWidth:
                          (widget.showBackButton && widget.showProfileButton)
                              ? 104
                              : 60,
                      leading:
                          (!widget.showBackButton && !widget.showProfileButton)
                              ? const SizedBox.shrink()
                              : Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(width: 12),
                                    if (widget.showBackButton)
                                      AdminAppBarIconButton(
                                        icon: Icons.arrow_back_ios_new_rounded,
                                        tooltip: 'Volver',
                                        onTap: () => _handleBackButton(context),
                                      ),
                                    if (widget.showBackButton &&
                                        widget.showProfileButton)
                                      const SizedBox(width: 8),
                                    if (widget.showProfileButton)
                                      AdminProfileAvatar(
                                        onTap: () => _openProfile(context),
                                      ),
                                  ],
                                ),
                              ),
                      actions: [
                        if (widget.actions != null) ...widget.actions!,
                        if (widget.actions != null &&
                            widget.actions!.isNotEmpty)
                          const SizedBox(width: 8),

                        if (widget.showSettingsButton &&
                            widget.settingsActions != null &&
                            widget.settingsActions!.isNotEmpty) ...[
                          AdminSettingsMenuButton(
                            items: widget.settingsActions!,
                            onSelected: widget.onSettingsSelected,
                          ),
                          const SizedBox(width: 8),
                        ],

                        if (widget.showDrawerButton)
                          Builder(
                            builder:
                                (context) => AdminAppBarIconButton(
                                  icon: Icons.menu_rounded,
                                  tooltip: 'Menú principal',
                                  onTap:
                                      () =>
                                          Scaffold.of(context).openEndDrawer(),
                                ),
                          ),

                        const SizedBox(width: 12),
                      ],
                    )
                    : null,
            body: SafeArea(
              top: !widget.showAppBar,
              bottom: false,
              child: Column(
                children: [_buildOfflineBanner(), Expanded(child: widget.body)],
              ),
            ),
            floatingActionButton: widget.floatingActionButton,
            bottomNavigationBar: widget.bottomNavigationBar,
          );
        },
      ),
    );
  }

  // Lógica mejorada del botón atrás según la URL actual
  void _handleBackButton(BuildContext context) {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }

    final currentPath = GoRouterState.of(context).uri.path;

    // Redirección directa para vistas secundarias
    if (currentPath.contains('customer-detail')) {
      context.go('/admin/customers');
      return;
    } else if (currentPath.contains('customer-credit-movements')) {
      context.go('/admin/customer-credits');
      return;
    } else if (currentPath.contains('/inventory-exits/form')) {
      context.go('/admin/inventory-exits');
      return;
    } else if (currentPath.contains('/inventory-entries/form')) {
      context.go('/admin/inventory-entries');
      return;
    } else if (currentPath.contains('/purchase-orders/form')) {
      context.go('/admin/purchase-orders');
      return;
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/admin/customers');
    }
  }

  static const _breadcrumbMap = <String, String>{
    '/admin/purchase-orders/form': 'Inicio  ›  Órdenes de Compra  ›  Nueva Orden',
    '/admin/purchase-orders': 'Inicio  ›  Órdenes de Compra',
    '/admin/inventory-entries/form': 'Inicio  ›  Entradas de Inventario  ›  Nueva Entrada',
    '/admin/inventory-entries': 'Inicio  ›  Entradas de Inventario',
    '/admin/inventory-exits/form': 'Inicio  ›  Salidas de Inventario  ›  Nueva Salida',
    '/admin/inventory-exits': 'Inicio  ›  Salidas de Inventario',
    '/admin/products/form': 'Inicio  ›  Productos  ›  Formulario',
    '/admin/products': 'Inicio  ›  Productos',
    '/admin/catalog/form': 'Inicio  ›  Catálogo  ›  Formulario',
    '/admin/catalog': 'Inicio  ›  Catálogo',
    '/admin/users/form': 'Inicio  ›  Usuarios  ›  Formulario Usuario',
    '/admin/users': 'Inicio  ›  Usuarios',
    '/admin/customer-credit-movements': 'Inicio  ›  Créditos Clientes  ›  Movimientos',
    '/admin/customer-credits': 'Inicio  ›  Créditos Clientes',
    '/admin/customers/customer-detail': 'Inicio  ›  Clientes  ›  Detalle',
    '/admin/customers': 'Inicio  ›  Clientes',
    '/admin/supplier-credits': 'Inicio  ›  Créditos Proveedores',
    '/admin/suppliers': 'Inicio  ›  Proveedores',
    '/admin/orders': 'Inicio  ›  Pedidos',
    '/admin/kardex': 'Inicio  ›  Kardex',
    '/admin/financial-accounts': 'Inicio  ›  Cuentas Financieras',
    '/admin/categories': 'Inicio  ›  Categorías',
    '/admin/warehouses': 'Inicio  ›  Almacenes',
    '/admin/attributes': 'Inicio  ›  Atributos',
    '/admin/active-ingredients': 'Inicio  ›  Ingredientes Activos',
    '/admin/business-info': 'Inicio  ›  Información de la Empresa',
    '/admin/points-settings': 'Inicio  ›  Ajustes de Puntos',
    '/admin/inventory': 'Inicio  ›  Inventario',
    '/admin/dashboard': 'Inicio  ›  Dashboard',
  };

  String _buildBreadcrumbText(BuildContext context) {
    if (widget.breadcrumb != null && widget.breadcrumb!.isNotEmpty) {
      return widget.breadcrumb!;
    }
    try {
      final path = GoRouterState.of(context).uri.path;
      if (path.isEmpty || path == '/admin') {
        return 'Panel de Administración ERP';
      }

      for (final entry in _breadcrumbMap.entries) {
        if (path.startsWith(entry.key)) return entry.value;
      }
      return 'Panel de Administración ERP';
    } catch (e, st) {
      debugPrint('🔴 [AdminLayout] Error al construir breadcrumb: $e\n$st');
      return 'Panel de Administración ERP';
    }
  }

  Widget _buildDesktopTopBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // ── Toggle Sidebar Button ─────────────────────────────────
          AdminAppBarIconButton(
            icon:
                _isSidebarCollapsed
                    ? Icons.menu_open_rounded
                    : Icons.menu_rounded,
            tooltip: _isSidebarCollapsed ? 'Expandir menú' : 'Colapsar menú',
            onTap: _toggleSidebar,
          ),
          if (widget.showBackButton) ...[
            const SizedBox(width: 8),
            AdminAppBarIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Volver atrás',
              onTap:
                  () =>
                      _handleBackButton(context), 
            ),
          ],
          const SizedBox(width: 16),

          // ── Title & Breadcrumbs ───────────────────────────────────
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                _buildBreadcrumbText(context),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── Quick Custom Actions ──────────────────────────────────
          if (widget.actions != null) ...widget.actions!,
          if (widget.actions != null && widget.actions!.isNotEmpty)
            const SizedBox(width: 12),

          // ── Notifications Icon ────────────────────────────────────
          AdminAppBarIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notificaciones',
            onTap: () {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.notifications_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Notificaciones'),
                        ],
                      ),
                      content: const Text(
                        'No tienes notificaciones pendientes.\n\nEste módulo estará disponible próximamente.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Entendido'),
                        ),
                      ],
                    ),
              );
            },
          ),
          const SizedBox(width: 12),

          // ── Settings Dropdown ─────────────────────────────────────
          if (widget.showSettingsButton &&
              widget.settingsActions != null &&
              widget.settingsActions!.isNotEmpty) ...[
            AdminSettingsMenuButton(
              items: widget.settingsActions!,
              onSelected: widget.onSettingsSelected,
            ),
            const SizedBox(width: 12),
          ],

          // ── Admin Profile Dropdown Avatar ─────────────────────────
          PopupMenuButton<String>(
            tooltip: 'Opciones de perfil',
            offset: const Offset(0, 48),
            onSelected: (value) {
              if (value == 'profile') context.push('/admin/profile');
              if (value == 'business') context.go('/admin/business-info');
              if (value == 'logout') context.read<AuthCubit>().logout();
            },
            itemBuilder:
                (ctx) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Mi Perfil'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'business',
                    child: Row(
                      children: [
                        Icon(Icons.storefront_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Datos de Negocio'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Cerrar Sesión',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
            child: const AdminProfileAvatar(),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return BlocBuilder<NetworkCubit, NetworkState>(
      builder: (context, state) {
        final isOnline = state is NetworkConnected;
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child:
              isOnline
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        color: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Sin conexión a internet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const OfflineGamesSuggestion(),
                    ],
                  ),
        );
      },
    );
  }
}

/// Botón circular para la AppBar
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
    final button = Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

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
    return PopupMenuButton<String>(
      tooltip: 'Opciones',
      offset: const Offset(0, 45),
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          size: 18,
          color: AppColors.textSecondary,
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
