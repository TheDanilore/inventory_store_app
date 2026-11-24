import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_sidebar_models.dart';

class AdminMenuSection {
  final String title;
  final List<AdminSidebarItem> items;

  const AdminMenuSection({required this.title, required this.items});
}

/// Estructura inmutable del menú administrativo resuelto por permisos RBAC.
/// Fuente única de verdad compartida por [AdminSidebar] y [AppDrawer].
class AdminNavigationMenu {
  final bool canViewCatalog;
  final bool canViewOrders;
  final bool canViewSettings;
  final List<AdminSidebarItem> inventoryChildren;
  final List<AdminSidebarItem> purchasesChildren;
  final List<AdminSidebarItem> customersChildren;
  final List<AdminSidebarItem> mastersChildren;
  final List<AdminSidebarItem> systemChildren;

  const AdminNavigationMenu({
    required this.canViewCatalog,
    required this.canViewOrders,
    required this.canViewSettings,
    required this.inventoryChildren,
    required this.purchasesChildren,
    required this.customersChildren,
    required this.mastersChildren,
    required this.systemChildren,
  });

  bool get hasCommercialSection =>
      canViewOrders ||
      inventoryChildren.isNotEmpty ||
      purchasesChildren.isNotEmpty ||
      customersChildren.isNotEmpty;

  bool get hasErpSection =>
      mastersChildren.isNotEmpty || systemChildren.isNotEmpty;
}

class AdminMenuBuilder {
  /// Determina si [routePath] corresponde a la ruta activa actual [currentPath].
  static bool isRouteActive(String routePath, String currentPath) {
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

  /// Construye el árbol completo de navegación para [AdminSidebar] y [AppDrawer].
  static AdminNavigationMenu buildMenu({
    required bool isAdmin,
    required Set<String> permissions,
    required bool loyaltyEnabled,
  }) {
    bool can(String perm) => isAdmin || permissions.contains(perm);
    bool canAny(Iterable<String> checkPerms) =>
        isAdmin || checkPerms.any(permissions.contains);

    return AdminNavigationMenu(
      canViewCatalog: canAny([
        AppPermissions.productsView,
        AppPermissions.inventoryView,
      ]),
      canViewOrders: canAny([AppPermissions.posView, AppPermissions.posSale]),
      canViewSettings: can(AppPermissions.settingsView),
      inventoryChildren: buildInventoryChildren(can),
      purchasesChildren: buildPurchasesChildren(
        isAdmin: isAdmin,
        can: can,
        canAny: canAny,
      ),
      customersChildren: buildCustomersChildren(
        isAdmin: isAdmin,
        canAny: canAny,
      ),
      mastersChildren: buildMastersChildren(isAdmin: isAdmin, canAny: canAny),
      systemChildren: buildSystemChildren(
        isAdmin: isAdmin,
        can: can,
        canAny: canAny,
        loyaltyEnabled: loyaltyEnabled,
      ),
    );
  }

  static List<AdminSidebarItem> buildInventoryChildren(
    bool Function(String) can,
  ) {
    return [
      if (can(AppPermissions.productsView))
        const AdminSidebarItem(
          icon: Icons.category_outlined,
          title: 'Productos',
          routePath: '/products',
        ),
      if (can(AppPermissions.inventoryView))
        const AdminSidebarItem(
          icon: Icons.grid_view_rounded,
          title: 'Stock inventario',
          routePath: '/inventory',
        ),
      if (can(AppPermissions.inventoryKardex))
        const AdminSidebarItem(
          icon: Icons.article_outlined,
          title: 'Kardex',
          routePath: '/kardex',
        ),
      if (can(AppPermissions.inventoryExits))
        const AdminSidebarItem(
          icon: Icons.remove_rounded,
          title: 'Salidas inventario',
          routePath: '/inventory-exits',
        ),
    ];
  }

  static List<AdminSidebarItem> buildPurchasesChildren({
    required bool isAdmin,
    required bool Function(String) can,
    required bool Function(Iterable<String>) canAny,
  }) {
    return [
      if (isAdmin ||
          canAny([
            AppPermissions.purchasesView,
            AppPermissions.purchasesCreate,
            AppPermissions.purchasesReceive,
          ]))
        const AdminSidebarItem(
          icon: Icons.receipt_long_rounded,
          title: 'Órdenes de compra',
          routePath: '/purchase-orders',
        ),
      if (isAdmin || can(AppPermissions.inventoryEntries))
        const AdminSidebarItem(
          icon: Icons.add_rounded,
          title: 'Entradas inventario',
          routePath: '/inventory-entries',
        ),
      if (isAdmin ||
          canAny([
            AppPermissions.purchasesView,
            AppPermissions.reportsFinancial,
          ]))
        const AdminSidebarItem(
          icon: Icons.credit_score_rounded,
          title: 'Créditos proveedores',
          routePath: '/supplier-credits',
        ),
      if (isAdmin ||
          canAny([
            AppPermissions.suppliersView,
            AppPermissions.suppliersManage,
          ]))
        const AdminSidebarItem(
          icon: Icons.local_shipping_outlined,
          title: 'Proveedores',
          routePath: '/suppliers',
        ),
    ];
  }

  static List<AdminSidebarItem> buildCustomersChildren({
    required bool isAdmin,
    required bool Function(Iterable<String>) canAny,
  }) {
    return [
      if (isAdmin ||
          canAny([
            AppPermissions.customersView,
            AppPermissions.customersManage,
            AppPermissions.posView,
            AppPermissions.posSale,
          ])) ...[
        const AdminSidebarItem(
          icon: Icons.person_outline_rounded,
          title: 'Clientes',
          routePath: '/customers',
        ),
        if (isAdmin ||
            canAny([
              AppPermissions.creditsManage,
              AppPermissions.reportsFinancial,
            ]))
          const AdminSidebarItem(
            icon: Icons.credit_score_rounded,
            title: 'Créditos clientes',
            routePath: '/customer-credits',
          ),
      ],
    ];
  }

  static List<AdminSidebarItem> buildMastersChildren({
    required bool isAdmin,
    required bool Function(Iterable<String>) canAny,
  }) {
    return [
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
          const AdminSidebarItem(
            icon: Icons.category_outlined,
            title: 'Categorías',
            routePath: '/categories',
          ),
        if (isAdmin ||
            canAny([AppPermissions.brandsManage, AppPermissions.productsEdit]))
          const AdminSidebarItem(
            icon: Icons.branding_watermark_outlined,
            title: 'Marcas',
            routePath: '/brands',
          ),
        const AdminSidebarItem(
          icon: Icons.local_offer,
          title: 'Atributos',
          routePath: '/attributes',
        ),
        const AdminSidebarItem(
          icon: Icons.science_outlined,
          title: 'Ingredientes Activos',
          routePath: '/active-ingredients',
        ),
      ],
    ];
  }

