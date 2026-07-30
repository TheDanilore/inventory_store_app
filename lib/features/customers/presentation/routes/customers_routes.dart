import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_credit_movements_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_credits_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_detail_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customers_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/location_management_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/wishlist_screen.dart';
import 'package:inventory_store_app/features/auth/presentation/screens/profile_screen.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/orders_screen.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';

class CustomersRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/admin/customers',
      builder: (context, state) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<CustomersCubit>()),
            // Agregamos los Cubits faltantes e inicializamos sus datos
            BlocProvider(create: (_) => sl<CustomersStatsCubit>()..loadStats()),
            BlocProvider(
              create: (_) => sl<TopCustomersCubit>()..loadTopCustomers(),
            ),
          ],
          child: const CustomersScreen(),
        );
      },
    ),
    GoRoute(
      path: '/admin/customers/customer-detail/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final customer =
            state.extra is CustomerEntity
                ? state.extra as CustomerEntity
                : null;
        return CustomerDetailScreen(
          customerId: id,
          customer: customer,
          onViewAllOrders: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => BlocProvider(
                      create: (_) => sl<OrdersCubit>(),
                      child: OrdersScreen(
                        customTitle:
                            customer != null && customer.fullName.isNotEmpty
                                ? 'Pedidos de ${customer.fullName}'
                                : 'Pedidos del cliente',
                      ),
                    ),
              ),
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/admin/customer-credits',
      builder: (context, state) => const CustomerCreditsScreen(),
    ),
    GoRoute(
      path: '/admin/customer-credit-movements/:creditId',
      builder: (context, state) {
        final creditId = state.pathParameters['creditId'] ?? '';
        final args = state.extra as Map<String, dynamic>? ?? {};
        final customerName =
            args['customerName'] as String? ??
            state.uri.queryParameters['name'] ??
            '';
        final currentDebt =
            args['currentDebt'] as double? ??
            double.tryParse(state.uri.queryParameters['debt'] ?? '0') ??
            0.0;
        final creditLimit =
            args['creditLimit'] as double? ??
            double.tryParse(state.uri.queryParameters['limit'] ?? '0') ??
            0.0;

        return CustomerCreditMovementsScreen(
          creditId: creditId,
          customerName: customerName,
          currentDebt: currentDebt,
          creditLimit: creditLimit,
        );
      },
    ),
  ];

  static List<RouteBase> get topLevelRoutes => [
    GoRoute(
      path: '/locations',
      builder: (context, state) {
        final customerId =
            context.read<AuthCubit>().state.currentUser?.id ?? '';
        return LocationManagementScreen(customerId: customerId);
      },
    ),
    GoRoute(
      path: '/wishlist',
      builder:
          (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => sl<CartCubit>()..initCart(cartType: 'customer'),
              ),
            ],
            child: WishlistScreen(
              onAddToCart: (ctx, product) {
                context.read<CartCubit>().addItem(
                  CartItemEntity(
                    productId: product.id,
                    productName: product.name,
                    cartKey: CartItemEntity.buildKey(product.id, null),
                    quantity: 1,
                    unitPrice: product.displaySalePrice ?? 0.0,
                    unitCost: product.defaultVariant?.unitCost ?? 0.0,
                    availableStock: product.totalStock,
                    usesBatches: product.usesBatches,
                    imageUrl: product.primaryImageUrl,
                  ),
                );
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('${product.name} agregado al carrito'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
    ),
  ];

  static List<RouteBase> get customerRoutes => [
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(openedFromAdmin: false),
    ),
  ];
}
