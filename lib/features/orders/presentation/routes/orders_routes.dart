import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_cubit.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/orders_screen.dart';

class OrdersRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/orders',
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

  static List<RouteBase> get topLevelRoutes => [];

  static List<RouteBase> get customerRoutes => [];
}
