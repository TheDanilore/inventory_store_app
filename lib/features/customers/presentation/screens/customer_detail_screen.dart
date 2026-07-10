import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_detail_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_detail_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_locations_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_locations_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credits_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credits_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customer_form_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_detail/customer_header_card.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_detail/customer_kpi_row.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_detail/customer_credit_section.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_detail/customer_locations_section.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_detail/customer_top_products_section.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_detail/customer_recent_orders_section.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class CustomerDetailScreen extends StatelessWidget {
  final CustomerEntity customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<CustomerDetailCubit>()..loadCustomer(customer.id),
        ),
        BlocProvider(
          create:
              (_) => sl<CustomerLocationsCubit>()..loadLocations(customer.id),
        ),
        BlocProvider(
          create:
              (_) => sl<CustomerCreditsCubit>()..loadCreditData(customer.id),
        ),
      ],
      child: const _CustomerDetailContent(),
    );
  }
}

class _CustomerDetailContent extends StatelessWidget {
  const _CustomerDetailContent();

  void _openEditCustomer(BuildContext context) async {
    final state = context.read<CustomerDetailCubit>().state;
    if (state is CustomerDetailLoaded) {
      await CustomerFormSheet.show(context, customer: state.customer);
      if (context.mounted) {
        context.read<CustomerDetailCubit>().loadCustomer(state.customer.id);
      }
    }
  }