  static List<AdminSidebarItem> buildSystemChildren({
    required bool isAdmin,
    required bool Function(String) can,
    required bool Function(Iterable<String>) canAny,
    required bool loyaltyEnabled,
  }) {
    return [
      if (can(AppPermissions.usersView))
        const AdminSidebarItem(
          icon: Icons.account_circle_outlined,
          title: 'Usuarios',
          routePath: '/users',
        ),
      if (canAny([
        AppPermissions.rolesManage,
        AppPermissions.permissionsAssign,
      ]))
        const AdminSidebarItem(
          icon: Icons.shield_outlined,
          title: 'Roles y Permisos',
          routePath: '/roles',
        ),
      if (isAdmin ||
          canAny([
            AppPermissions.financialAccountsManage,
            AppPermissions.reportsFinancial,
            AppPermissions.settingsView,
          ]))
        const AdminSidebarItem(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Cuentas',
          routePath: '/financial-accounts',
        ),
      if (isAdmin ||
          canAny([
            AppPermissions.warehousesManage,
            AppPermissions.inventoryTransfer,
            AppPermissions.settingsView,
          ]))
        const AdminSidebarItem(
          icon: Icons.warehouse_outlined,
          title: 'Almacenes',
          routePath: '/warehouses',
        ),
      if (loyaltyEnabled && can(AppPermissions.settingsEdit))
        const AdminSidebarItem(
          icon: Icons.stars_rounded,
          title: 'Puntos y Monedas',
          routePath: '/points-settings',
        ),
    ];
  }
}
