import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/providers/app_providers.dart';
import 'package:inventory_store_app/shared/theme/app_theme.dart';
import 'package:inventory_store_app/router/app_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

Future<void> main() async {
  // Asegura que Flutter esté inicializado antes de ejecutar código nativo o asíncrono
  WidgetsFlutterBinding.ensureInitialized();

  // Usa rutas sin el '#' (Path URL strategy) para la versión web
  usePathUrlStrategy();

  try {
    // Inicializa los datos de fecha para español
    await initializeDateFormatting('es', null);

    // Inicializa Supabase
    await Supabase.initialize(
      url: 'https://lvupdgdmlmzztjmydqak.supabase.co',
      publishableKey: 'sb_publishable_rTnni_12Jz1J9IDn5Jshew_kzyof4jB',
    );
  } catch (e) {
    debugPrint('Error crítico inicializando la app: $e');
  }

  // Finalmente corremos la app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      child: Builder(
        builder: (context) {
          final router = AppRouter.createRouter(context);
          return MaterialApp.router(
            title: 'Inventario Store',
            theme: AppTheme.light(),
            debugShowCheckedModeBanner: false,

            supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            routerConfig: router,
          );
        },
      ),
    );
  }
}
