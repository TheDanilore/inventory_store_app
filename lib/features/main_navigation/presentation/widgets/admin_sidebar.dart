import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_state.dart';

class AdminSidebarItem {
  final IconData icon;
  final String title;
  final String routePath;
  final Widget? trailing;
  final List<AdminSidebarItem> children;

  const AdminSidebarItem({
    required this.icon,
    required this.title,
    required this.routePath,
    this.trailing,
    this.children = const [],
  });
}

/// Memoria de navegación estática para retener la posición exacta de scroll
/// y los grupos expandidos a través de transiciones de ruta en el ERP.
class SidebarNavigationMemory {
  static double scrollOffset = 0.0;
  static final Set<String> expandedGroups = {};
}

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
    final width = widget.isCollapsed ? 72.0 : 260.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(
          right: BorderSide(color: AppColors.sidebarBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Brand / Header ─────────────────────────────────────────
          _buildBrandHeader(context),
          const Divider(height: 1, color: AppColors.sidebarBorder),

          // ── Items List con Scroll Persistente y Barra Estilizada ─────
          Expanded(
            child: RawScrollbar(
              controller: _scrollController,
              thumbColor: AppColors.sidebarText.withValues(alpha: 0.22),
              radius: const Radius.circular(4),
              thickness: 4,
              padding: const EdgeInsets.only(right: 2),
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  if (!widget.isCollapsed)
                    _buildSectionHeader('MENÚ PRINCIPAL'),
                  _buildSidebarTile(
                    context,
                    const AdminSidebarItem(
                      icon: Icons.grid_view_rounded,
                      title: 'Catálogo',
                      routePath: '/',
                    ),
                  ),
                  _buildSidebarTile(
                    context,
                    const AdminSidebarItem(
                      icon: Icons.bar_chart_rounded,
                      title: 'Dashboard',
                      routePath: '/dashboard',
                    ),
                  ),

                  if (!widget.isCollapsed) ...[
                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppColors.sidebarBorder,
                    ),
                    _buildSectionHeader('GESTIÓN COMERCIAL'),
                  ],

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

                      return _buildSidebarTile(
                        context,
                        AdminSidebarItem(
                          icon: Icons.receipt_long_rounded,
                          title: 'Pedidos',
                          routePath: '/orders',
                          trailing: badge,
                        ),
                      );
                    },
                  ),

                  _ExpandableSidebarGroup(
                    isCollapsed: widget.isCollapsed,
                    item: const AdminSidebarItem(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Compras',
                      routePath: '',
                      children: [
                        AdminSidebarItem(
                          icon: Icons.receipt_long_rounded,
                          title: 'Órdenes de compra',
                          routePath: '/purchase-orders',
                        ),
                        AdminSidebarItem(
                          icon: Icons.add_rounded,
                          title: 'Entradas inventario',
                          routePath: '/inventory-entries',
                        ),
                        AdminSidebarItem(
                          icon: Icons.credit_score_rounded,
                          title: 'Créditos proveedores',
                          routePath: '/supplier-credits',
                        ),
                        AdminSidebarItem(
                          icon: Icons.local_shipping_outlined,
                          title: 'Proveedores',
                          routePath: '/suppliers',
                        ),
                      ],
                    ),
                  ),

                  _ExpandableSidebarGroup(
                    isCollapsed: widget.isCollapsed,
                    item: const AdminSidebarItem(
                      icon: Icons.inventory_2_outlined,
                      title: 'Inventario',
                      routePath: '',
                      children: [
                        AdminSidebarItem(
                          icon: Icons.category_outlined,
                          title: 'Productos',
                          routePath: '/products',
                        ),
                        AdminSidebarItem(
                          icon: Icons.grid_view_rounded,
                          title: 'Stock inventario',
                          routePath: '/inventory',
                        ),
                        AdminSidebarItem(
                          icon: Icons.article_outlined,
                          title: 'Kardex',
                          routePath: '/kardex',
                        ),
                        AdminSidebarItem(
                          icon: Icons.remove_rounded,
                          title: 'Salidas inventario',
                          routePath: '/inventory-exits',
                        ),
                      ],
                    ),
                  ),

                  _ExpandableSidebarGroup(
                    isCollapsed: widget.isCollapsed,
                    item: const AdminSidebarItem(
                      icon: Icons.people_outline_rounded,
                      title: 'Clientes y Créditos',
                      routePath: '',
                      children: [
                        AdminSidebarItem(
                          icon: Icons.person_outline_rounded,
                          title: 'Clientes',
                          routePath: '/customers',
                        ),
                        AdminSidebarItem(
                          icon: Icons.credit_score_rounded,
                          title: 'Créditos clientes',
                          routePath: '/customer-credits',
                        ),
                      ],
                    ),
                  ),

                  if (!widget.isCollapsed) ...[
                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppColors.sidebarBorder,
                    ),
                    _buildSectionHeader('CONFIGURACIÓN ERP'),
                  ],

                  _buildSidebarTile(
                    context,
                    const AdminSidebarItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Cuentas',
                      routePath: '/financial-accounts',
                    ),
                  ),
                  _buildSidebarTile(
                    context,
                    const AdminSidebarItem(
                      icon: Icons.category_outlined,
                      title: 'Categorías',
                      routePath: '/categories',
                    ),
                  ),
                  _buildSidebarTile(
                    context,
                    const AdminSidebarItem(
                      icon: Icons.branding_watermark_outlined,
                      title: 'Marcas',
                      routePath: '/brands',
                    ),
                  ),
                  _buildSidebarTile(
                    context,
                    const AdminSidebarItem(
                      icon: Icons.warehouse_outlined,
                      title: 'Almacenes',
                      routePath: '/warehouses',
                    ),
                  ),
                  _buildSidebarTile(
                    context,
                    const AdminSidebarItem(
                      icon: Icons.tune_rounded,
                      title: 'Atributos',
                      routePath: '/attributes',
                    ),
                  ),
                  _buildSidebarTile(
                    context,
                    const AdminSidebarItem(
                      icon: Icons.science_rounded,
                      title: 'Ingredientes Activos',
                      routePath: '/active-ingredients',
                    ),
                  ),
                  _buildSidebarTile(
                    context,
                    const AdminSidebarItem(
                      icon: Icons.people_outline_rounded,
                      title: 'Usuarios',
                      routePath: '/users',
                    ),
                  ),
                  _buildSidebarTile(
                    context,
                    const AdminSidebarItem(
                      icon: Icons.storefront_rounded,
                      title: 'Negocio',
                      routePath: '/business-info',
                    ),
                  ),
                  BlocSelector<AppConfigCubit, AppConfigState, bool>(
                    selector:
                        (s) => s.businessInfo?.loyaltyGlobalEnabled ?? false,
                    builder: (context, loyaltyEnabled) {
                      if (!loyaltyEnabled) return const SizedBox.shrink();
                      return _buildSidebarTile(
                        context,
                        const AdminSidebarItem(
                          icon: Icons.stars_rounded,
                          title: 'Puntos y Monedas',
                          routePath: '/points-settings',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── DANILORE Cloud / Pro Status Card (Shopeers / Apple Style) ─
          if (!widget.isCollapsed) _buildCloudStatusCard(),

          // ── Collapse / Expand Footer Action ────────────────────────
          const Divider(height: 1, color: AppColors.sidebarBorder),
          InkWell(
            onTap: widget.onToggleCollapse,
            hoverColor: const Color(0xFFF1F5F9),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment:
                    widget.isCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceBetween,
                children: [
                  if (!widget.isCollapsed)
                    const Text(
                      'Colapsar menú',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  Icon(
                    widget.isCollapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudStatusCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A), // Navy 900
            Color(0xFF2563EB), // Blue 600
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_done_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'DANILORE Cloud',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'ERP activo con sincronización de inventario en tiempo real.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 10.5,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Servidor En Línea',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 0 : 16),
      child: ClipRect(
        child: Row(
          mainAxisAlignment:
              widget.isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
              ),
              child: Image.asset('assets/logo_icon.png', fit: BoxFit.contain),
            ),
            if (!widget.isCollapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: BlocSelector<AppConfigCubit, AppConfigState, String>(
                  selector:
                      (state) =>
                          state.businessInfo?.businessName ?? 'DANILORE ONE',
                  builder: (context, name) {
                    final isDefault =
                        name.trim().isEmpty ||
                        name == 'ERP Tienda' ||
                        name == 'Mi Tienda' ||
                        name.toUpperCase().contains('DANILORE');

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isDefault)
                          const Row(
                            children: [
                              Text(
                                'DANILORE ',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              Text(
                                'ONE',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2563EB),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        Text(
                          isDefault
                              ? 'Todo tu negocio en un solo lugar'
                              : 'DANILORE ONE ERP',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  bool _isItemActive(String routePath, String currentPath) {
    if (routePath.isEmpty) return false;
    if (currentPath == routePath) return true;
    if (routePath != '/' && currentPath.startsWith('$routePath/')) {
      return true;
    }
    return false;
  }

  Widget _buildSidebarTile(BuildContext context, AdminSidebarItem item) {
    return Builder(
      builder: (context) {
        final currentPath = GoRouterState.of(context).uri.path;
        final isActive = _isItemActive(item.routePath, currentPath);

        final tile = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.go(item.routePath),
              hoverColor: const Color(0xFFF1F5F9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      isActive ? const Color(0xFFEFF6FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      isActive
                          ? Border.all(color: const Color(0xFFDBEAFE), width: 1)
                          : Border.all(color: Colors.transparent, width: 1),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isCollapsed ? 0 : 10,
                ),
                child: ClipRect(
                  child: Row(
                    mainAxisAlignment:
                        widget.isCollapsed
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                    children: [
                      // Linear / Stripe Active Indicator Bar
                      if (!widget.isCollapsed && isActive)
                        Container(
                          width: 3.5,
                          height: 18,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF2563EB,
                                ).withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      Icon(
                        item.icon,
                        size: 20,
                        color:
                            isActive
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF64748B),
                      ),
                      if (!widget.isCollapsed) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: -0.2,
                              fontWeight:
                                  isActive ? FontWeight.w700 : FontWeight.w500,
                              color:
                                  isActive
                                      ? const Color(0xFF1E40AF)
                                      : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        if (item.trailing != null) item.trailing!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        if (widget.isCollapsed) {
          return Tooltip(
            message: item.title,
            preferBelow: false,
            verticalOffset: 0,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            child: tile,
          );
        }
        return tile;
      },
    );
  }

  Widget _buildBadge(int count) {
    return Container(
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

class _ExpandableSidebarGroup extends StatefulWidget {
  final AdminSidebarItem item;
  final bool isCollapsed;

  const _ExpandableSidebarGroup({
    required this.item,
    required this.isCollapsed,
  });

  @override
  State<_ExpandableSidebarGroup> createState() =>
      _ExpandableSidebarGroupState();
}

class _ExpandableSidebarGroupState extends State<_ExpandableSidebarGroup> {
  bool _isItemActive(String routePath, String currentPath) {
    if (routePath.isEmpty) return false;
    if (currentPath == routePath) return true;
    if (routePath != '/' && currentPath.startsWith('$routePath/')) {
      return true;
    }
    return false;
  }

  Widget _buildSidebarTile(BuildContext context, AdminSidebarItem item) {
    final currentPath = GoRouterState.of(context).uri.path;
    final isActive = _isItemActive(item.routePath, currentPath);

    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(item.routePath),
          hoverColor: const Color(0xFFF1F5F9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 38,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFEFF6FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border:
                  isActive
                      ? Border.all(color: const Color(0xFFDBEAFE), width: 1)
                      : Border.all(color: Colors.transparent, width: 1),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCollapsed ? 0 : 10,
            ),
            child: ClipRect(
              child: Row(
                mainAxisAlignment:
                    widget.isCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                children: [
                  if (!widget.isCollapsed && isActive)
                    Container(
                      width: 3.5,
                      height: 16,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  Icon(
                    item.icon,
                    size: 19,
                    color:
                        isActive
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B),
                  ),
                  if (!widget.isCollapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: -0.2,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color:
                              isActive
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    if (item.trailing != null) item.trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.isCollapsed) {
      return Tooltip(message: item.title, child: tile);
    }
    return tile;
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final hasActiveChild = widget.item.children.any(
      (sub) => _isItemActive(sub.routePath, currentPath),
    );
    // Sincronizar persistencia: si tiene un hijo activo, se mantiene abierto
    if (hasActiveChild) {
      SidebarNavigationMemory.expandedGroups.add(widget.item.title);
    }
    final isOpen = SidebarNavigationMemory.expandedGroups.contains(
      widget.item.title,
    );

    if (widget.isCollapsed) {
      return PopupMenuButton<String>(
        tooltip: widget.item.title,
        offset: const Offset(60, 0),
        onSelected: (route) => context.go(route),
        itemBuilder:
            (ctx) =>
                widget.item.children
                    .map(
                      (sub) => PopupMenuItem(
                        value: sub.routePath,
                        child: Row(
                          children: [
                            Icon(
                              sub.icon,
                              size: 18,
                              color: const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 10),
                            Text(sub.title),
                          ],
                        ),
                      ),
                    )
                    .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  hasActiveChild ? const Color(0xFFEFF6FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border:
                  hasActiveChild
                      ? Border.all(color: const Color(0xFFDBEAFE), width: 1)
                      : null,
            ),
            child: Icon(
              widget.item.icon,
              size: 20,
              color:
                  hasActiveChild
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  if (SidebarNavigationMemory.expandedGroups.contains(
                    widget.item.title,
                  )) {
                    SidebarNavigationMemory.expandedGroups.remove(
                      widget.item.title,
                    );
                  } else {
                    SidebarNavigationMemory.expandedGroups.add(
                      widget.item.title,
                    );
                  }
                });
              },
              hoverColor: const Color(0xFFF1F5F9),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(
                      widget.item.icon,
                      size: 20,
                      color:
                          hasActiveChild
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: -0.2,
                          fontWeight:
                              hasActiveChild
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                          color:
                              hasActiveChild
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState:
              isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.only(left: 20, right: 8, bottom: 4),
            padding: const EdgeInsets.only(left: 8),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
            ),
            child: Column(
              children:
                  widget.item.children
                      .map((sub) => _buildSidebarTile(context, sub))
                      .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
