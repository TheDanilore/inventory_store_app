import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/checkout_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/orders_screen.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/customer_orders_screen.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/customer_cart_screen.dart';

class OrdersRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(path: 'orders', builder: (context, state) => const OrdersScreen()),
  ];

  static List<RouteBase> get customerRoutes => [
    GoRoute(
      path: '/orders',
      builder: (context, state) => const CustomerOrdersScreen(),
    ),
    GoRoute(
      path: '/cart',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<CheckoutCubit>(),
            child: const CustomerCartScreen(),
          ),
    ),
  ];
}
