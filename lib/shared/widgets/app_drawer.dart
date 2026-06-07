import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/admin_credit_movements_screen.dart';
import 'package:inventory_store_app/screens/admin/admin_credits_screen.dart';
import 'package:inventory_store_app/screens/admin/categories_management_screen.dart';
import 'package:inventory_store_app/screens/admin/customers_screen.dart';
import 'package:inventory_store_app/screens/admin/warehouses_management_screen.dart';
import 'package:inventory_store_app/screens/admin/kardex_screen.dart';
import 'package:inventory_store_app/screens/admin/users_management_screen.dart';
import 'package:inventory_store_app/screens/admin/dashboard_screen.dart';
import 'package:inventory_store_app/screens/admin/business_info_screen.dart';
import 'package:inventory_store_app/screens/admin/admin_catalog_screen.dart';
import 'package:inventory_store_app/screens/admin/orders_screen.dart';
import 'package:inventory_store_app/screens/admin/points_settings_screen.dart';
import 'package:inventory_store_app/screens/customer/customer_catalog_screen.dart';
import 'package:inventory_store_app/screens/customer/cart_screen.dart';
import 'package:inventory_store_app/screens/auth/profile_screen.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Modelo de datos para los ítems del drawer
// ---------------------------------------------------------------------------

class _DrawerItem {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
  final List<_DrawerSubItem> children;

  const _DrawerItem({
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
    this.children = const [],
  });
}

class _DrawerSubItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DrawerSubItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });
}

// ---------------------------------------------------------------------------
// Widget principal
// ---------------------------------------------------------------------------

class AppDrawer extends StatefulWidget {
  final bool isAdmin;
  const AppDrawer({super.key, this.isAdmin = false});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Rastreo de qué grupos expandibles están abiertos (por título)
  final Set<String> _expanded = {};

  Future<int> _loadPendingOrdersCount() async {
    final response = await Supabase.instance.client
        .from('orders')
        .select('id')
        .eq('status', 'PENDING');
    return List<Map<String, dynamic>>.from(response).length;
  }

