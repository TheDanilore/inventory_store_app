import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_credit_movements_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_credits_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_detail_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customers_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/location_management_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/wishlist_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit_list_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/auth/presentation/screens/profile_screen.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/orders_screen.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';

class CustomersRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: 'customers',
      builder: (context, state) {
        return MultiBlocProvider(
          providers: [BlocProvider(create: (_) => sl<CustomersCubit>())],
          child: const AdminLayout(
            title: 'Clientes',
            showBackButton: true,
            body: CustomersScreen(),
          ),
        );
      },
    ),
    GoRoute(
      path: 'customer-detail/:id',
      builder: (context, state) {
        final customer = state.extra;
        return AdminLayout(
          title: (customer as dynamic)?.fullName ?? 'Detalle de Cliente',
          showBackButton: true,
          body: CustomerDetailScreen(
            customer: customer as dynamic,
            onViewAllOrders: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => BlocProvider(
                        create: (_) => sl<OrdersCubit>(),
                        child: OrdersScreen(
                          customTitle:
                              'Pedidos de ${(customer as dynamic)?.fullName ?? ''}',
                        ),
                      ),
                ),
              );
            },
          ),
        );
      },
    ),
    GoRoute(
      path: 'customer-credits',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<CustomerCreditListCubit>()..loadAccounts(),
            child: Builder(
              builder: (context) {
                return AdminLayout(
                  title: 'Cuentas por Cobrar',
                  showBackButton: true,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        context.read<CustomerCreditListCubit>().loadAccounts();
                      },
                    ),
                  ],
                  body: const CustomerCreditsScreen(),
                );
              },
            ),
          ),
    ),
    GoRoute(
      path: 'customer-credit-movements/:creditId',
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

  static List<RouteBase> get customerRoutes => [
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(openedFromAdmin: false),
    ),
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
          (context, state) => WishlistScreen(
            onAddToCart: (ctx, product) {
              context.read<CartCubit>().addItem(
                CartItemEntity(
                  productId: product.id,
                  productName: product.name,
                  cartKey: CartItemEntity.buildKey(product.id, null),
                  quantity: 1,
                  unitPrice: product.salePrice,
                  unitCost: product.unitCost,
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
  ];
}
