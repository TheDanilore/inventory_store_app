import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_menu_builder.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_sidebar_models.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/pending_orders_badge.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/sidebar_brand_header.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/sidebar_expandable_group.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/sidebar_nav_tile.dart';

// Re-exportamos los modelos para mantener total retrocompatibilidad.
export 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_sidebar_models.dart';

/// Sidebar de escritorio optimizado en memoria y CPU.
///
/// Usa un único [AnimatedContainer] para la transición de ancho,
/// suscripciones granulares `context.select` para permisos y lealtad,
/// [AdminMenuBuilder] como fuente única de verdad RBAC y [PendingOrdersBadge]
/// con soporte Zero-Shimmer.
class AdminSidebar extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const AdminSidebar({
    super.key,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: SidebarNavigationMemory.scrollOffset,
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      SidebarNavigationMemory.scrollOffset = _scrollController.offset;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = widget.isCollapsed ? 72.0 : 272.0;
    final currentPath =
        GoRouter.maybeOf(
          context,
        )?.routerDelegate.currentConfiguration.uri.path ??
        '';

    final authData = context
        .select<AuthCubit, ({bool isAdmin, Set<String> permissions})>(
          (c) => (
            isAdmin: c.state.currentUser?.isAdmin ?? false,
            permissions: c.state.currentUser?.permissions ?? const <String>{},
          ),
        );

    final loyaltyEnabled = context.select<AppConfigCubit, bool>(
      (c) => c.state.businessInfo?.loyaltyGlobalEnabled ?? false,
    );

    final menu = AdminMenuBuilder.buildMenu(
      isAdmin: authData.isAdmin,
      permissions: authData.permissions,
      loyaltyEnabled: loyaltyEnabled,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSidebarBg : AppColors.sidebarBg,
        border: Border(
          right: BorderSide(
            color:
                isDark ? AppColors.darkSidebarBorder : AppColors.sidebarBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          SidebarBrandHeader(
            isCollapsed: widget.isCollapsed,
            onToggleCollapse: widget.onToggleCollapse,
          ),
          Divider(
            height: 1,
            color:
                isDark ? AppColors.darkSidebarBorder : AppColors.sidebarBorder,
          ),
          Expanded(
            child: RepaintBoundary(
              child: RawScrollbar(
                controller: _scrollController,
                thumbColor: (isDark
                        ? AppColors.darkSidebarText
                        : AppColors.sidebarText)
                    .withValues(alpha: 0.22),
                radius: const Radius.circular(4),
                thickness: 4,
                padding: const EdgeInsets.only(right: 2),
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    if (!widget.isCollapsed)
                      _SectionHeader(isDark: isDark, title: 'MENÚ PRINCIPAL'),
                    SidebarNavTile(
                      item: const AdminSidebarItem(
                        icon: Icons.bar_chart_rounded,
                        title: 'Dashboard',
                        routePath: '/',
                      ),
                      isCollapsed: widget.isCollapsed,
                      currentPath: currentPath,
                    ),
                    if (menu.canViewCatalog)
                      SidebarNavTile(
                        item: const AdminSidebarItem(
                          icon: Icons.grid_view_rounded,
                          title: 'Catálogo',
                          routePath: '/catalog',
                        ),
                        isCollapsed: widget.isCollapsed,
                        currentPath: currentPath,
                      ),
                    if (menu.hasCommercialSection && !widget.isCollapsed) ...[
                      const SizedBox(height: 12),
                      _SidebarDivider(isDark: isDark),
                      _SectionHeader(
                        isDark: isDark,
                        title: 'GESTIÓN COMERCIAL',
                      ),
                    ],
                    if (menu.canViewOrders)
                      SidebarNavTile(
                        item: const AdminSidebarItem(
                          icon: Icons.receipt_long_rounded,
                          title: 'Pedidos',
                          routePath: '/orders',
                          trailing: PendingOrdersBadge(compact: true),
                        ),
                        isCollapsed: widget.isCollapsed,
                        currentPath: currentPath,
                      ),
                    if (menu.inventoryChildren.isNotEmpty)
                      SidebarExpandableGroup(
                        isCollapsed: widget.isCollapsed,
                        currentPath: currentPath,
                        item: AdminSidebarItem(
                          icon: Icons.inventory_2_outlined,
                          title: 'Inventario',
                          routePath: '',
                          children: menu.inventoryChildren,
                        ),
                      ),
                    if (menu.purchasesChildren.isNotEmpty)
                      SidebarExpandableGroup(
                        isCollapsed: widget.isCollapsed,
                        currentPath: currentPath,
                        item: AdminSidebarItem(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Compras',
                          routePath: '',
                          children: menu.purchasesChildren,
                        ),
                      ),
                    if (menu.customersChildren.isNotEmpty)
                      SidebarExpandableGroup(
                        isCollapsed: widget.isCollapsed,
                        currentPath: currentPath,
                        item: AdminSidebarItem(
                          icon: Icons.people_outline_rounded,
                          title: 'Clientes y Créditos',
                          routePath: '',
                          children: menu.customersChildren,
                        ),
                      ),
                    if (menu.hasErpSection && !widget.isCollapsed) ...[
                      const SizedBox(height: 12),
                      _SidebarDivider(isDark: isDark),
                      _SectionHeader(
                        isDark: isDark,
                        title: 'CONFIGURACIÓN ERP',
                      ),
                    ],
                    if (menu.mastersChildren.isNotEmpty)
                      SidebarExpandableGroup(
                        isCollapsed: widget.isCollapsed,
                        currentPath: currentPath,
                        item: AdminSidebarItem(
                          icon: Icons.category_outlined,
                          title: 'Maestros / Catálogos',
                          routePath: '',
                          children: menu.mastersChildren,
                        ),
                      ),
                    if (menu.systemChildren.isNotEmpty)
                      SidebarExpandableGroup(
                        isCollapsed: widget.isCollapsed,
                        currentPath: currentPath,
                        item: AdminSidebarItem(
                          icon: Icons.settings_outlined,
                          title: 'Configuración del Sistema',
                          routePath: '',
                          children: menu.systemChildren,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            color:
                isDark ? AppColors.darkSidebarBorder : AppColors.sidebarBorder,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                if (menu.canViewSettings)
                  SidebarNavTile(
                    item: const AdminSidebarItem(
                      icon: Icons.settings_outlined,
                      title: 'Configuraciones',
                      routePath: '/settings',
                    ),
                    isCollapsed: widget.isCollapsed,
                    isSubItem: true,
                    currentPath: currentPath,
                  ),
                SidebarNavTile(
                  item: const AdminSidebarItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Ayuda y Soporte',
                    routePath: '/help',
                  ),
                  isCollapsed: widget.isCollapsed,
                  isSubItem: true,
                  currentPath: currentPath,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final bool isDark;
  final String title;

  const _SectionHeader({required this.isDark, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color:
                isDark
                    ? AppColors.darkSidebarSectionHeader
                    : const Color(0xFF94A3B8),
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  final bool isDark;

  const _SidebarDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? AppColors.darkSidebarBorder : AppColors.sidebarBorder,
    );
  }
}