  void _toggle(String title) {
    setState(() {
      if (_expanded.contains(title)) {
        _expanded.remove(title);
      } else {
        _expanded.add(title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─────────────────────────────────────────
          // HEADER
          // ─────────────────────────────────────────
          _DrawerHeader(isAdmin: widget.isAdmin),

          // ─────────────────────────────────────────
          // CUERPO (scrollable)
          // ─────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildSectionTitle('MENÚ PRINCIPAL'),
                _buildItem(
                  context,
                  _DrawerItem(
                    icon: Icons.grid_view_rounded,
                    title: 'Catálogo',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  widget.isAdmin
                                      ? const CatalogoScreen()
                                      : const CustomerCatalogScreen(),
                        ),
                      );
                    },
                  ),
                ),
                _buildItem(
                  context,
                  _DrawerItem(
                    icon: Icons.bar_chart_rounded,
                    title: 'Dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DashboardScreen(),
                        ),
                      );
                    },
                  ),
                ),
                if (!widget.isAdmin)
                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Mi Carrito',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CartScreen()),
                        );
                      },
                    ),
                  ),

                // ── Sección Administración ──────────────────────────────
                if (widget.isAdmin) ...[
                  const _SectionDivider(),
                  _buildSectionTitle('ADMINISTRACIÓN'),

                  // Pedidos (con badge dinámico)
                  FutureBuilder<int>(
                    future: _loadPendingOrdersCount(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return _buildItem(
                        context,
                        _DrawerItem(
                          icon: Icons.receipt_long_rounded,
                          title: 'Pedidos',
                          trailing: count > 0 ? _buildBadge(count) : null,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OrdersScreen(),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.inventory_2_outlined,
                      title: 'Kardex',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KardexScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.people_outline_rounded,
                      title: 'Clientes',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomersScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.credit_score_rounded,
                      title: 'Créditos',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminCreditsScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.category_outlined,
                      title: 'Categorías',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CategoriesManagementScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  // // ── Crédito (con sub-ítems) ─────────────────────────
                  // _buildExpandableItem(
                  //   context,
                  //   _DrawerItem(
                  //     icon: Icons.credit_card_rounded,
                  //     title: 'Crédito',
                  //     children: [
                  //       _DrawerSubItem(
                  //         icon: Icons.credit_score_rounded,
                  //         title: 'Créditos',
                  //         onTap: () {
                  //           Navigator.pop(context);
                  //           Navigator.push(
                  //             context,
                  //             MaterialPageRoute(
                  //               builder: (_) => const AdminCreditsScreen(),
                  //             ),
                  //           );
                  //         },
                  //       ),
                  //       _DrawerSubItem(
                  //         icon: Icons.swap_horiz_rounded,
                  //         title: 'Movimientos de Crédito',
                  //         onTap: () {
                  //           Navigator.pop(context);
                  //           Navigator.push(
                  //             context,
                  //             MaterialPageRoute(
                  //               builder: (_) => const AdminCreditsScreen(),
                  //             ),
                  //           );
                  //         },
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.warehouse_outlined,
                      title: 'Almacenes',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WarehousesManagementScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.people_outline_rounded,
                      title: 'Usuarios',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UsersManagementScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.storefront_rounded,
                      title: 'Negocio',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BusinessInfoScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.stars_rounded,
                      title: 'Monedas',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PointsSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ─────────────────────────────────────────
          // PIE (perfil siempre visible)
          // ─────────────────────────────────────────
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildItem(
              context,
              _DrawerItem(
                icon: Icons.account_circle_outlined,
                title: 'Mi Perfil',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ProfileScreen(openedFromAdmin: widget.isAdmin),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Constructores de ítems
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildItem(BuildContext context, _DrawerItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(item.icon, color: AppColors.textSecondary, size: 22),
        title: Text(
          item.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: item.trailing,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        splashColor: AppColors.primary.withValues(alpha: 0.1),
        hoverColor: AppColors.primaryLight,
        onTap: item.onTap,
        dense: true,
      ),
    );
  }

  Widget _buildExpandableItem(BuildContext context, _DrawerItem item) {
    final isOpen = _expanded.contains(item.title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Cabecera del grupo ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: ListTile(
            leading: Icon(item.icon, color: AppColors.textSecondary, size: 22),
            title: Text(
              item.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: AnimatedRotation(
              turns: isOpen ? 0.5 : 0,
              duration: const Duration(milliseconds: 220),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isOpen ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            splashColor: AppColors.primary.withValues(alpha: 0.1),
            hoverColor: AppColors.primaryLight,
            onTap: () => _toggle(item.title),
            dense: true,
          ),
        ),

        // ── Sub-ítems con animación ─────────────────────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState:
              isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: _SubItemsPanel(items: item.children, isOpen: isOpen),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Utilidades de UI
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textHint,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
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
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 12, bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.35),
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
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 0, top: 2, bottom: 2),
      child: ListTile(
        leading: Icon(item.icon, color: AppColors.primary, size: 20),
        title: Text(
          item.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: item.trailing,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        splashColor: AppColors.primary.withValues(alpha: 0.1),
        hoverColor: AppColors.primaryLight,
        onTap: item.onTap,
        dense: true,
        minLeadingWidth: 20,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        bottom: 24,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Consumer<AppConfigProvider>(
            builder: (context, config, _) {
              final businessName = config.businessName;
              final businessAddress = config.businessAddress;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    businessName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (businessAddress.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      businessAddress,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Chip de rol
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAdmin
                              ? Icons.admin_panel_settings_rounded
                              : Icons.person_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isAdmin ? 'Administrador' : 'Cliente',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(indent: 24, endIndent: 24),
    );
  }
}
