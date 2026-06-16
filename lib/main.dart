import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/providers/app_providers.dart';
import 'package:inventory_store_app/shared/theme/app_theme.dart';
import 'package:inventory_store_app/router/app_router.dart';
import 'package:inventory_store_app/providers/auth_provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

// ─── Instancias globales creadas UNA SOLA VEZ ────────────────────────────────
// El GoRouter NO puede vivir dentro del árbol de widgets porque cualquier
// rebuild de MyApp (incluso causado por notifyListeners del AuthProvider)
// recrearía el router y lanzaría el "DartError: Assertion failed" de Flutter Web.
// Al crearlos aquí, en el top-level, están garantizados como singletons.
late final AuthProvider _authProvider;
late final GoRouter _router;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Usa rutas sin '#' (Path URL strategy) para la versión web
  usePathUrlStrategy();

  try {
    await initializeDateFormatting('es', null);

    await Supabase.initialize(
      url: 'https://lvupdgdmlmzztjmydqak.supabase.co',
      publishableKey: 'sb_publishable_rTnni_12Jz1J9IDn5Jshew_kzyof4jB',
    );
  } catch (e) {
    debugPrint('Error crítico inicializando la app: $e');
  }

  // Captura la URL inicial ANTES de que el router haga cualquier redirección
  AppRouter.captureInitialRoute();

  // Creamos el AuthProvider y el GoRouter UNA SOLA VEZ, fuera del árbol de widgets.
  // El router recibe el provider directamente (sin necesitar un BuildContext).
  _authProvider = AuthProvider();
  _router = AppRouter.createRouter(_authProvider);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthProvider ya instanciado: lo inyectamos con .value para que
        // el árbol lo encuentre con context.read<AuthProvider>() como siempre.
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        // El resto de providers se crean normalmente desde AppProviders
        ...AppProviders.providersExcludingAuth,
      ],
      child: MaterialApp.router(
        title: 'Inventario Store',
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
      ),
    );
  }
}
