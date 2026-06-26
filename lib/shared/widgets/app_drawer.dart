import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/profile_provider.dart';
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

class AppDrawer extends StatefulWidget {
  final bool isAdmin;
  const AppDrawer({super.key, this.isAdmin = false});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Rastreo de qué grupos expandibles están abiertos (por título)
  final Set<String> _expanded = {};
  int? _pendingCount;

  @override
  void initState() {
    super.initState();
    if (widget.isAdmin) {
      _fetchPendingCount();
    }
  }

  Future<void> _fetchPendingCount() async {
    try {
      final count = await Supabase.instance.client
          .from('orders')
          .count(CountOption.exact)
          .eq('status', 'PENDING');
      if (mounted) {
        setState(() => _pendingCount = count);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pendingCount = 0);
      }
    }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
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
                    routePath: widget.isAdmin ? '/admin' : '/customer',
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.isAdmin) {
                        context.go('/admin');
                      } else {
                        context.go('/customer');
                      }
                    },
                  ),
                ),
                _buildItem(
                  context,
                  _DrawerItem(
                    icon: Icons.bar_chart_rounded,
                    title: 'Dashboard',
                    routePath: '/admin/dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/admin/dashboard');
                    },
                  ),
                ),
                if (!widget.isAdmin)
                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Mi Carrito',
                      routePath: '/customer/cart',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/customer/cart');
                      },
                    ),
                  ),

                // ── Sección Administración ──────────────────────────────
                if (widget.isAdmin) ...[
                  const _SectionDivider(),
                  _buildSectionTitle('ADMINISTRACIÓN'),

                  // Pedidos (con badge dinámico)
                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.receipt_long_rounded,
                      title: 'Pedidos',
                      routePath: '/admin/orders',
                      trailing:
                          _pendingCount == null
                              ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.error,
                                ),
                              )
                              : (_pendingCount! > 0
                                  ? _buildBadge(_pendingCount!)
                                  : null),
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin/orders');
                      },
                    ),
                  ),

                  // // ── Compras (con sub-ítems) ─────────────────────────
                  _buildExpandableItem(
                    context,
                    _DrawerItem(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Compras',
                      routePath: '',
                      children: [
                        _DrawerSubItem(
                          icon: Icons.receipt_long_rounded,
                          title: 'Órdenes de compra',
                          routePath: '/admin/purchase-orders',
                          onTap: () {
                            Navigator.pop(context);
                            context.go('/admin/purchase-orders');
                          },
                        ),
                        _DrawerSubItem(
                          icon: Icons.add_rounded,
                          title: 'Entradas de inventario',
                          routePath: '/admin/inventory-entries',
                          onTap: () {
                            Navigator.pop(context);
                            context.go('/admin/inventory-entries');
                          },
                        ),
                        _DrawerSubItem(
                          icon: Icons.credit_score_rounded,
                          title: 'Créditos de proveedores',
                          routePath: '/admin/supplier-credits',
                          onTap: () {
                            Navigator.pop(context);
                            context.go('/admin/supplier-credits');
                          },
                        ),
                        _DrawerSubItem(
                          icon: Icons.local_shipping_outlined,
                          title: 'Proveedores',
                          routePath: '/admin/suppliers',
                          onTap: () {
                            Navigator.pop(context);
                            context.go('/admin/suppliers');
                          },
                        ),
                      ],
                    ),
                  ),

                  // // ── Inventario (con sub-ítems) ─────────────────────────
                  _buildExpandableItem(
                    context,
                    _DrawerItem(
                      icon: Icons.inventory_2_outlined,
                      title: 'Inventario',
                      routePath: '',
                      children: [
                        _DrawerSubItem(
                          icon: Icons.grid_view_rounded,
                          title: 'Inventario',
                          routePath: '/admin/inventory',
                          onTap: () {
                            Navigator.pop(context);
                            context.go('/admin/inventory');
                          },
                        ),
                        _DrawerSubItem(
                          icon: Icons.article_outlined,
                          title: 'Kardex',
                          routePath: '/admin/kardex',
                          onTap: () {
                            Navigator.pop(context);
                            context.go('/admin/kardex');
                          },
                        ),

                        _DrawerSubItem(
                          icon: Icons.remove_rounded,
                          title: 'Registro Salida',
                          routePath: '/admin/inventory-exits',
                          onTap: () {
                            Navigator.pop(context);
                            context.go('/admin/inventory-exits');
                          },
                        ),
                      ],
                    ),
                  ),

                  _buildExpandableItem(
                    context,
                    _DrawerItem(
                      icon: Icons.people_outline_rounded,
                      title: 'Clientes y Créditos',
                      routePath: '',
                      children: [
                        _DrawerSubItem(
                          icon: Icons.person_outline_rounded,
                          title: 'Clientes',
                          routePath: '/admin/customers',
                          onTap: () {
                            Navigator.pop(context);
                            context.go('/admin/customers');
                          },
                        ),
                        _DrawerSubItem(
                          icon: Icons.credit_score_rounded,
                          title: 'Créditos',
                          routePath: '/admin/customer-credits',
                          onTap: () {
                            Navigator.pop(context);
                            context.go('/admin/customer-credits');
                          },
                        ),
                      ],
                    ),
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Cuentas',
                      routePath: '/admin/financial-accounts',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin/financial-accounts');
                      },
                    ),
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.category_outlined,
                      title: 'Categorías',
                      routePath: '/admin/categories',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin/categories');
                      },
                    ),
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.warehouse_outlined,
                      title: 'Almacenes',
                      routePath: '/admin/warehouses',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin/warehouses');
                      },
                    ),
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.tune_rounded,
                      title: 'Atributos y Valores',
                      routePath: '/admin/attributes',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin/attributes');
                      },
                    ),
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.science_rounded,
                      title: 'Ingredientes Activos/Componentes Químicos',
                      routePath: '/admin/active-ingredients',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin/active-ingredients');
                      },
                    ),
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.people_outline_rounded,
                      title: 'Usuarios',
                      routePath: '/admin/users',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin/users');
                      },
                    ),
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.storefront_rounded,
                      title: 'Negocio',
                      routePath: '/admin/business-info',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin/business-info');
                      },
                    ),
                  ),

                  _buildItem(
                    context,
                    _DrawerItem(
                      icon: Icons.stars_rounded,
                      title: 'Monedas',
                      routePath: '/admin/points-settings',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin/points-settings');
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
          _DrawerFooter(isAdmin: widget.isAdmin),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Constructores de ítems
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildItem(BuildContext context, _DrawerItem item) {
    final currentPath = GoRouterState.of(context).uri.path;
    final active =
        (item.routePath == '/admin' || item.routePath == '/customer')
            ? currentPath == item.routePath
            : currentPath.startsWith(item.routePath);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border:
              active
                  ? const Border(
                    left: BorderSide(color: AppColors.primary, width: 4),
                  )
                  : null,
        ),
        child: ListTile(
          leading: Icon(
            item.icon,
            color:
                active
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.8),
            size: 22,
          ),
          title: Text(
            item.title,
            style: TextStyle(
              color:
                  active
                      ? AppColors.primary
                      : AppColors.textPrimary.withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          tileColor: active ? AppColors.primary.withValues(alpha: 0.1) : null,
          trailing: item.trailing,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(
              right: const Radius.circular(12),
              left:
                  active ? const Radius.circular(8) : const Radius.circular(12),
            ),
          ),
          splashColor: AppColors.primary.withValues(alpha: 0.15),
          hoverColor: AppColors.primaryLight,
          onTap: () {
            if (item.onTap != null) item.onTap!();
          },
          dense: true,
        ),
      ),
    );
  }

  Widget _buildExpandableItem(BuildContext context, _DrawerItem item) {
    // Si algún sub-ítem es la pantalla activa, auto-expandir el grupo
    final currentPath = GoRouterState.of(context).uri.path;
    final hasActiveChild = item.children.any(
      (sub) => currentPath.startsWith(sub.routePath),
    );
    if (hasActiveChild && !_expanded.contains(item.title)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_expanded.contains(item.title)) {
          setState(() => _expanded.add(item.title));
        }
      });
    }
    final isOpen = _expanded.contains(item.title) || hasActiveChild;

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
    final currentPath = GoRouterState.of(context).uri.path;
    final active = currentPath.startsWith(item.routePath);
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 0, top: 2, bottom: 2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border:
              active
                  ? const Border(
                    left: BorderSide(color: AppColors.primary, width: 3),
                  )
                  : null,
        ),
        child: ListTile(
          leading: Icon(
            item.icon,
            color:
                active
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.7),
            size: 20,
          ),
          title: Text(
            item.title,
            style: TextStyle(
              color:
                  active
                      ? AppColors.primary
                      : AppColors.textPrimary.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          tileColor: active ? AppColors.primary.withValues(alpha: 0.1) : null,
          trailing: item.trailing,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(
              right: const Radius.circular(10),
              left:
                  active ? const Radius.circular(6) : const Radius.circular(10),
            ),
          ),
          splashColor: AppColors.primary.withValues(alpha: 0.15),
          hoverColor: AppColors.primaryLight,
          onTap: () {
            item.onTap();
          },
          dense: true,
          minLeadingWidth: 20,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
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
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        bottom: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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

// ---------------------------------------------------------------------------
// Drawer Footer
// ---------------------------------------------------------------------------

class _DrawerFooter extends StatelessWidget {
  final bool isAdmin;
  const _DrawerFooter({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Consumer<ProfileProvider>(
            builder: (context, profile, _) {
              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(context);
                        if (isAdmin) {
                          context.go('/admin/profile');
                        } else {
                          context.go('/customer/profile');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.1,
                              ),
                              backgroundImage:
                                  profile.avatarUrl != null
                                      ? NetworkImage(profile.avatarUrl!)
                                      : null,
                              child:
                                  profile.avatarUrl == null
                                      ? const Icon(
                                        Icons.person_rounded,
                                        color: AppColors.primary,
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
                                    profile.fullName.isEmpty
                                        ? 'Mi Perfil'
                                        : profile.fullName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    isAdmin ? 'Administrador' : 'Cliente',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: AppColors.error,
                                size: 20,
                              ),
                              tooltip: 'Cerrar Sesión',
                              onPressed: () async {
                                Navigator.pop(context);
                                try {
                                  await context
                                      .read<ProfileProvider>()
                                      .signOut();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'v1.0.0',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
