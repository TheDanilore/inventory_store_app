import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
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
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/screens/splash_screen.dart';
import 'package:inventory_store_app/shared/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  // Asegura que Flutter esté inicializado antes de ejecutar código nativo o asíncrono
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa los datos de fecha para español
  await initializeDateFormatting('es', null);

  await Supabase.initialize(
    url: 'https://lvupdgdmlmzztjmydqak.supabase.co',
    publishableKey: 'sb_publishable_rTnni_12Jz1J9IDn5Jshew_kzyof4jB',
  );

  // 3. Finalmente corres la app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppConfigProvider()),
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => PosProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => WalletProvider(), lazy: true),
        ChangeNotifierProvider(
          create: (_) => CustomerCreditsProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => SupplierCreditsProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => OrdersProvider(), lazy: true),
        ChangeNotifierProvider(
          create: (_) => PurchaseOrdersProvider(),
          lazy: true,
        ),
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
        ChangeNotifierProvider(
          create: (_) => InventoryExitsProvider(),
          lazy: true,
        ),
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
        ChangeNotifierProvider(create: (_) => ActiveIngredientsProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => WarehousesProvider(), lazy: true),
      ],
      child: MaterialApp(
        title: 'Inventario Store',
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,

        // 2. AGREGA ESTAS DOS LÍNEAS AQUÍ:
        supportedLocales: const [
          Locale('es', 'ES'), // Idioma principal (Español)
          Locale('en', 'US'), // Opcional (Inglés)
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        home: const SplashScreen(),
      ),
    );
  }
}
