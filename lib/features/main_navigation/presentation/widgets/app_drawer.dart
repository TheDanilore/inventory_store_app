import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart'
    as auth_state;
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_badge_widget.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_expandable_group.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_footer.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_header.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_item_tile.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_models.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_pos_button.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_menu_builder.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_sidebar_models.dart';

// Re-exportar modelos para mantener compatibilidad con cualquier archivo dependiente.
export 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_models.dart';

/// Menú lateral (Drawer) optimizado para dispositivos móviles y tablets.
///
/// Consume [AdminMenuBuilder] como fuente única de verdad RBAC sin escalar
/// privilegios visuales para colaboradores no-admin, resuelve `currentPath`
/// una sola vez y evita animaciones/subárboles ocultos en RAM.
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

  List<DrawerSubItem> _toDrawerSubItems(
    BuildContext context,
    List<AdminSidebarItem> items,
  ) {
    return [
      for (final item in items)
        DrawerSubItem(
          icon: item.icon,
          title: item.title,
          routePath: item.routePath,
          onTap: () {
            Navigator.pop(context);
            context.go(item.routePath);
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPath =
        GoRouter.maybeOf(
          context,
        )?.routerDelegate.currentConfiguration.uri.path ??
        '';

    return BlocSelector<
      AuthCubit,
      auth_state.AuthState,
      ({bool isAdmin, Set<String> permissions})
    >(
      selector: (state) {
        final user = state.currentUser;
        return (
          isAdmin: user != null ? user.isAdmin : widget.isAdmin,
          permissions: user?.permissions ?? const <String>{},
        );
      },
      builder: (context, authData) {
        final loyaltyEnabled = context.select<AppConfigCubit, bool>(
          (c) => c.state.businessInfo?.loyaltyGlobalEnabled ?? false,
        );

        final menu = AdminMenuBuilder.buildMenu(
          isAdmin: authData.isAdmin,
          permissions: authData.permissions,
          loyaltyEnabled: loyaltyEnabled,
        );

        final inventorySubItems = _toDrawerSubItems(
          context,
          menu.inventoryChildren,
        );
        final purchasesSubItems = _toDrawerSubItems(
          context,
          menu.purchasesChildren,
        );
        final customersSubItems = _toDrawerSubItems(
          context,
          menu.customersChildren,
        );
        final mastersSubItems = _toDrawerSubItems(
          context,
          menu.mastersChildren,
        );
        final systemSubItems = _toDrawerSubItems(context, menu.systemChildren);

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
              DrawerHeaderWidget(isAdmin: authData.isAdmin),
              Expanded(
                child: RepaintBoundary(
                  child: RawScrollbar(
                    controller: _scrollController,
                    thumbColor:
                        isDark
                            ? AppColors.darkSidebarText.withValues(alpha: 0.3)
                            : AppColors.sidebarText.withValues(alpha: 0.22),
                    radius: const Radius.circular(4),
                    thickness: 4,
                    padding: const EdgeInsets.only(right: 2),
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: [
                        _buildSectionTitle(context, 'MENÚ PRINCIPAL'),
                        DrawerItemTile(
                          currentPath: currentPath,
                          item: DrawerItem(
                            icon: Icons.bar_chart_rounded,
                            title: 'Dashboard',
                            routePath: '/',
                            onTap: () {
                              Navigator.pop(context);
                              context.go('/');
                            },
                          ),
                        ),
                        if (menu.canViewCatalog)
                          DrawerItemTile(
                            currentPath: currentPath,
                            item: DrawerItem(
                              icon: Icons.grid_view_rounded,
                              title: 'Catálogo',
                              routePath: '/catalog',
                              onTap: () {
                                Navigator.pop(context);
                                context.go('/catalog');
                              },
                            ),
                          ),
                        if (menu.hasCommercialSection) ...[
                          const _SectionDivider(),
                          _buildSectionTitle(context, 'GESTIÓN COMERCIAL'),
                        ],
                        if (menu.canViewOrders)
                          DrawerItemTile(
                            currentPath: currentPath,
                            item: DrawerItem(
                              icon: Icons.receipt_long_rounded,
                              title: 'Pedidos',
                              routePath: '/orders',
                              trailing: const DrawerBadgeWidget(),
                              onTap: () {
                                Navigator.pop(context);
                                context.go('/orders');
                              },
                            ),
                          ),
                        if (inventorySubItems.isNotEmpty)
                          DrawerExpandableGroup(
                            currentPath: currentPath,
                            item: DrawerItem(
                              icon: Icons.inventory_2_outlined,
                              title: 'Inventario',
                              routePath: '',
                              children: inventorySubItems,
                            ),
                          ),
                        if (purchasesSubItems.isNotEmpty)
                          DrawerExpandableGroup(
                            currentPath: currentPath,
                            item: DrawerItem(
                              icon: Icons.shopping_bag_outlined,
                              title: 'Compras',
                              routePath: '',
                              children: purchasesSubItems,
                            ),
                          ),
                        if (customersSubItems.isNotEmpty)
                          DrawerExpandableGroup(
                            currentPath: currentPath,
                            item: DrawerItem(
                              icon: Icons.people_outline_rounded,
                              title: 'Clientes y Créditos',
                              routePath: '',
                              children: customersSubItems,
                            ),
                          ),
                        if (menu.hasErpSection) ...[
                          const _SectionDivider(),
                          _buildSectionTitle(context, 'CONFIGURACIÓN ERP'),
                        ],
                        if (mastersSubItems.isNotEmpty)
                          DrawerExpandableGroup(
                            currentPath: currentPath,
                            item: DrawerItem(
                              icon: Icons.category_outlined,
                              title: 'Maestros / Catálogos',
                              routePath: '',
                              children: mastersSubItems,
                            ),
                          ),
                        if (systemSubItems.isNotEmpty)
                          DrawerExpandableGroup(
                            currentPath: currentPath,
                            item: DrawerItem(
                              icon: Icons.settings_outlined,
                              title: 'Configuración del Sistema',
                              routePath: '',
                              children: systemSubItems,
                            ),
                          ),
                        const _SectionDivider(),
                        _buildSectionTitle(context, 'SISTEMA & SOPORTE'),
                        if (menu.canViewSettings)
                          DrawerItemTile(
                            currentPath: currentPath,
                            item: DrawerItem(
                              icon: Icons.settings_outlined,
                              title: 'Configuraciones',
                              routePath: '/settings',
                              onTap: () {
                                Navigator.pop(context);
                                context.go('/settings');
                              },
                            ),
                          ),
                        DrawerItemTile(
                          currentPath: currentPath,
                          item: DrawerItem(
                            icon: Icons.help_outline_rounded,
                            title: 'Ayuda y Soporte',
                            routePath: '/help',
                            onTap: () {
                              Navigator.pop(context);
                              context.go('/help');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const DrawerPosButton(),
              Divider(height: 1, color: AppColors.sideBorder(context)),
              DrawerFooterWidget(isAdmin: authData.isAdmin),
            ],
          ),
        );
      },
    );
  }

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
}

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
