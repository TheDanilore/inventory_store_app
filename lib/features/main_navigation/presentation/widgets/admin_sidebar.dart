import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final Set<String> _expandedGroups = {};
  // ValueNotifier: solo el badge de "Pedidos" se reconstruye cuando cambia el count.
  // No se usa setState global para un dato que afecta un único widget del sidebar.
  final ValueNotifier<int?> _pendingNotifier = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    _fetchPendingOrdersCount();
  }

  @override
  void dispose() {
    _pendingNotifier.dispose();
    super.dispose();
  }

  Future<void> _fetchPendingOrdersCount() async {
    try {
      // select('id') con .count() minimiza el egress: solo transfiere
      // el header HTTP con el count exacto, sin descargar filas.
      final response = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('status', 'PENDING')
          .count(CountOption.exact);
      if (mounted) {
        _pendingNotifier.value = response.count;
      }
    } catch (e, st) {
      debugPrint('🔴 [AdminSidebar] Error al obtener pedidos pendientes: $e\n$st');
      // null = sin dato disponible. El badge no aparece en lugar de
      // mostrar 0 falsamente cuando la query falló.
      if (mounted) _pendingNotifier.value = null;
    }
  }

  void _toggleGroup(String title) {
    setState(() {
      if (_expandedGroups.contains(title)) {
        _expandedGroups.remove(title);
      } else {
        _expandedGroups.add(title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.isCollapsed ? 72.0 : 260.0;
    final currentPath = GoRouterState.of(context).uri.path;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Brand / Header ─────────────────────────────────────────
          _buildBrandHeader(context),
          const Divider(height: 1, color: AppColors.border),

          // ── Items List ─────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                if (!widget.isCollapsed) _buildSectionHeader('MENÚ PRINCIPAL'),
                _buildSidebarTile(
                  context,
                  const AdminSidebarItem(
                    icon: Icons.grid_view_rounded,
                    title: 'Catálogo',
                    routePath: '/admin',
                  ),
                  currentPath,
                ),
                _buildSidebarTile(
                  context,
                  const AdminSidebarItem(
                    icon: Icons.bar_chart_rounded,
                    title: 'Dashboard',
                    routePath: '/admin/dashboard',
                  ),
                  currentPath,
                ),

                if (!widget.isCollapsed) ...[
                  const SizedBox(height: 12),
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.border,
                  ),
                  _buildSectionHeader('GESTIÓN COMERCIAL'),
                ],

                // ValueListenableBuilder: solo este tile se reconstruye
                // cuando cambia _pendingNotifier. El resto del sidebar
                // permanece intacto.
                ValueListenableBuilder<int?>(
                  valueListenable: _pendingNotifier,
                  builder: (ctx, count, _) {
                    return _buildSidebarTile(
                      context,
                      AdminSidebarItem(
                        icon: Icons.receipt_long_rounded,
                        title: 'Pedidos',
                        routePath: '/admin/orders',
                        trailing:
                            count != null && count > 0
                                ? _buildBadge(count)
                                : null,
                      ),
                      currentPath,
                    );
                  },
                ),

                _buildExpandableSidebarGroup(
                  context,
                  const AdminSidebarItem(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Compras',
                    routePath: '',
                    children: [
                      AdminSidebarItem(
                        icon: Icons.receipt_long_rounded,
                        title: 'Órdenes de compra',
                        routePath: '/admin/purchase-orders',
                      ),
                      AdminSidebarItem(
                        icon: Icons.add_rounded,
                        title: 'Entradas inventario',
                        routePath: '/admin/inventory-entries',
                      ),
                      AdminSidebarItem(
                        icon: Icons.credit_score_rounded,
                        title: 'Créditos proveedores',
                        routePath: '/admin/supplier-credits',
                      ),
                      AdminSidebarItem(
                        icon: Icons.local_shipping_outlined,
                        title: 'Proveedores',
                        routePath: '/admin/suppliers',
                      ),
                    ],
                  ),
                  currentPath,
                ),

                _buildExpandableSidebarGroup(
                  context,
                  const AdminSidebarItem(
                    icon: Icons.inventory_2_outlined,
                    title: 'Inventario',
                    routePath: '',
                    children: [
                      AdminSidebarItem(
                        icon: Icons.category_outlined,
                        title: 'Productos',
                        routePath: '/admin/products',
                      ),
                      AdminSidebarItem(
                        icon: Icons.grid_view_rounded,
                        title: 'Stock inventario',
                        routePath: '/admin/inventory',
                      ),
                      AdminSidebarItem(
                        icon: Icons.article_outlined,
                        title: 'Kardex',
                        routePath: '/admin/kardex',
                      ),
                      AdminSidebarItem(
                        icon: Icons.remove_rounded,
                        title: 'Salidas inventario',
                        routePath: '/admin/inventory-exits',
                      ),
                    ],
                  ),
                  currentPath,
                ),

                _buildExpandableSidebarGroup(
                  context,
                  const AdminSidebarItem(
                    icon: Icons.people_outline_rounded,
                    title: 'Clientes y Créditos',
                    routePath: '',
                    children: [
                      AdminSidebarItem(
                        icon: Icons.person_outline_rounded,
                        title: 'Clientes',
                        routePath: '/admin/customers',
                      ),
                      AdminSidebarItem(
                        icon: Icons.credit_score_rounded,
                        title: 'Créditos clientes',
                        routePath: '/admin/customer-credits',
                      ),
                    ],
                  ),
                  currentPath,
                ),

                if (!widget.isCollapsed) ...[
                  const SizedBox(height: 12),
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.border,
                  ),
                  _buildSectionHeader('CONFIGURACIÓN ERP'),
                ],

                _buildSidebarTile(
                  context,
                  const AdminSidebarItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Cuentas',
                    routePath: '/admin/financial-accounts',
                  ),
                  currentPath,
                ),
                _buildSidebarTile(
                  context,
                  const AdminSidebarItem(
                    icon: Icons.category_outlined,
                    title: 'Categorías',
                    routePath: '/admin/categories',
                  ),
                  currentPath,
                ),
                _buildSidebarTile(
                  context,
                  const AdminSidebarItem(
                    icon: Icons.warehouse_outlined,
                    title: 'Almacenes',
                    routePath: '/admin/warehouses',
                  ),
                  currentPath,
                ),
                _buildSidebarTile(
                  context,
                  const AdminSidebarItem(
                    icon: Icons.tune_rounded,
                    title: 'Atributos',
                    routePath: '/admin/attributes',
                  ),
                  currentPath,
                ),
                _buildSidebarTile(
                  context,
                  const AdminSidebarItem(
                    icon: Icons.science_rounded,
                    title: 'Ingredientes Activos',
                    routePath: '/admin/active-ingredients',
                  ),
                  currentPath,
                ),
                _buildSidebarTile(
                  context,
                  const AdminSidebarItem(
                    icon: Icons.people_outline_rounded,
                    title: 'Usuarios',
                    routePath: '/admin/users',
                  ),
                  currentPath,
                ),
                _buildSidebarTile(
                  context,
                  const AdminSidebarItem(
                    icon: Icons.storefront_rounded,
                    title: 'Negocio',
                    routePath: '/admin/business-info',
                  ),
                  currentPath,
                ),
                _buildSidebarTile(
                  context,
                  const AdminSidebarItem(
                    icon: Icons.stars_rounded,
                    title: 'Puntos y Monedas',
                    routePath: '/admin/points-settings',
                  ),
                  currentPath,
                ),
              ],
            ),
          ),

          // ── Collapse / Expand Footer Action ────────────────────────
          const Divider(height: 1, color: AppColors.border),
          InkWell(
            onTap: widget.onToggleCollapse,
            child: Container(
              height: 52,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  Icon(
                    widget.isCollapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    color: AppColors.textSecondary,
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            if (!widget.isCollapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: BlocSelector<AppConfigCubit, AppConfigState, String>(
                selector:
                    (state) =>
                        state.businessInfo?.businessName ?? 'ERP Tienda',
                builder: (context, name) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        'Panel de Control',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
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
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  bool _isItemActive(String routePath, String currentPath) {
    if (routePath.isEmpty) return false;
    if (currentPath == routePath) return true;
    // Regla genérica: captura /form, /:id y cualquier sub-ruta.
    // Las 6 excepciones hardcodeadas anteriores eran redundantes:
    // startsWith('$routePath/') las cubría en todos los casos.
    if (routePath != '/admin' && currentPath.startsWith('$routePath/')) {
      return true;
    }
    return false;
  }

  Widget _buildSidebarTile(
    BuildContext context,
    AdminSidebarItem item,
    String currentPath,
  ) {
    final isActive = _isItemActive(item.routePath, currentPath);

    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color:
            isActive
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(item.routePath),
          hoverColor: AppColors.primaryLight,
          child: Container(
            height: 42,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCollapsed ? 0 : 12,
            ),
            child: ClipRect(
              child: Row(
                mainAxisAlignment:
                    widget.isCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                children: [
                  Icon(
                    item.icon,
                    size: 20,
                    color:
                        isActive ? AppColors.primary : AppColors.textSecondary,
                  ),
                  if (!widget.isCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isActive ? FontWeight.w800 : FontWeight.w500,
                          color:
                              isActive
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
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

  Widget _buildExpandableSidebarGroup(
    BuildContext context,
    AdminSidebarItem item,
    String currentPath,
  ) {
    final hasActiveChild = item.children.any(
      (sub) => _isItemActive(sub.routePath, currentPath),
    );
    final isOpen = _expandedGroups.contains(item.title) || hasActiveChild;

    if (widget.isCollapsed) {
      return PopupMenuButton<String>(
        tooltip: item.title,
        offset: const Offset(60, 0),
        onSelected: (route) => context.go(route),
        itemBuilder:
            (ctx) =>
                item.children
                    .map(
                      (sub) => PopupMenuItem(
                        value: sub.routePath,
                        child: Row(
                          children: [
                            Icon(
                              sub.icon,
                              size: 18,
                              color: AppColors.textSecondary,
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
                  hasActiveChild
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              size: 20,
              color:
                  hasActiveChild ? AppColors.primary : AppColors.textSecondary,
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
              onTap: () => _toggleGroup(item.title),
              hoverColor: AppColors.primaryLight,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color:
                          hasActiveChild
                              ? AppColors.primary
                              : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              hasActiveChild
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                          color:
                              hasActiveChild
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
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
                left: BorderSide(color: AppColors.border, width: 2),
              ),
            ),
            child: Column(
              children:
                  item.children
                      .map(
                        (sub) => _buildSidebarTile(context, sub, currentPath),
                      )
                      .toList(),
            ),
          ),
        ),
      ],
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
