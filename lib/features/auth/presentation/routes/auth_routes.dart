import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/screens/login_screen.dart';
import 'package:inventory_store_app/features/auth/presentation/screens/profile_screen.dart';
import 'package:inventory_store_app/features/auth/presentation/screens/splash_screen.dart';

class AuthRoutes {
  static List<RouteBase> get topLevelRoutes => [
        GoRoute(
          path: '/',
          builder: (context, state) => SplashScreen(
            onInitialize: (ctx) async {
              final configCubit = ctx.read<AppConfigCubit>();
              await Future.wait([
                configCubit.loadConfig(),
                configCubit.loadBusinessInfo(),
              ]).timeout(const Duration(seconds: 5));
            },
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ];

  static List<RouteBase> get adminRoutes => [
        GoRoute(
          path: 'profile',
          builder: (context, state) =>
              const ProfileScreen(openedFromAdmin: true),
        ),
      ];
}
