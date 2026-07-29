import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/network/network_cubit.dart';
import 'package:inventory_store_app/core/router/app_router.dart';
import 'package:inventory_store_app/core/theme/app_theme.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';

Future<void> main() async {
  // Asegura que los canales nativos estén listos
  WidgetsFlutterBinding.ensureInitialized();

  // Optimización web/desktop de URLs
  usePathUrlStrategy();

  // Inicialización de formatos locales obligatorios
  await initializeDateFormatting('es', null);

  // Carga de persistencia local inicial
  final prefs = await SharedPreferences.getInstance();

  // 1. Buscamos primero en el almacenamiento local (porque el ERP permite cambiarlas dinámicamente)
  // 2. Si no hay nada guardado, usamos la variable de entorno inyectada de forma segura
  // 3. Como último recurso absoluto, dejamos un string vacío para forzar un fallo controlado
  final defaultUrl = const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  final defaultKey = const String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: '',
  );

  final url = prefs.getString('SUPABASE_URL') ?? defaultUrl;
  final key = prefs.getString('SUPABASE_KEY') ?? defaultKey;

  if (url.isEmpty || key.isEmpty) {
    throw Exception(
      'FALLO CRÍTICO: Las credenciales de Supabase no están configuradas.',
    );
  }

  try {
    // Inicialización idempotente y segura de Supabase
    await Supabase.initialize(url: url, publishableKey: key);
  } catch (error, stackTrace) {
    // Logs con StackTrace
    debugPrint('FALLO CRÍTICO SUPABASE: $error\n$stackTrace');
  }

  try {
    // Inicialización del contenedor de dependencias (GetIt)
    // Se sugiere pasar 'prefs' internamente para evitar lecturas duplicadas
    initDI();
  } catch (error, stackTrace) {
    debugPrint('FALLO CRÍTICO DI: $error\n$stackTrace');
    // Aquí se podría lanzar una pantalla de error nativa si es fatal
  }

  // Captura de rutas profundas (Deep Linking) de forma segura
  AppRouter.captureInitialRoute();

  // Inyección limpia: Resolvemos el Cubit central y disparamos la sesión
  final authCubit = sl<AuthCubit>()..checkSession();
  final router = AppRouter.createRouter(authCubit);

  runApp(MyApp(authCubit: authCubit, router: router));
}

class MyApp extends StatelessWidget {
  final AuthCubit authCubit;
  final GoRouter router;

  const MyApp({required this.authCubit, required this.router, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      // OPTIMIZACIÓN DE MEMORIA: Aquí SOLO viven los bloques globales transversales.
      // PosCubit, CashShiftsCubit, PointsCubit, WalletCubit, etc., deben ser movidos
      // a sus respectivas pantallas o submódulos en las definiciones de GoRouter.
      providers: [
        BlocProvider.value(value: authCubit),
        BlocProvider(create: (_) => sl<NetworkCubit>()),
        BlocProvider(
          create:
              (_) =>
                  sl<AppConfigCubit>()
                    ..fetchSettings()
                    ..loadBusinessInfo(),
        ),
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
        routerConfig: router,
      ),
    );
  }
}
