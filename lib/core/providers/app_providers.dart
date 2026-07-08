import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:inventory_store_app/core/providers/network_provider.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/pos_provider.dart';
import 'package:inventory_store_app/features/loyalty/presentation/providers/wallet_provider.dart';
import 'package:inventory_store_app/features/purchases/presentation/providers/purchase_order_form_provider.dart';
import 'package:inventory_store_app/features/orders/presentation/providers/orders_provider.dart';
import 'package:inventory_store_app/features/purchases/presentation/providers/purchase_orders_provider.dart';
import 'package:inventory_store_app/features/inventory/presentation/providers/inventory_entries_provider.dart';
import 'package:inventory_store_app/features/inventory/presentation/providers/inventory_exits_provider.dart';
import 'package:inventory_store_app/features/inventory/presentation/providers/inventory_entry_form_provider.dart';
import 'package:inventory_store_app/features/inventory/presentation/providers/inventory_exit_form_provider.dart';
import 'package:inventory_store_app/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:inventory_store_app/features/customers/presentation/providers/customer_credits_provider.dart';
import 'package:inventory_store_app/features/purchases/presentation/providers/supplier_credits_provider.dart';
import 'package:inventory_store_app/features/financial/presentation/providers/financial_accounts_provider.dart';
import 'package:inventory_store_app/features/financial/presentation/providers/account_movements_provider.dart';
import 'package:inventory_store_app/features/catalog/presentation/providers/active_ingredients_provider.dart';
import 'package:inventory_store_app/features/catalog/presentation/providers/attributes_provider.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/cash_shifts_provider.dart';
import 'package:inventory_store_app/features/catalog/presentation/providers/categories_provider.dart';
import 'package:inventory_store_app/features/inventory/presentation/providers/warehouses_provider.dart';
import 'package:inventory_store_app/features/catalog/presentation/providers/admin_catalog_provider.dart';
import 'package:inventory_store_app/core/providers/app_config_provider.dart';
import 'package:inventory_store_app/features/auth/presentation/providers/profile_provider.dart';
import 'package:inventory_store_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/cart_provider.dart';
import 'package:inventory_store_app/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:inventory_store_app/features/orders/presentation/providers/cart_checkout_provider.dart';
import 'package:inventory_store_app/features/loyalty/presentation/providers/points_provider.dart';
import 'package:inventory_store_app/features/orders/presentation/providers/customer_orders_provider.dart';
import 'package:inventory_store_app/features/customers/presentation/providers/customer_wishlist_provider.dart';
import 'package:inventory_store_app/features/customers/presentation/providers/customer_locations_provider.dart';

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
    ChangeNotifierProvider(
      create: (_) => CustomerCreditsProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => CustomerCatalogProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(create: (_) => CartCheckoutProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => PointsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CustomerOrdersProvider(), lazy: true),
    ChangeNotifierProvider(
      create: (_) => CustomerWishlistProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => CustomerLocationsProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => AdminCatalogProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => SupplierCreditsProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(create: (_) => OrdersProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => PurchaseOrdersProvider(), lazy: true),
    ChangeNotifierProvider(
      create: (_) => PurchaseOrderFormProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => InventoryEntryFormProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => InventoryEntriesProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(create: (_) => InventoryExitsProvider(), lazy: true),
    ChangeNotifierProvider(
      create: (_) => InventoryExitFormProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(create: (_) => InventoryProvider(), lazy: true),
    ChangeNotifierProvider(
      create: (_) => FinancialAccountsProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => AccountMovementsProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(create: (_) => CashShiftsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CategoriesProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => AttributesProvider(), lazy: true),
    ChangeNotifierProvider(
      create: (_) => ActiveIngredientsProvider(),
      lazy: true,
    ),
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
    ChangeNotifierProvider(
      create: (_) => CustomerCreditsProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => CustomerCatalogProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(create: (_) => CartCheckoutProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => PointsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CustomerOrdersProvider(), lazy: true),
    ChangeNotifierProvider(
      create: (_) => CustomerWishlistProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => CustomerLocationsProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => AdminCatalogProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => SupplierCreditsProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(create: (_) => OrdersProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => PurchaseOrdersProvider(), lazy: true),
    ChangeNotifierProvider(
      create: (_) => PurchaseOrderFormProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => InventoryEntryFormProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => InventoryEntriesProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(create: (_) => InventoryExitsProvider(), lazy: true),
    ChangeNotifierProvider(
      create: (_) => InventoryExitFormProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(create: (_) => InventoryProvider(), lazy: true),
    ChangeNotifierProvider(
      create: (_) => FinancialAccountsProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(
      create: (_) => AccountMovementsProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(create: (_) => CashShiftsProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => CategoriesProvider(), lazy: true),
    ChangeNotifierProvider(create: (_) => AttributesProvider(), lazy: true),
    ChangeNotifierProvider(
      create: (_) => ActiveIngredientsProvider(),
      lazy: true,
    ),
    ChangeNotifierProvider(create: (_) => WarehousesProvider(), lazy: true),
  ];
}