  void _refreshData(BuildContext context) {
    final state = context.read<CustomerDetailCubit>().state;
    if (state is CustomerDetailLoaded) {
      context.read<CustomerDetailCubit>().loadCustomer(state.customer.id);
      context.read<CustomerLocationsCubit>().loadLocations(state.customer.id);
      context.read<CustomerCreditsCubit>().loadCreditData(state.customer.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerDetailCubit, CustomerDetailState>(
      builder: (context, state) {
        final isLoading =
            state is CustomerDetailLoading || state is CustomerDetailInitial;
        final error = state is CustomerDetailError ? state.message : null;
        final c = state is CustomerDetailLoaded ? state.customer : null;

        final title = c?.fullName ?? 'Cargando...';

        return AdminLayout(
          title: title,
          showBackButton: true,
          body: RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: () async => _refreshData(context),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth > 750;
                final isLoyaltyEnabled =
                    context.watch<AppConfigCubit>().loyaltyGlobalEnabled;

                if (isTablet) {
                  return _buildTabletLayout(
                    context,
                    state,
                    isLoyaltyEnabled,
                    isLoading,
                    error,
                    c,
                  );
                }
                return _buildMobileLayout(
                  context,
                  state,
                  isLoyaltyEnabled,
                  isLoading,
                  error,
                  c,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    CustomerDetailState state,
    bool isLoyaltyEnabled,
    bool isLoading,
    String? error,
    CustomerEntity? c,
  ) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (c != null)
          SliverToBoxAdapter(
            child: CustomerHeaderCard(
              customer: c,
              onEdit: () => _openEditCustomer(context),
            ),
          ),
        if (isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _CustomerDetailSkeleton(),
          )
        else if (error != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                error,
                style: const TextStyle(color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else if (state is CustomerDetailLoaded)
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),
              CustomerKpiRow(
                totalSpent: c!.totalRevenue,
                orderCount: c.orderCount,
                avgOrder:
                    state.recentOrders.isNotEmpty
                        ? c.totalRevenue / c.orderCount
                        : 0,
                walletBalance: c.walletBalance,
                isLoyaltyEnabled: isLoyaltyEnabled,
              ),
              const SizedBox(height: 24),
              BlocBuilder<CustomerCreditsCubit, CustomerCreditsState>(
                builder: (context, creditState) {
                  if (creditState is CustomerCreditsLoaded) {
                    return CustomerCreditSection(
                      debt: creditState.creditAccount.currentDebt,
                      limit: creditState.creditAccount.creditLimit,
                      isActive: creditState.creditAccount.isActive,
                      creditId: creditState.creditAccount.id,
                      customer: c,
                      movements: creditState.movements,
                      onPaymentRegistered:
                          () => context
                              .read<CustomerCreditsCubit>()
                              .loadCreditData(c.id),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              BlocBuilder<CustomerLocationsCubit, CustomerLocationsState>(
                builder: (context, locState) {
                  if (locState is CustomerLocationsLoaded) {
                    return CustomerLocationsSection(
                      locations: locState.locations,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              if (state.topProducts.isNotEmpty)
                CustomerTopProductsSection(products: state.topProducts),
              CustomerRecentOrdersSection(orders: state.recentOrders, customerId: state.customer.id, customerName: state.customer.fullName),
              const SizedBox(height: 40),
            ]),
          ),
      ],
    );
  }

  Widget _buildTabletLayout(
    BuildContext context,
    CustomerDetailState state,
    bool isLoyaltyEnabled,
    bool isLoading,
    String? error,
    CustomerEntity? c,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna Izquierda (Master)
        Expanded(
          flex: 4,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (c != null)
                SliverToBoxAdapter(
                  child: CustomerHeaderCard(
                    customer: c,
                    onEdit: () => _openEditCustomer(context),
                  ),
                ),
              if (isLoading)
                const SliverToBoxAdapter(
                  child: _CustomerDetailSkeleton(isTabletLeftColumn: true),
                )
              else if (error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      error,
                      style: const TextStyle(color: AppColors.danger),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (state is CustomerDetailLoaded)
                SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    CustomerKpiRow(
                      totalSpent: c!.totalRevenue,
                      orderCount: c.orderCount,
                      avgOrder:
                          state.recentOrders.isNotEmpty
                              ? c.totalRevenue / c.orderCount
                              : 0,
                      walletBalance: c.walletBalance,
                      isLoyaltyEnabled: isLoyaltyEnabled,
                    ),
                    const SizedBox(height: 24),
                    BlocBuilder<CustomerCreditsCubit, CustomerCreditsState>(
                      builder: (context, creditState) {
                        if (creditState is CustomerCreditsLoaded) {
                          return CustomerCreditSection(
                            debt: creditState.creditAccount.currentDebt,
                            limit: creditState.creditAccount.creditLimit,
                            isActive: creditState.creditAccount.isActive,
                            creditId: creditState.creditAccount.id,
                            customer: c,
                            movements: creditState.movements,
                            onPaymentRegistered:
                                () => context
                                    .read<CustomerCreditsCubit>()
                                    .loadCreditData(c.id),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 40),
                  ]),
                ),
            ],
          ),
        ),

        // Columna Derecha (Detail)
        if (!isLoading && error == null && state is CustomerDetailLoaded)
          Expanded(
            flex: 6,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(top: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      BlocBuilder<
                        CustomerLocationsCubit,
                        CustomerLocationsState
                      >(
                        builder: (context, locState) {
                          if (locState is CustomerLocationsLoaded) {
                            return CustomerLocationsSection(
                              locations: locState.locations,
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      if (state.topProducts.isNotEmpty)
                        CustomerTopProductsSection(products: state.topProducts),
                      CustomerRecentOrdersSection(orders: state.recentOrders, customerId: state.customer.id, customerName: state.customer.fullName),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          )
        else if (isLoading)
          const Expanded(
            flex: 6,
            child: CustomScrollView(
              physics: NeverScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: _CustomerDetailSkeleton(isTabletRightColumn: true),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CustomerDetailSkeleton extends StatelessWidget {
  final bool isTabletLeftColumn;
  final bool isTabletRightColumn;

  const _CustomerDetailSkeleton({
    this.isTabletLeftColumn = false,
    this.isTabletRightColumn = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isTabletRightColumn) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppShimmer(height: 120, borderRadius: 16),
              SizedBox(height: 24),
              AppShimmer(height: 200, borderRadius: 16),
              SizedBox(height: 24),
              AppShimmer(height: 250, borderRadius: 16),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isTabletLeftColumn) const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(child: AppShimmer(height: 80, borderRadius: 16)),
                SizedBox(width: 10),
                Expanded(child: AppShimmer(height: 80, borderRadius: 16)),
                SizedBox(width: 10),
                Expanded(child: AppShimmer(height: 80, borderRadius: 16)),
                SizedBox(width: 10),
                Expanded(child: AppShimmer(height: 80, borderRadius: 16)),
              ],
            ),
            const SizedBox(height: 24),
            const AppShimmer(height: 180, borderRadius: 16),
            if (!isTabletLeftColumn) ...const [
              SizedBox(height: 24),
              AppShimmer(height: 120, borderRadius: 16),
              SizedBox(height: 24),
              AppShimmer(height: 250, borderRadius: 16),
            ],
          ],
        ),
      ),
    );
  }
}

