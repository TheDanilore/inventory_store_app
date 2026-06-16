import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:inventory_store_app/providers/network_provider.dart';
import 'package:inventory_store_app/providers/pos_provider.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart';
import 'package:inventory_store_app/providers/admin/purchase_order_form_provider.dart';
import 'package:inventory_store_app/providers/admin/orders_provider.dart';
import 'package:inventory_store_app/providers/admin/purchase_orders_provider.dart';
import 'package:inventory_store_app/providers/admin/inventory_entries_provider.dart';
import 'package:inventory_store_app/providers/admin/inventory_exits_provider.dart';
import 'package:inventory_store_app/providers/admin/inventory_entry_form_provider.dart';
import 'package:inventory_store_app/providers/admin/inventory_exit_form_provider.dart';
import 'package:inventory_store_app/providers/admin/inventory_provider.dart';
import 'package:inventory_store_app/providers/admin/customer_credits_provider.dart';
import 'package:inventory_store_app/providers/admin/supplier_credits_provider.dart';
import 'package:inventory_store_app/providers/admin/financial_accounts_provider.dart';
import 'package:inventory_store_app/providers/admin/account_movements_provider.dart';
import 'package:inventory_store_app/providers/admin/active_ingredients_provider.dart';
import 'package:inventory_store_app/providers/admin/attributes_provider.dart';
import 'package:inventory_store_app/providers/admin/cash_shifts_provider.dart';
import 'package:inventory_store_app/providers/admin/categories_provider.dart';
import 'package:inventory_store_app/providers/admin/warehouses_provider.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/profile_provider.dart';
import 'package:inventory_store_app/providers/auth_provider.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/providers/customer/catalog_provider.dart';
import 'package:inventory_store_app/providers/customer/cart_checkout_provider.dart';
import 'package:inventory_store_app/providers/customer/points_provider.dart';

class AppProviders {
  // Lista COMPLETA (por compatibilidad, aunque ya no se usa en main.dart)
  static final List<SingleChildWidget> providers = [
    ChangeNotifierProvider(create: (_) => AppConfigProvider()),
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => ProfileProvider()),
    ChangeNotifierProvider(create: (_) => NetworkProvider()),
    ChangeNotifierProvider(create: (_) => CartProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => PosProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => WalletProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CustomerCreditsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CustomerCatalogProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CartCheckoutProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => PointsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => SupplierCreditsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => OrdersProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => PurchaseOrdersProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => PurchaseOrderFormProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => InventoryEntryFormProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => InventoryEntriesProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => InventoryExitsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => InventoryExitFormProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => InventoryProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => FinancialAccountsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => AccountMovementsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CashShiftsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CategoriesProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => AttributesProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => ActiveIngredientsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => WarehousesProvider(), lazy: true),
  ];

  /// Todos los providers EXCEPTO AuthProvider.
  ///
  /// Úsalo en main.dart junto con un ChangeNotifierProvider AuthProvider.value
  /// que apunte a la instancia global creada antes de runApp(). Esto garantiza
  /// que el GoRouter y el AuthProvider sean singletons verdaderos y nunca se
  /// recreen durante rebuilds del árbol de widgets.
  static final List<SingleChildWidget> providersExcludingAuth = [
    ChangeNotifierProvider(create: (_) => AppConfigProvider()),
    ChangeNotifierProvider(create: (_) => ProfileProvider()),
    ChangeNotifierProvider(create: (_) => NetworkProvider()),
    ChangeNotifierProvider(create: (_) => CartProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => PosProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => WalletProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CustomerCreditsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CustomerCatalogProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CartCheckoutProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => PointsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => SupplierCreditsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => OrdersProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => PurchaseOrdersProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => PurchaseOrderFormProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => InventoryEntryFormProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => InventoryEntriesProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => InventoryExitsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => InventoryExitFormProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => InventoryProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => FinancialAccountsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => AccountMovementsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CashShiftsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CategoriesProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => AttributesProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => ActiveIngredientsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => WarehousesProvider(), lazy: true),
  ];
}
