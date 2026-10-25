import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart'
    as auth_state;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_state.dart';

// ---------------------------------------------------------------------------
// Modelo de datos para los ítems del drawer
// ---------------------------------------------------------------------------

class _DrawerItem {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
  final List<_DrawerSubItem> children;
  final String routePath;

  const _DrawerItem({
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
    this.children = const [],
    required this.routePath,
  });
}

class _DrawerSubItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final String routePath;

  const _DrawerSubItem({
    required this.icon,
    required this.title,
    required this.onTap,
    // ignore: unused_element_parameter
    this.trailing,
    required this.routePath,
  });
}

// ---------------------------------------------------------------------------
// Widget principal
// ---------------------------------------------------------------------------

/// Memoria de sesión estática para retener la posición de scroll
/// y los grupos expandidos del Drawer móvil a través de navegaciones.
class DrawerNavigationMemory {
  static double scrollOffset = 0.0;
  static final Set<String> expandedGroups = {};
}

class AppDrawer extends StatefulWidget {
  final bool isAdmin;
  const AppDrawer({super.key, this.isAdmin = false});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: DrawerNavigationMemory.scrollOffset,
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      DrawerNavigationMemory.scrollOffset = _scrollController.offset;
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
    final authState = context.watch<AuthCubit>().state;
    final currentUser = authState.currentUser;
    final isAdmin = widget.isAdmin || (currentUser?.isAdmin ?? false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    final inventoryChildren = <_DrawerSubItem>[
      if (can(AppPermissions.productsView))
        _DrawerSubItem(
          icon: Icons.category_outlined,
          title: 'Productos',
          routePath: '/products',
          onTap: () {
            Navigator.pop(context);
            context.go('/products');
          },
        ),
      if (can(AppPermissions.inventoryView))
        _DrawerSubItem(
          icon: Icons.grid_view_rounded,
          title: 'Stock inventario',
          routePath: '/inventory',
          onTap: () {
            Navigator.pop(context);
            context.go('/inventory');
          },
        ),
      if (can(AppPermissions.inventoryKardex))
        _DrawerSubItem(
          icon: Icons.article_outlined,
          title: 'Kardex',
          routePath: '/kardex',
          onTap: () {
            Navigator.pop(context);
            context.go('/kardex');
          },
        ),
      if (can(AppPermissions.inventoryExits))
        _DrawerSubItem(
          icon: Icons.remove_rounded,
          title: 'Salidas inventario',
          routePath: '/inventory-exits',
          onTap: () {
            Navigator.pop(context);
            context.go('/inventory-exits');
          },
        ),
    ];

    final purchasesChildren = <_DrawerSubItem>[
      if (isAdmin ||
          canAny([
            AppPermissions.purchasesView,
            AppPermissions.purchasesCreate,
            AppPermissions.purchasesReceive,
          ]))
        _DrawerSubItem(
          icon: Icons.receipt_long_rounded,
          title: 'Órdenes de compra',
          routePath: '/purchase-orders',
          onTap: () {
            Navigator.pop(context);
            context.go('/purchase-orders');
          },
        ),
      if (isAdmin || can(AppPermissions.inventoryEntries))
        _DrawerSubItem(
          icon: Icons.add_rounded,
          title: 'Entradas inventario',
          routePath: '/inventory-entries',
          onTap: () {
            Navigator.pop(context);
            context.go('/inventory-entries');
          },
        ),
      if (isAdmin ||
          canAny([
            AppPermissions.purchasesView,
            AppPermissions.reportsFinancial,
          ]))
        _DrawerSubItem(
          icon: Icons.credit_score_rounded,
          title: 'Créditos proveedores',
          routePath: '/supplier-credits',
          onTap: () {
            Navigator.pop(context);
            context.go('/supplier-credits');
          },
        ),
      if (isAdmin ||
          canAny([
            AppPermissions.suppliersView,
            AppPermissions.suppliersManage,
          ]))
        _DrawerSubItem(
          icon: Icons.local_shipping_outlined,
          title: 'Proveedores',
          routePath: '/suppliers',
          onTap: () {
            Navigator.pop(context);
            context.go('/suppliers');
          },
        ),
    ];

    final customersChildren = <_DrawerSubItem>[
      if (isAdmin ||
          canAny([
            AppPermissions.customersView,
            AppPermissions.customersManage,
            AppPermissions.posView,
            AppPermissions.posSale,
          ])) ...[
        _DrawerSubItem(
          icon: Icons.person_outline_rounded,
          title: 'Clientes',
          routePath: '/customers',
          onTap: () {
            Navigator.pop(context);
            context.go('/customers');
          },
        ),
        if (isAdmin ||
            canAny([
              AppPermissions.creditsManage,
              AppPermissions.reportsFinancial,
            ]))
          _DrawerSubItem(
            icon: Icons.credit_score_rounded,
            title: 'Créditos clientes',
            routePath: '/customer-credits',
            onTap: () {
              Navigator.pop(context);
              context.go('/customer-credits');
            },
          ),
      ],
    ];

    final mastersChildren = <_DrawerSubItem>[
      if (isAdmin ||
          canAny([
            AppPermissions.productsCreate,
            AppPermissions.productsEdit,
            AppPermissions.categoriesManage,
            AppPermissions.brandsManage,
          ])) ...[
        if (isAdmin ||
            canAny([
              AppPermissions.categoriesManage,
              AppPermissions.productsEdit,
            ]))
          _DrawerSubItem(
            icon: Icons.category_outlined,
            title: 'Categorías',
            routePath: '/categories',
            onTap: () {
              Navigator.pop(context);
              context.go('/categories');
            },
          ),
        if (isAdmin ||
            canAny([AppPermissions.brandsManage, AppPermissions.productsEdit]))
          _DrawerSubItem(
            icon: Icons.branding_watermark_outlined,
            title: 'Marcas',
            routePath: '/brands',
            onTap: () {
              Navigator.pop(context);
              context.go('/brands');
            },
          ),
        _DrawerSubItem(
          icon: Icons.local_offer,
          title: 'Atributos',
          routePath: '/attributes',
          onTap: () {
            Navigator.pop(context);
            context.go('/attributes');
          },
        ),
        _DrawerSubItem(
          icon: Icons.science_outlined,
          title: 'Ingredientes activos',
          routePath: '/active-ingredients',
          onTap: () {
            Navigator.pop(context);
            context.go('/active-ingredients');
          },
        ),
      ],
    ];

    final hasCommercialSection =
        canViewOrders ||
        inventoryChildren.isNotEmpty ||
        purchasesChildren.isNotEmpty ||
        customersChildren.isNotEmpty;

    final canViewSettings = can(AppPermissions.settingsView);

    return Drawer(
      backgroundColor: AppColors.sideBg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─────────────────────────────────────────
          // HEADER
          // ─────────────────────────────────────────
          _DrawerHeader(isAdmin: widget.isAdmin),

          // ─────────────────────────────────────────
          // CUERPO (scrollable persistente)
          // ─────────────────────────────────────────
          Expanded(
            child: RawScrollbar(
              controller: _scrollController,
              thumbColor: isDark
                  ? AppColors.darkSidebarText.withValues(alpha: 0.3)
                  : AppColors.sidebarText.withValues(alpha: 0.22),
              radius: const Radius.circular(4),
              thickness: 4,
              padding: const EdgeInsets.only(right: 2),
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: _staggerDrawerChildren([
                  _buildSectionTitle(context, 'MENÚ PRINCIPAL'),
                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.bar_chart_rounded,
                      title: 'Dashboard',
                      routePath: '/',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/');
                      },
                    ),
                  ),
                  if (canViewCatalog)
                    _buildItem(
                      context,
                      _DrawerItem(
                        icon: Icons.grid_view_rounded,
                        title: 'Catálogo',
                        routePath: '/catalog',
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/catalog');
                        },
                      ),
                    ),

                  // ── GESTIÓN COMERCIAL ──────────────────────────────
                  if (hasCommercialSection) ...[
                    const _SectionDivider(),
                    _buildSectionTitle(context, 'GESTIÓN COMERCIAL'),
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
                        return _buildItem(
                          context,
                          _DrawerItem(
                            icon: Icons.receipt_long_rounded,
                            title: 'Pedidos',
                            routePath: '/orders',
                            trailing: badge,
                            onTap: () {
                              Navigator.pop(context);
                              context.go('/orders');
                            },
                          ),
                        );
                      },
                    ),

                  if (inventoryChildren.isNotEmpty)
                    _ExpandableDrawerGroup(
                      _DrawerItem(
                        icon: Icons.inventory_2_outlined,
                        title: 'Inventario',
                        routePath: '',
                        children: inventoryChildren,
                      ),
                    ),

                  if (purchasesChildren.isNotEmpty)
                    _ExpandableDrawerGroup(
                      _DrawerItem(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Compras',
                        routePath: '',
                        children: purchasesChildren,
                      ),
                    ),

                  if (customersChildren.isNotEmpty)
                    _ExpandableDrawerGroup(
                      _DrawerItem(
                        icon: Icons.people_outline_rounded,
                        title: 'Clientes y Créditos',
                        routePath: '',
                        children: customersChildren,
                      ),
                    ),

                  BlocSelector<AppConfigCubit, AppConfigState, bool>(
                    selector:
                        (s) => s.businessInfo?.loyaltyGlobalEnabled ?? false,
                    builder: (context, loyaltyEnabled) {
                      final systemChildren = <_DrawerSubItem>[
                        if (can(AppPermissions.usersView))
                          _DrawerSubItem(
                            icon: Icons.account_circle_outlined,
                            title: 'Usuarios',
                            routePath: '/users',
                            onTap: () {
                              Navigator.pop(context);
                              context.go('/users');
                            },
                          ),
                        if (canAny([
                          AppPermissions.rolesManage,
                          AppPermissions.permissionsAssign,
                        ]))
                          _DrawerSubItem(
                            icon: Icons.shield_outlined,
                            title: 'Roles y Permisos',
                            routePath: '/roles',
                            onTap: () {
                              Navigator.pop(context);
                              context.go('/roles');
                            },
                          ),
                        if (isAdmin ||
                            canAny([
                              AppPermissions.financialAccountsManage,
                              AppPermissions.reportsFinancial,
                              AppPermissions.settingsView,
                            ]))
                          _DrawerSubItem(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Cuentas',
                            routePath: '/financial-accounts',
                            onTap: () {
                              Navigator.pop(context);
                              context.go('/financial-accounts');
                            },
                          ),
                        if (isAdmin ||
                            canAny([
                              AppPermissions.warehousesManage,
                              AppPermissions.inventoryTransfer,
                              AppPermissions.settingsView,
                            ]))
                          _DrawerSubItem(
                            icon: Icons.warehouse_outlined,
                            title: 'Almacenes',
                            routePath: '/warehouses',
                            onTap: () {
                              Navigator.pop(context);
                              context.go('/warehouses');
                            },
                          ),
                        if (loyaltyEnabled && can(AppPermissions.settingsEdit))
                          _DrawerSubItem(
                            icon: Icons.stars_rounded,
                            title: 'Puntos y Monedas',
                            routePath: '/points-settings',
                            onTap: () {
                              Navigator.pop(context);
                              context.go('/points-settings');
                            },
                          ),
                      ];

                      final hasErpSection =
                          mastersChildren.isNotEmpty ||
                          systemChildren.isNotEmpty;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hasErpSection) ...[
                            const _SectionDivider(),
                            _buildSectionTitle(context, 'CONFIGURACIÓN ERP'),
                          ],
                          if (mastersChildren.isNotEmpty)
                            _ExpandableDrawerGroup(
                              _DrawerItem(
                                icon: Icons.category_outlined,
                                title: 'Maestros / Catálogos',
                                routePath: '',
                                children: mastersChildren,
                              ),
                            ),
                          if (systemChildren.isNotEmpty)
                            _ExpandableDrawerGroup(
                              _DrawerItem(
                                icon: Icons.settings_outlined,
                                title: 'Configuración del Sistema',
                                routePath: '',
                                children: systemChildren,
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  // ── SISTEMA & SOPORTE ──────────────────────────────
                  const _SectionDivider(),
                  _buildSectionTitle(context, 'SISTEMA & SOPORTE'),
                  if (canViewSettings)
                    _buildItem(
                      context,
                      _DrawerItem(
                        icon: Icons.settings_outlined,
                        title: 'Configuraciones',
                        routePath: '/settings',
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/settings');
                        },
                      ),
                    ),
                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Ayuda y Soporte',
                      routePath: '/help',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/help');
                      },
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ─────────────────────────────────────────
          // PIE (perfil siempre visible)
          // ─────────────────────────────────────────
          Divider(height: 1, color: AppColors.sideBorder(context)),
          _DrawerFooter(isAdmin: isAdmin),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Entrada en cascada
  // ─────────────────────────────────────────────────────────────────────────

  /// Envuelve cada item visible del cuerpo del drawer para que entre con un
  /// fade + slide-up escalonado al abrirse (efecto cascada). Como cada
  /// widget conserva su posición/identidad en builds posteriores, el efecto
  /// solo se dispara cuando el Drawer se monta por primera vez, no en cada
  /// rebuild por cambios de estado (bloc, tema, etc).
  List<Widget> _staggerDrawerChildren(List<Widget> children) {
    const step = Duration(milliseconds: 22);
    return [
      for (var i = 0; i < children.length; i++)
        children[i]
            .animate()
            .fadeIn(duration: 220.ms, delay: step * i)
            .slideY(
              begin: 0.14,
              end: 0,
              duration: 260.ms,
              delay: step * i,
              curve: Curves.easeOutCubic,
            ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Constructores de ítems
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildItem(BuildContext context, _DrawerItem item) {
    final currentPath = GoRouterState.of(context).uri.path;
    final active = _isItemActive(item.routePath, currentPath);
    final isDark = AppColors.isDark(context);

    final itemBg = active ? AppColors.sideActiveBg(context) : Colors.transparent;
    final itemBorder =
        active ? AppColors.sideActiveBorder(context) : Colors.transparent;
    final itemIndicator = AppColors.sideActiveIndicator(context);
    final iconColor = active
        ? (isDark ? const Color(0xFF60A5FA) : itemIndicator)
        : AppColors.sideText(context);
    final textColor = active
        ? AppColors.sideTextActive(context)
        : AppColors.txtPrimary(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: itemBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: item.onTap,
          splashColor: itemIndicator.withValues(alpha: 0.12),
          hoverColor: AppColors.sideHover(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: itemBorder, width: 1),
            ),
            child: Row(
              children: [
                if (active)
                  Container(
                    width: 3.5,
                    height: 18,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: itemIndicator,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: itemIndicator.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                Icon(
                  item.icon,
                  color: iconColor,
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      letterSpacing: -0.2,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (item.trailing != null) item.trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isItemActive(String routePath, String currentPath) {
    if (routePath.isEmpty) return false;
    if (currentPath == routePath) return true;
    if (routePath == '/' &&
        (currentPath == '/dashboard' || currentPath == '/')) {
      return true;
    }
    if (routePath == '/catalog' &&
        (currentPath == '/catalog' || currentPath.startsWith('/catalog/'))) {
      return true;
    }
    if (routePath != '/' && currentPath.startsWith('$routePath/')) {
      return true;
    }
    return false;
  }
}

class _ExpandableDrawerGroup extends StatefulWidget {
  final _DrawerItem item;

  const _ExpandableDrawerGroup(this.item);

  @override
  State<_ExpandableDrawerGroup> createState() => _ExpandableDrawerGroupState();
}

class _ExpandableDrawerGroupState extends State<_ExpandableDrawerGroup> {
  bool _isItemActive(String routePath, String currentPath) {
    if (routePath.isEmpty) return false;
    if (currentPath == routePath) return true;
    if (routePath != '/' && currentPath.startsWith('$routePath/')) {
      return true;
    }
    return false;
  }

  void _toggle() {
    setState(() {
      if (DrawerNavigationMemory.expandedGroups.contains(widget.item.title)) {
        DrawerNavigationMemory.expandedGroups.remove(widget.item.title);
      } else {
        DrawerNavigationMemory.expandedGroups.add(widget.item.title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item.children.isEmpty) {
      return const SizedBox.shrink();
    }
    final currentPath = GoRouterState.of(context).uri.path;
    final hasActiveChild = widget.item.children.any(
      (sub) => _isItemActive(sub.routePath, currentPath),
    );
    if (hasActiveChild) {
      DrawerNavigationMemory.expandedGroups.add(widget.item.title);
    }
    final isOpen = DrawerNavigationMemory.expandedGroups.contains(
      widget.item.title,
    );
    final isDark = AppColors.isDark(context);

    final headerTextColor = hasActiveChild
        ? AppColors.sideTextActive(context)
        : AppColors.txtPrimary(context);
    final iconColor = hasActiveChild
        ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
        : AppColors.sideText(context);
    final chevronColor = isOpen
        ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
        : AppColors.sideText(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Cabecera del grupo ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _toggle,
              splashColor: AppColors.sideActiveIndicator(context).withValues(alpha: 0.1),
              hoverColor: AppColors.sideHover(context),
              child: Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.item.icon,
                      color: iconColor,
                      size: 21,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.item.title,
                        style: TextStyle(
                          color: headerTextColor,
                          fontSize: 14,
                          letterSpacing: -0.2,
                          fontWeight:
                              hasActiveChild
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: chevronColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Sub-ítems con animación ─────────────────────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState:
              isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: _SubItemsPanel(
            items: widget.item.children,
            isOpen: isOpen,
          ),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Utilidades de UI
// ─────────────────────────────────────────────────────────────────────────

Widget _buildSectionTitle(BuildContext context, String title) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.sideSectionHeader(context),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    ),
  );
}

Widget _buildBadge(int count) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.error,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Sub-panel de ítems expandidos
// ---------------------------------------------------------------------------

class _SubItemsPanel extends StatelessWidget {
  final List<_DrawerSubItem> items;
  final bool isOpen;

  const _SubItemsPanel({required this.items, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final lineBorderColor = isDark
        ? const Color(0xFF3B82F6).withValues(alpha: 0.45)
        : const Color(0xFF2563EB).withValues(alpha: 0.35);

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 12, bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: lineBorderColor,
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items.map((sub) => _SubItemTile(item: sub)).toList(),
      ),
    );
  }
}

class _SubItemTile extends StatelessWidget {
  final _DrawerSubItem item;
  const _SubItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final active =
        currentPath == item.routePath ||
        currentPath.startsWith('${item.routePath}/');
    final isDark = AppColors.isDark(context);

    final tileBg = active
        ? AppColors.sideActiveBg(context)
        : Colors.transparent;
    final tileBorder = active
        ? AppColors.sideActiveBorder(context)
        : Colors.transparent;
    final indicatorColor = AppColors.sideActiveIndicator(context);
    final iconColor = active
        ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
        : (isDark ? AppColors.darkSidebarText : const Color(0xFF64748B));
    final textColor = active
        ? AppColors.sideTextActive(context)
        : AppColors.txtPrimary(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: tileBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: item.onTap,
          splashColor: indicatorColor.withValues(alpha: 0.12),
          hoverColor: AppColors.sideHover(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tileBorder, width: 1),
            ),
            child: Row(
              children: [
                if (active)
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Icon(
                  item.icon,
                  color: iconColor,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13.5,
                      letterSpacing: -0.2,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (item.trailing != null) item.trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header del drawer
// ---------------------------------------------------------------------------

class _DrawerHeader extends StatelessWidget {
  final bool isAdmin;
  const _DrawerHeader({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final headerBg = AppColors.sideBg(context);
    final borderColor = AppColors.sideBorder(context);
    final logoBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
    final logoBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE);
    final titleColor = AppColors.txtPrimary(context);
    final subtitleColor = AppColors.txtSecondary(context);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: logoBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: logoBorder, width: 1),
                ),
                child: Image.asset('assets/logo_icon.png', fit: BoxFit.contain),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isDark
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : const Color(0xFFDBEAFE),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAdmin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.person_rounded,
                      color:
                          isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB),
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isAdmin ? 'Administrador' : 'Cliente',
                      style: TextStyle(
                        color:
                            isDark
                                ? const Color(0xFF93C5FD)
                                : const Color(0xFF1E40AF),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          BlocSelector<
            AppConfigCubit,
            AppConfigState,
            ({String businessName, String businessAddress})
          >(
            selector:
                (state) => (
                  businessName:
                      state.businessInfo?.businessName ?? 'DANILORE ONE',
                  businessAddress: state.businessInfo?.address ?? '',
                ),
            builder: (context, data) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.businessName,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (data.businessAddress.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      data.businessAddress,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Divider de sección
// ---------------------------------------------------------------------------

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        indent: 24,
        endIndent: 24,
        color: AppColors.sideBorder(context),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drawer Footer
// ---------------------------------------------------------------------------

class _DrawerFooter extends StatelessWidget {
  final bool isAdmin;
  const _DrawerFooter({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final footerBg = AppColors.sideBg(context);
    final borderColor = AppColors.sideBorder(context);
    final textPrimary = AppColors.txtPrimary(context);
    final textSecondary = AppColors.txtSecondary(context);

    return Container(
      decoration: BoxDecoration(
        color: footerBg,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: BlocSelector<
            AuthCubit,
            auth_state.AuthState,
            ({String? avatarUrl, String fullName, String? roleName})
          >(
            selector:
                (state) => (
                  avatarUrl: state.currentUser?.avatarUrl,
                  fullName: state.currentUser?.fullName ?? '',
                  roleName: state.currentUser?.role,
                ),
            builder: (context, data) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/profile');
                  },
                  hoverColor: AppColors.sideHover(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              isDark
                                  ? const Color(0xFF1E293B)
                                  : AppColors.primary.withValues(alpha: 0.1),
                          backgroundImage:
                              data.avatarUrl != null &&
                                      data.avatarUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                    data.avatarUrl!,
                                    maxWidth: 72,
                                    maxHeight: 72,
                                  )
                                  : null,
                          child:
                              data.avatarUrl == null
                                  ? Icon(
                                    Icons.person_rounded,
                                    color:
                                        isDark
                                            ? const Color(0xFF60A5FA)
                                            : AppColors.primary,
                                    size: 20,
                                  )
                                  : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.fullName.isEmpty
                                    ? 'Mi Perfil'
                                    : data.fullName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                data.roleName ??
                                    (isAdmin ? 'Administrador' : 'Colaborador'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.logout_rounded,
                            color:
                                isDark
                                    ? const Color(0xFFF87171)
                                    : AppColors.error,
                            size: 20,
                          ),
                          tooltip: 'Cerrar Sesión',
                          onPressed: () async {
                            final authCubit = context.read<AuthCubit>();
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);

                            try {
                              await authCubit.logout();
                              if (navigator.mounted) {
                                navigator.pop();
                              }
                            } catch (e, st) {
                              LoggerService.e(
                                'Error al cerrar sesión',
                                error: e,
                                stackTrace: st,
                                tag: 'AppDrawer',
                              );
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se pudo cerrar sesión. Inténtalo de nuevo.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
