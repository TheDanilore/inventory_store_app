import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inventory_store_app/providers/network_provider.dart';
import 'package:inventory_store_app/providers/pos_provider.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart';
import 'package:inventory_store_app/providers/admin/purchase_orders_provider.dart';
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
        ChangeNotifierProvider(create: (_) => PurchaseOrdersProvider(), lazy: true),
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
