import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/pos_provider.dart';
import 'package:inventory_store_app/features/users/presentation/providers/users_provider.dart';
import 'package:inventory_store_app/core/theme/app_theme.dart';
import 'package:inventory_store_app/core/router/app_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/network/network_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/cart_provider.dart';

import 'package:inventory_store_app/features/loyalty/presentation/bloc/points_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/wallet_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/top_customers_cubit.dart';

// ─── Singletons protegidos contra múltiples llamadas a main() ────────────────
// En Flutter Web (desarrollo con hot restart), el módulo Dart puede inicializar
// el entrypoint varias veces. Usar `late final` sin guard causaría
// "DartError: Assertion failed" al intentar reasignar una variable `late final`
// ya inicializada. La solución es usar nullable + inicialización condicional.
AuthCubit? _authCubit;
GoRouter? _router;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await initializeDateFormatting('es', null);

  final prefs = await SharedPreferences.getInstance();
  
  // Si no hay conexión guardada, usamos la de por defecto
  final url = prefs.getString('SUPABASE_URL') ?? 'https://lvupdgdmlmzztjmydqak.supabase.co';
  final key = prefs.getString('SUPABASE_KEY') ?? 'sb_publishable_rTnni_12Jz1J9IDn5Jshew_kzyof4jB';

  await _initErpAndRunApp(url, key);
}

Future<void> _initErpAndRunApp(String url, String publishableKey) async {
  // Supabase.initialize lanza si ya fue inicializado (en hot restart).
  // Lo envolvemos para que sea idempotente.
  try {
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );
  } catch (e) {
    // En hot restart Supabase ya está inicializado → ignoramos el error.
    debugPrint('Supabase init (posiblemente ya inicializado): $e');
  }

  // Inicializar Inyección de Dependencias
  try {
    initDI();
  } catch (e) {
    debugPrint('DI init: $e');
  }

  // Capturamos la URL inicial solo la primera vez.
  AppRouter.captureInitialRoute();

  // Inicialización idempotente
  _authCubit ??= sl<AuthCubit>()..checkSession();
  _router ??= AppRouter.createRouter(_authCubit!);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authCubit!),
        BlocProvider(create: (_) => sl<NetworkCubit>()),
        BlocProvider(
          create: (_) => sl<AppConfigCubit>()
            ..fetchSettings()
            ..loadBusinessInfo(),
        ),
        BlocProvider(create: (_) => sl<PointsCubit>()),
        BlocProvider(create: (_) => sl<WalletCubit>()),
        BlocProvider(create: (_) => sl<TopCustomersCubit>()),
      ],
      child: MultiProvider(
        providers: [
          // Inyectamos la instancia global con .value (no crea una nueva).
          
          ChangeNotifierProvider(create: (_) => UsersProvider(role: '')),
          ChangeNotifierProvider(create: (_) => PosProvider()),
          ChangeNotifierProvider(create: (_) => CartProvider()),
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
      ),
    );
  }
}
