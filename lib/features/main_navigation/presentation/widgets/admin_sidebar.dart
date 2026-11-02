import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/auth/domain/entities/auth_user_entity.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_menu_builder.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_sidebar_models.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/sidebar_brand_header.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/sidebar_collapsible_label.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/sidebar_expandable_group.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/sidebar_nav_tile.dart';

// Re-exportamos los modelos para mantener total retrocompatibilidad
export 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_sidebar_models.dart';

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
    final currentPath = GoRouterState.of(context).uri.path;

    // ── Optimización Crítica: Suscripción granular a permisos ─────────────────
    // Evita reconstruir los 30+ ítems ante eventos ajenos de AuthCubit (tokens, pings).
    final currentUser = context.select<AuthCubit, AuthUserEntity?>(
      (c) => c.state.currentUser,
    );
    final isAdmin = currentUser?.isAdmin ?? false;

    bool can(String perm) =>
        isAdmin || (currentUser?.hasPermission(perm) ?? false);
    bool canAny(Iterable<String> perms) =>
        isAdmin || (currentUser?.hasAnyPermission(perms) ?? false);

    final canViewCatalog = canAny([
      AppPermissions.productsView,
      AppPermissions.inventoryView,
    ]);
    final canViewOrders = canAny([
      AppPermissions.posView,
      AppPermissions.posSale,
    ]);
    final canViewSettings = can(AppPermissions.settingsView);

    final loyaltyEnabled = context.select<AppConfigCubit, bool>(
      (c) => c.state.businessInfo?.loyaltyGlobalEnabled ?? false,
    );

    // ── Resolución limpia de menús ───────────────────────────────────────────
    final inventoryChildren = AdminMenuBuilder.buildInventoryChildren(can);
    final purchasesChildren = AdminMenuBuilder.buildPurchasesChildren(
      isAdmin: isAdmin,
      can: can,
      canAny: canAny,
    );
    final customersChildren = AdminMenuBuilder.buildCustomersChildren(
      isAdmin: isAdmin,
      canAny: canAny,
    );
    final mastersChildren = AdminMenuBuilder.buildMastersChildren(
      isAdmin: isAdmin,
      canAny: canAny,
    );
    final systemChildren = AdminMenuBuilder.buildSystemChildren(
      isAdmin: isAdmin,
      can: can,
      canAny: canAny,
      loyaltyEnabled: loyaltyEnabled,
    );

    final hasCommercialSection =
        canViewOrders ||
        inventoryChildren.isNotEmpty ||
        purchasesChildren.isNotEmpty ||
        customersChildren.isNotEmpty;

    final hasErpSection =
        mastersChildren.isNotEmpty || systemChildren.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
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
          // ── Brand / Header ─────────────────────────────────────────
          SidebarBrandHeader(
            isCollapsed: widget.isCollapsed,
            onToggleCollapse: widget.onToggleCollapse,
          ),
          Divider(
            height: 1,
            color:
                isDark ? AppColors.darkSidebarBorder : AppColors.sidebarBorder,
          ),

          // ── Items List con Scroll Persistente y Barra Estilizada ─────
          Expanded(
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
                    _buildSectionHeader(context, 'MENÚ PRINCIPAL'),

                  SidebarNavTile(
                    item: const AdminSidebarItem(
                      icon: Icons.bar_chart_rounded,
                      title: 'Dashboard',
                      routePath: '/',
                    ),
                    isCollapsed: widget.isCollapsed,
                    currentPath: currentPath,
                  ),

                  if (canViewCatalog)
                    SidebarNavTile(
                      item: const AdminSidebarItem(
                        icon: Icons.grid_view_rounded,
                        title: 'Catálogo',
                        routePath: '/catalog',
                      ),
                      isCollapsed: widget.isCollapsed,
                      currentPath: currentPath,
                    ),

                  if (hasCommercialSection && !widget.isCollapsed) ...[
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color:
                          isDark
                              ? AppColors.darkSidebarBorder
                              : AppColors.sidebarBorder,
                    ),
                    _buildSectionHeader(context, 'GESTIÓN COMERCIAL'),
                  ],

                  if (canViewOrders)
                    BlocBuilder<SidebarBadgeCubit, SidebarBadgeState>(
                      builder: (ctx, state) {
                        Widget? badge;
                        if (state is SidebarBadgeLoaded && state.count > 0) {
                          badge = _buildBadge(state.count);
                        } else if (state is SidebarBadgeError) {
                          badge = const Icon(
                            Icons.warning_rounded,
                            color: AppColors.error,
                            size: 14,
                          );
                        }

                        return SidebarNavTile(
                          item: AdminSidebarItem(
                            icon: Icons.receipt_long_rounded,
                            title: 'Pedidos',
                            routePath: '/orders',
                            trailing: badge,
                          ),
                          isCollapsed: widget.isCollapsed,
                          currentPath: currentPath,
                        );
                      },
                    ),

                  if (inventoryChildren.isNotEmpty)
                    SidebarExpandableGroup(
                      isCollapsed: widget.isCollapsed,
                      currentPath: currentPath,
                      item: AdminSidebarItem(
                        icon: Icons.inventory_2_outlined,
                        title: 'Inventario',
                        routePath: '',
                        children: inventoryChildren,
                      ),
                    ),

                  if (purchasesChildren.isNotEmpty)
                    SidebarExpandableGroup(
                      isCollapsed: widget.isCollapsed,
                      currentPath: currentPath,
                      item: AdminSidebarItem(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Compras',
                        routePath: '',
                        children: purchasesChildren,
                      ),
                    ),

                  if (customersChildren.isNotEmpty)
                    SidebarExpandableGroup(
                      isCollapsed: widget.isCollapsed,
                      currentPath: currentPath,
                      item: AdminSidebarItem(
                        icon: Icons.people_outline_rounded,
                        title: 'Clientes y Créditos',
                        routePath: '',
                        children: customersChildren,
                      ),
                    ),

                  if (hasErpSection && !widget.isCollapsed) ...[
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color:
                          isDark
                              ? AppColors.darkSidebarBorder
                              : AppColors.sidebarBorder,
                    ),
                    _buildSectionHeader(context, 'CONFIGURACIÓN ERP'),
                  ],

                  if (mastersChildren.isNotEmpty)
                    SidebarExpandableGroup(
                      isCollapsed: widget.isCollapsed,
                      currentPath: currentPath,
                      item: AdminSidebarItem(
                        icon: Icons.category_outlined,
                        title: 'Maestros / Catálogos',
                        routePath: '',
                        children: mastersChildren,
                      ),
                    ),

                  if (systemChildren.isNotEmpty)
                    SidebarExpandableGroup(
                      isCollapsed: widget.isCollapsed,
                      currentPath: currentPath,
                      item: AdminSidebarItem(
                        icon: Icons.settings_outlined,
                        title: 'Configuración del Sistema',
                        routePath: '',
                        children: systemChildren,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Pinned Bottom Actions: Settings & Help ──
          Divider(
            height: 1,
            color:
                isDark ? AppColors.darkSidebarBorder : AppColors.sidebarBorder,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                if (canViewSettings)
                  _buildActionTile(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Configuraciones',
                    isSelected: currentPath == '/settings',
                    onTap: () => context.go('/settings'),
                  ),
                _buildActionTile(
                  context,
                  icon: Icons.help_outline_rounded,
                  title: 'Ayuda y Soporte',
                  isSelected: currentPath == '/help',
                  onTap: () => context.go('/help'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          hoverColor:
              isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 38,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCollapsed ? 0 : 10,
            ),
            decoration:
                isSelected
                    ? BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                              : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isDark
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                                : const Color(0xFFBFDBFE),
                      ),
                    )
                    : const BoxDecoration(),
            child: ClipRect(
              child: Row(
                mainAxisAlignment:
                    widget.isCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color:
                        isSelected
                            ? const Color(0xFF3B82F6)
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B)),
                  ),
                  CollapsibleLabel(
                    collapsed: widget.isCollapsed,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 170),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                              color:
                                  isSelected
                                      ? (isDark
                                          ? const Color(0xFF93C5FD)
                                          : const Color(0xFF1D4ED8))
                                      : (isDark
                                          ? AppColors.darkTextSecondary
                                          : const Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      key: ValueKey(count),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
