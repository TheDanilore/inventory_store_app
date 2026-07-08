import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/providers/app_providers.dart';
import 'package:inventory_store_app/core/theme/app_theme.dart';
import 'package:inventory_store_app/core/router/app_router.dart';
import 'package:inventory_store_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

// ─── Singletons protegidos contra múltiples llamadas a main() ────────────────
// En Flutter Web (desarrollo con hot restart), el módulo Dart puede inicializar
// el entrypoint varias veces. Usar `late final` sin guard causaría
// "DartError: Assertion failed" al intentar reasignar una variable `late final`
// ya inicializada. La solución es usar nullable + inicialización condicional.
AuthProvider? _authProvider;
GoRouter? _router;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  usePathUrlStrategy();

  // Supabase.initialize lanza si ya fue inicializado (en hot restart).
  // Lo envolvemos para que sea idempotente.
  try {
    await initializeDateFormatting('es', null);
    await Supabase.initialize(
      url: 'https://lvupdgdmlmzztjmydqak.supabase.co',
      publishableKey: 'sb_publishable_rTnni_12Jz1J9IDn5Jshew_kzyof4jB',
    );
  } catch (e) {
    // En hot restart Supabase ya está inicializado → ignoramos el error.
    debugPrint('Supabase init (posiblemente ya inicializado): $e');
  }

  // Capturamos la URL inicial solo la primera vez.
  // En llamadas subsiguientes de main() (hot restart) _pendingDeepLink
  // ya fue capturado, así que captureInitialRoute() lo sobreescribirá
  // solo si hay una nueva ruta, lo cual es el comportamiento correcto.
  AppRouter.captureInitialRoute();

  // Inicialización idempotente: solo creamos las instancias la primera vez.
  // En hot restart estas variables ya tienen valor → no las recreamos,
  // evitando así duplicar el NavigatorKey y el GoRouter.
  _authProvider ??= AuthProvider();
  _router ??= AppRouter.createRouter(_authProvider!);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Inyectamos la instancia global con .value (no crea una nueva).
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider!),
        ...AppProviders.providersExcludingAuth,
      ],
      child: MaterialApp.router(
        restorationScopeId: 'app',
        title: 'Inventario Store',
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router!,
      ),
    );
  }
}
