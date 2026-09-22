import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/top_customers/loyalty_top_customers_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/admin/points_settings_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/top_customers_screen.dart';

class LoyaltyRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/customers/top-customers',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<LoyaltyTopCustomersCubit>(),
            child: const TopCustomersScreen(),
          ),
    ),
    GoRoute(
      path: '/points-settings',
      builder: (context, state) => const PointsSettingsScreen(),
    ),
  ];

  static List<RouteBase> get customerRoutes => [];
}
