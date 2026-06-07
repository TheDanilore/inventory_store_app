import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/network_provider.dart';
import 'package:inventory_store_app/providers/pos_provider.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/screens/splash_screen.dart';
import 'package:inventory_store_app/shared/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializa la conexión con Supabase
  await Supabase.initialize(
    url: 'https://lvupdgdmlmzztjmydqak.supabase.co',
    anonKey: 'sb_publishable_rTnni_12Jz1J9IDn5Jshew_kzyof4jB',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AppConfigProvider: se instancia aquí pero carga datos desde SplashScreen
        ChangeNotifierProvider(create: (_) => AppConfigProvider()),
        // NetworkProvider: solo escucha conectividad, no llama a Supabase
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        // CartProvider y WalletProvider arrancan con lazy:true para que no
        // inicialicen Supabase hasta que se acceda a ellos por primera vez,
        // garantizando que Supabase.initialize() ya terminó.
        ChangeNotifierProvider(create: (_) => CartProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => PosProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => WalletProvider(), lazy: true),
      ],
      child: MaterialApp(
        title: 'Inventario Store', // título fallback
        // Quita onGenerateTitle — no funciona en web para la pestaña
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
}
