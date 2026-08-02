import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inventory_store_app/core/config/env_config.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/network/network_cubit.dart';
import 'package:inventory_store_app/core/router/app_router.dart';
import 'package:inventory_store_app/core/theme/app_theme.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/core/widgets/fatal_error_app.dart';
import 'dart:developer' as developer;

Future<void> main() async {
  // Asegura que los canales nativos estén listos
  WidgetsFlutterBinding.ensureInitialized();

  // Optimización web/desktop de URLs
  usePathUrlStrategy();

  // Inicialización de formatos locales obligatorios
  await initializeDateFormatting('es', null);

  try {
    // Carga de persistencia local inicial
    final prefs = await SharedPreferences.getInstance();

    // Carga resiliente de credenciales (fromEnvironment -> rootBundle env.json -> SharedPreferences)
    await EnvConfig.load(prefs);

    // Inicialización idempotente y segura de Supabase
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseKey,
    );

    // Inicialización del contenedor de dependencias (GetIt)
    initDI();

    // Captura de rutas profundas (Deep Linking) de forma segura
    AppRouter.captureInitialRoute();

    // Inyección limpia: Resolvemos el Cubit central y disparamos la sesión
    final authCubit = sl<AuthCubit>()..checkSession();
    final router = AppRouter.createRouter(authCubit);

    runApp(MyApp(authCubit: authCubit, router: router));
  } catch (error, stackTrace) {
    developer.log(
      'FALLO CRÍTICO EN INICIALIZACIÓN: $error',
      error: error,
      stackTrace: stackTrace,
      name: 'MainEntrypoint',
    );

    // Fallback: Mostrar pantalla de error segura en vez de crashear el framework
    runApp(
      FatalErrorApp(error: error.toString(), stackTrace: stackTrace.toString()),
    );
  }
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
