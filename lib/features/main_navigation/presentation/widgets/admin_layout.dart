import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/app_drawer.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_sidebar.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_offline_banner.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_desktop_top_bar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_shell_layout.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/notifications/notification_bell.dart';
import 'package:inventory_store_app/core/utils/app_back_handler.dart';
export 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_shell_layout.dart';

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

  bool _isSidebarCollapsed = AdminShellLayout.cachedSidebarCollapsed;

  @override
  void initState() {
    super.initState();
    if (!AdminShellLayout.hasLoadedFromPrefs) {
      _loadSidebarState();
    }
    _scheduleHeaderUpdate();
  }

  @override
  void didUpdateWidget(AdminLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.actions != widget.actions ||
        oldWidget.showBackButton != widget.showBackButton ||
        oldWidget.breadcrumb != widget.breadcrumb ||
        oldWidget.floatingActionButton != widget.floatingActionButton ||
        oldWidget.bottomNavigationBar != widget.bottomNavigationBar ||
        oldWidget.showSettingsButton != widget.showSettingsButton) {
      _scheduleHeaderUpdate();
    }
  }

  void _scheduleHeaderUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Prevenir que pantallas inactivas pausadas en el navigator stack sobreescriban
      // la cabecera activa de la pantalla visible actual.
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;

      final shell = AdminShellScope.maybeOf(context);
      if (shell != null) {
        shell.updateHeader(
          AdminHeaderConfig(
            title: widget.title,
            breadcrumb: widget.breadcrumb,
            actions: widget.actions,
            showBackButton: widget.showBackButton,
            onBack: () => _handleBackButton(context),
            showSettingsButton: widget.showSettingsButton,
            settingsActions: widget.settingsActions,
            onSettingsSelected: widget.onSettingsSelected,
            floatingActionButton: widget.floatingActionButton,
            bottomNavigationBar: widget.bottomNavigationBar,
            showAppBar: widget.showAppBar,
            showProfileButton: widget.showProfileButton,
            showDrawerButton: widget.showDrawerButton,
          ),
        );
      }
    });
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
        'Error loading sidebar state in AdminLayout',
        error: e,
        stackTrace: st,
        tag: 'AdminLayout',
      );
      AdminShellLayout.hasLoadedFromPrefs = true;
    }
  }

  void _openProfile(BuildContext context) {
    // Usa AuthCubit (fuente de verdad) en lugar del SDK de Supabase
    // para evitar navegar con tokens expirados pero cacheados.
    final user = context.read<AuthCubit>().state.currentUser;
    if (user == null) {
      context.go('/login');
    } else {
      context.go('/profile');
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
        'Error saving sidebar state in AdminLayout',
        error: e,
        stackTrace: st,
        tag: 'AdminLayout',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = AdminShellScope.maybeOf(context);

    // ── Optimización Crítica: Cortocircuito Unificado (Desktop y Mobile) ────
    // Cuando el AdminShellLayout persistente está activo en el árbol (Desktop o Mobile),
    // él ya provee: Scaffold raíz, Sidebar/Drawer, TopBar/AppBar, OfflineBanner y SafeArea.
    // AdminLayout NO duplica Scaffolds — entrega directamente el body en un Scaffold
    // transparente para conservar soporte opcional a FABs locales.
    // Esto elimina: N Scaffolds anidados, N AppBars duplicadas, parpadeos y LayoutBuilders redundantes.
    if (shell != null) {
      // El shell ya renderiza bottomNavigationBar y floatingActionButton
      // (vía AdminHeaderConfig). No duplicarlos aquí.
      return Scaffold(backgroundColor: Colors.transparent, body: widget.body);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Fallback: Standalone Desktop o Mobile/Tablet ──────────────────────────
    // Cuando no hay AdminShellLayout (p. ej. pantalla autónoma o mobile),
    // se construye la estructura completa con Sidebar/AppBar propios.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;

          // ── 2. Modo Autónomo (Standalone Desktop sin Persistent Shell) ──
          if (isDesktop) {
            return AppPopScope(
              onCustomBack: widget.onBack,
              child: Scaffold(
                backgroundColor: AppColors.bg(context),
                body: Row(
                  children: [
                    AdminSidebar(
                      isCollapsed: _isSidebarCollapsed,
                      onToggleCollapse: _toggleSidebar,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          AdminDesktopTopBar(
                            isSidebarCollapsed: _isSidebarCollapsed,
                            onToggleSidebar: _toggleSidebar,
                            showBackButton: widget.showBackButton,
                            onBack: () => _handleBackButton(context),
                            title: widget.title,
                            breadcrumbText: _buildBreadcrumbText(context),
                            actions: widget.actions,
                            showSettingsButton: widget.showSettingsButton,
                            settingsActions: widget.settingsActions,
                            onSettingsSelected: widget.onSettingsSelected,
                          ),
                          const AdminOfflineBanner(),
                          Expanded(child: widget.body),
                        ],
                      ),
                    ),
                  ],
                ),
                floatingActionButton: widget.floatingActionButton,
                bottomNavigationBar: widget.bottomNavigationBar,
              ),
            );
          }

          // ── Mobile / Tablet Layout ──────────────────────────────────────────
          return AppPopScope(
            onCustomBack: widget.onBack,
            child: Scaffold(
              backgroundColor: AppColors.bg(context),
              drawerScrimColor:
                  isDark
                      ? Colors.black.withValues(alpha: 0.65)
                      : Colors.black45,
              endDrawer:
                  widget.showDrawerButton
                      ? const AppDrawer(isAdmin: true)
                      : null,
              appBar:
                  widget.showAppBar
                      ? AppBar(
                        backgroundColor:
                            isDark ? AppColors.darkSurface : AppColors.surface,
                        elevation: 0,
                        shadowColor: Colors.black.withValues(alpha: 0.06),
                        surfaceTintColor: Colors.transparent,
                        titleSpacing: 0,
                        leadingWidth: widget.showBackButton ? 52 : 46,
                        leading:
                            widget.showBackButton
                                ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: AdminAppBarIconButton(
                                      icon: Icons.arrow_back_ios_new_rounded,
                                      tooltip: 'Volver',
                                      onTap: () => _handleBackButton(context),
                                    ),
                                  ),
                                )
                                : Padding(
                                  padding: const EdgeInsets.only(left: 14),
                                  child: Center(
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color:
                                            isDark
                                                ? const Color(0xFF1E293B)
                                                : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              isDark
                                                  ? const Color(0xFF334155)
                                                  : const Color(0xFFDBEAFE),
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
                            widget.showBackButton
                                ? Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          isDark
                                              ? AppColors.darkTextPrimary
                                              : AppColors.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                )
                                : Padding(
                                  padding: const EdgeInsets.only(left: 4),
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
                                                  ? AppColors.darkTextPrimary
                                                  : const Color(0xFF0F172A),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ONE',
                                        style: TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w900,
                                          color:
                                              isDark
                                                  ? const Color(0xFF60A5FA)
                                                  : const Color(0xFF2563EB),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        actions: [
                          if (widget.actions != null)
                            ...widget.actions!.where(
                              (a) => !_isRefreshWidget(a),
                            ),
                          if (widget.actions != null &&
                              widget.actions!
                                  .where((a) => !_isRefreshWidget(a))
                                  .isNotEmpty)
                            const SizedBox(width: 6),

                          if (widget.showSettingsButton &&
                              widget.settingsActions != null &&
                              widget.settingsActions!.isNotEmpty) ...[
                            AdminSettingsMenuButton(
                              items: widget.settingsActions!,
                              onSelected: widget.onSettingsSelected,
                            ),
                            const SizedBox(width: 6),
                          ],

                          const NotificationBell(),
                          const SizedBox(width: 6),

                          if (widget.showDrawerButton)
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

                          if (widget.showProfileButton) ...[
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
                top: !widget.showAppBar,
                bottom: false,
                child: Column(
                  children: [
                    const AdminOfflineBanner(),
                    Expanded(child: widget.body),
                  ],
                ),
              ),
              floatingActionButton: widget.floatingActionButton,
              bottomNavigationBar: widget.bottomNavigationBar,
            ),
          );
        },
      ),
    );
  }

  // Lógica unificada del botón atrás del SO y AppBar
  void _handleBackButton(BuildContext context) {
    AppBackHandler.handleBack(context, onCustomBack: widget.onBack);
  }

  String _buildBreadcrumbText(BuildContext context) {
    if (widget.breadcrumb != null && widget.breadcrumb!.isNotEmpty) {
      return widget.breadcrumb!;
    }
    try {
      final path = GoRouterState.of(context).uri.path;
      return AdminShellHelper.resolveBreadcrumb(path);
    } catch (e, st) {
      LoggerService.e(
        'Error al construir breadcrumb',
        error: e,
        stackTrace: st,
        tag: 'AdminLayout',
      );
      return 'Panel de Administración ERP';
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
}
