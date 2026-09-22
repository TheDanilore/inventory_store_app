import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/admin/customer_credit_movements_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/admin/customer_credits_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/admin/customer_detail_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/admin/customers_screen.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';

class CustomersRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/customers',
      builder: (context, state) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<CustomersCubit>()),
            BlocProvider(create: (_) => sl<CustomersStatsCubit>()),
            BlocProvider(create: (_) => sl<TopCustomersCubit>()),
          ],
          child: const CustomersScreen(),
        );
      },
    ),
    GoRoute(
      path: '/customers/customer-detail/:id',
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
            final targetId = customer?.id ?? id;
            final targetName = customer?.fullName ?? '';
            final query =
                targetName.isNotEmpty
                    ? '?customerId=$targetId&customerName=${Uri.encodeComponent(targetName)}'
                    : '?customerId=$targetId';
            context.push('/orders$query');
          },
        );
      },
    ),
    GoRoute(
      path: '/customer-credits',
      builder: (context, state) => const CustomerCreditsScreen(),
    ),
    GoRoute(
      path: '/customer-credit-movements/:creditId',
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

        final customerId =
            args['customerId'] as String? ??
            state.uri.queryParameters['customerId'] ??
            '';

        return CustomerCreditMovementsScreen(
          creditId: creditId,
          customerName: customerName,
          currentDebt: currentDebt,
          creditLimit: creditLimit,
          customerId: customerId,
        );
      },
    ),
  ];

  static List<RouteBase> get topLevelRoutes => [];

  static List<RouteBase> get customerRoutes => [];
}
