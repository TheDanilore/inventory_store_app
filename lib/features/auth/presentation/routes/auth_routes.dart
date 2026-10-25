import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/screens/login_screen.dart';
import 'package:inventory_store_app/features/auth/presentation/screens/profile_screen.dart';
import 'package:inventory_store_app/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:inventory_store_app/features/auth/presentation/screens/splash_screen.dart';

import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class AuthRoutes {
  static List<RouteBase> get topLevelRoutes => [
    GoRoute(
      path: '/splash',
      builder:
          (context, state) => SplashScreen(
            onInitialize: (ctx) async {
              final configCubit = ctx.read<AppConfigCubit>();
              await configCubit.loadConfig().timeout(
                const Duration(seconds: 5),
              );
            },
          ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder:
          (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            child: const LoginScreen(),
            transitionDuration: const Duration(milliseconds: 450),
            reverseTransitionDuration: const Duration(milliseconds: 350),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: child,
              );
            },
          ),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordScreen(),
    ),
  ];

  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/profile',
      builder:
          (context, state) => const AdminLayout(
            title: 'Perfil',
            showAppBar: true,
            showBackButton: true,
            body: ProfileScreen(openedFromAdmin: true),
          ),
    ),
  ];
}
