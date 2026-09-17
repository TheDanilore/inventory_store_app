import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_cubit.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/checkout_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/customer_orders/customer_orders_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/wallet_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/orders_screen.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/customer_orders_screen.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/customer_cart_screen.dart';

class OrdersRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/admin/orders',
      builder: (context, state) {
        final orderId =
            state.uri.queryParameters['selectedId'] ??
            state.uri.queryParameters['orderId'];
        final customerId = state.uri.queryParameters['customerId'];
        final customerName = state.uri.queryParameters['customerName'];

        return BlocProvider(
          create: (_) {
            final cubit = sl<OrdersCubit>();
            if (customerId != null && customerId.isNotEmpty) {
              cubit.setCustomerIdFilter(customerId);
            }
            return cubit..loadOrders(reset: true);
          },
          child: OrdersScreen(
            targetOrderId: orderId,
            customTitle:
                (customerName != null && customerName.isNotEmpty)
                    ? 'Pedidos de $customerName'
                    : null,
          ),
        );
      },
    ),
  ];

  static List<RouteBase> get topLevelRoutes => [
    GoRoute(
      path: '/orders',
      builder:
          (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (ctx) => sl<CustomerOrdersCubit>()..init()),
              BlocProvider(create: (_) => sl<WalletCubit>()),
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
