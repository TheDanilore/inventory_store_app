import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/checkout_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/customer_orders/customer_orders_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/orders_screen.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/customer_orders_screen.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/customer_cart_screen.dart';

class OrdersRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/admin/orders',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<OrdersCubit>()..loadOrders(reset: true),
            child: const OrdersScreen(),
          ),
    ),
  ];

  static List<RouteBase> get topLevelRoutes => [
    GoRoute(
      path: '/orders',
      builder:
          (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (ctx) {
                  final userId =
                      ctx.read<AuthCubit>().state.currentUser?.id ??
                      Supabase.instance.client.auth.currentUser?.id;
                  return sl<CustomerOrdersCubit>()..init(userId);
                },
              ),
              BlocProvider(
                create: (_) => sl<CartCubit>()..initCart(cartType: 'customer'),
              ),
            ],
            child: const CustomerOrdersScreen(),
          ),
    ),
  ];

  static List<RouteBase> get customerRoutes => [
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
