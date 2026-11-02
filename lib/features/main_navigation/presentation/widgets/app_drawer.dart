import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
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

// Re-exportar modelos para mantener compatibilidad con cualquier archivo dependiente
export 'package:inventory_store_app/features/main_navigation/presentation/widgets/drawer/drawer_models.dart';

/// Menú lateral (Drawer) optimizado para dispositivos móviles y tablets.
///
/// Arquitectura de alto rendimiento:
/// - Rebuild trees aislados mediante `BlocSelector` para permisos y configuración.
/// - Cero asignación de AnimationControllers en cascada para fluidez en gama baja.
/// - Decodificación de mapas de bits limitada para un consumo mínimo de RAM/VRAM.
/// - Retención de estado de scroll y colapso de grupos sin mutaciones en fase de build.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Selector granular: solo reconstruir el árbol de navegación si cambian permisos o admin
    return BlocSelector<
      AuthCubit,
      auth_state.AuthState,
      ({bool isAdmin, Set<String> permissions})
    >(
      selector:
          (state) => (
            isAdmin: widget.isAdmin || (state.currentUser?.isAdmin ?? false),
            permissions: state.currentUser?.permissions ?? const <String>{},
          ),
      builder: (context, authData) {
        final isAdmin = authData.isAdmin;
        final perms = authData.permissions;

        bool can(String perm) => isAdmin || perms.contains(perm);
        bool canAny(Iterable<String> checkPerms) =>
            isAdmin || checkPerms.any((p) => perms.contains(p));

        final canViewCatalog = canAny([
          AppPermissions.productsView,
          AppPermissions.inventoryView,
        ]);
        final canViewOrders = canAny([
          AppPermissions.posView,
          AppPermissions.posSale,
        ]);

        final inventoryChildren = <DrawerSubItem>[
          if (can(AppPermissions.productsView))
            DrawerSubItem(
              icon: Icons.category_outlined,
              title: 'Productos',
              routePath: '/products',
              onTap: () {
                Navigator.pop(context);
                context.go('/products');
              },
            ),
          if (can(AppPermissions.inventoryView))
            DrawerSubItem(
              icon: Icons.grid_view_rounded,
              title: 'Stock inventario',
              routePath: '/inventory',
              onTap: () {
                Navigator.pop(context);
                context.go('/inventory');
              },
            ),
          if (can(AppPermissions.inventoryKardex))
            DrawerSubItem(
              icon: Icons.article_outlined,
              title: 'Kardex',
              routePath: '/kardex',
              onTap: () {
                Navigator.pop(context);
                context.go('/kardex');
              },
            ),
          if (can(AppPermissions.inventoryExits))
            DrawerSubItem(
              icon: Icons.remove_rounded,
              title: 'Salidas inventario',
              routePath: '/inventory-exits',
              onTap: () {
                Navigator.pop(context);
                context.go('/inventory-exits');
              },
            ),
        ];

        final purchasesChildren = <DrawerSubItem>[
          if (isAdmin ||
              canAny([
                AppPermissions.purchasesView,
                AppPermissions.purchasesCreate,
                AppPermissions.purchasesReceive,
              ]))
            DrawerSubItem(
              icon: Icons.receipt_long_rounded,
              title: 'Órdenes de compra',
              routePath: '/purchase-orders',
              onTap: () {
                Navigator.pop(context);
                context.go('/purchase-orders');
              },
            ),
          if (isAdmin || can(AppPermissions.inventoryEntries))
            DrawerSubItem(
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
            DrawerSubItem(
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
            DrawerSubItem(
              icon: Icons.local_shipping_outlined,
              title: 'Proveedores',
              routePath: '/suppliers',
              onTap: () {
                Navigator.pop(context);
                context.go('/suppliers');
              },
            ),
        ];

        final customersChildren = <DrawerSubItem>[
          if (isAdmin ||
              canAny([
                AppPermissions.customersView,
                AppPermissions.customersManage,
                AppPermissions.posView,
                AppPermissions.posSale,
              ])) ...[
            DrawerSubItem(
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
              DrawerSubItem(
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

        final mastersChildren = <DrawerSubItem>[
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
              DrawerSubItem(
                icon: Icons.category_outlined,
                title: 'Categorías',
                routePath: '/categories',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/categories');
                },
              ),
            if (isAdmin ||
                canAny([
                  AppPermissions.brandsManage,
                  AppPermissions.productsEdit,
                ]))
              DrawerSubItem(
                icon: Icons.branding_watermark_outlined,
                title: 'Marcas',
                routePath: '/brands',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/brands');
                },
              ),
            DrawerSubItem(
              icon: Icons.local_offer,
              title: 'Atributos',
              routePath: '/attributes',
              onTap: () {
                Navigator.pop(context);
                context.go('/attributes');
              },
            ),
            DrawerSubItem(
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
              // Header con bitmap optimizado
              DrawerHeaderWidget(isAdmin: isAdmin),

              // Cuerpo con Scrollbar nativo y límite de repintado
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
                        if (canViewCatalog)
                          DrawerItemTile(
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

                        // Gestión Comercial
                        if (hasCommercialSection) ...[
                          const _SectionDivider(),
                          _buildSectionTitle(context, 'GESTIÓN COMERCIAL'),
                        ],

                        if (canViewOrders)
                          DrawerItemTile(
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

                        if (inventoryChildren.isNotEmpty)
                          DrawerExpandableGroup(
                            item: DrawerItem(
                              icon: Icons.inventory_2_outlined,
                              title: 'Inventario',
                              routePath: '',
                              children: inventoryChildren,
                            ),
                          ),

                        if (purchasesChildren.isNotEmpty)
                          DrawerExpandableGroup(
                            item: DrawerItem(
                              icon: Icons.shopping_bag_outlined,
                              title: 'Compras',
                              routePath: '',
                              children: purchasesChildren,
                            ),
                          ),

                        if (customersChildren.isNotEmpty)
                          DrawerExpandableGroup(
                            item: DrawerItem(
                              icon: Icons.people_outline_rounded,
                              title: 'Clientes y Créditos',
                              routePath: '',
                              children: customersChildren,
                            ),
                          ),

                        // Configuración ERP
                        BlocSelector<AppConfigCubit, AppConfigState, bool>(
                          selector:
                              (s) =>
                                  s.businessInfo?.loyaltyGlobalEnabled ?? false,
                          builder: (context, loyaltyEnabled) {
                            final systemChildren = <DrawerSubItem>[
                              if (can(AppPermissions.usersView))
                                DrawerSubItem(
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
                                DrawerSubItem(
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
                                DrawerSubItem(
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
                                DrawerSubItem(
                                  icon: Icons.warehouse_outlined,
                                  title: 'Almacenes',
                                  routePath: '/warehouses',
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.go('/warehouses');
                                  },
                                ),
                              if (loyaltyEnabled &&
                                  can(AppPermissions.settingsEdit))
                                DrawerSubItem(
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
                                  _buildSectionTitle(
                                    context,
                                    'CONFIGURACIÓN ERP',
                                  ),
                                ],
                                if (mastersChildren.isNotEmpty)
                                  DrawerExpandableGroup(
                                    item: DrawerItem(
                                      icon: Icons.category_outlined,
                                      title: 'Maestros / Catálogos',
                                      routePath: '',
                                      children: mastersChildren,
                                    ),
                                  ),
                                if (systemChildren.isNotEmpty)
                                  DrawerExpandableGroup(
                                    item: DrawerItem(
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

                        // Sistema & Soporte
                        const _SectionDivider(),
                        _buildSectionTitle(context, 'SISTEMA & SOPORTE'),
                        if (canViewSettings)
                          DrawerItemTile(
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

              // Botón POS de acceso rápido
              const DrawerPosButton(),

              // Pie de página con perfil y acción de logout
              Divider(height: 1, color: AppColors.sideBorder(context)),
              DrawerFooterWidget(isAdmin: isAdmin),
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
