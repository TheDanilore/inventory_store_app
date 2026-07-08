import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/config/presentation/providers/app_config_provider.dart';
import 'package:inventory_store_app/core/widgets/admin_layout.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/customers/presentation/providers/customer_detail_provider.dart';
import 'package:inventory_store_app/features/customers/presentation/providers/customers_provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/widgets/customers/customer_form_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/widgets/customer_detail/customer_header_card.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/widgets/customer_detail/customer_kpi_row.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/widgets/customer_detail/customer_credit_section.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/widgets/customer_detail/customer_locations_section.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/widgets/customer_detail/customer_top_products_section.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/widgets/customer_detail/customer_recent_orders_section.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class CustomerDetailScreen extends StatelessWidget {
  final CustomerSummary customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CustomerDetailProvider(customer)..loadAllData(),
      child: const _CustomerDetailContent(),
    );
  }
}

class _CustomerDetailContent extends StatelessWidget {
  const _CustomerDetailContent();

  void _openEditCustomer(BuildContext context) async {
    final customer = context.read<CustomerDetailProvider>().customer;
    await CustomerFormSheet.show(context, customer: customer);
    if (context.mounted) {
      // Refresh the details
      context.read<CustomerDetailProvider>().loadAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerDetailProvider>();
    final c = provider.customer;

    return AdminLayout(
      title: c.fullName,
      showBackButton: true,
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: provider.loadAllData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 750;
            final isLoyaltyEnabled =
                context.watch<AppConfigProvider>().loyaltyGlobalEnabled;

            if (isTablet) {
              return _buildTabletLayout(context, provider, isLoyaltyEnabled);
            }
            return _buildMobileLayout(context, provider, isLoyaltyEnabled);
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    CustomerDetailProvider provider,
    bool isLoyaltyEnabled,
  ) {
    final c = provider.customer;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: CustomerHeaderCard(
            customer: c,
            onEdit: () => _openEditCustomer(context),
          ),
        ),
        if (provider.isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _CustomerDetailSkeleton(),
          )
        else if (provider.errorMessage != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                provider.errorMessage!,
                style: const TextStyle(color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),
              CustomerKpiRow(
                totalSpent: c.totalSpent,
                orderCount: c.orderCount,
                avgOrder: provider.avgOrderValue,
                walletBalance: c.walletBalance,
                isLoyaltyEnabled: isLoyaltyEnabled,
              ),
              const SizedBox(height: 24),
              if (provider.hasCredit)
                CustomerCreditSection(
                  debt: provider.currentDebt,
                  limit: provider.creditLimit,
                  isActive: provider.creditIsActive,
                  creditId: provider.creditId!,
                  customer: c,
                  movements: provider.creditMovements,
                  onPaymentRegistered: provider.loadAllData,
                ),
              CustomerLocationsSection(locations: provider.locations),
              if (provider.topProducts.isNotEmpty)
                CustomerTopProductsSection(products: provider.topProducts),
              CustomerRecentOrdersSection(orders: provider.recentOrders),
              const SizedBox(height: 40),
            ]),
          ),
      ],
    );
  }

  Widget _buildTabletLayout(
    BuildContext context,
    CustomerDetailProvider provider,
    bool isLoyaltyEnabled,
  ) {
    final c = provider.customer;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna Izquierda (Master)
        Expanded(
          flex: 4,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: CustomerHeaderCard(
                  customer: c,
                  onEdit: () => _openEditCustomer(context),
                ),
              ),
              if (provider.isLoading)
                const SliverToBoxAdapter(
                  child: _CustomerDetailSkeleton(isTabletLeftColumn: true),
                )
              else if (provider.errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: AppColors.danger),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    CustomerKpiRow(
                      totalSpent: c.totalSpent,
                      orderCount: c.orderCount,
                      avgOrder: provider.avgOrderValue,
                      walletBalance: c.walletBalance,
                      isLoyaltyEnabled: isLoyaltyEnabled,
                    ),
                    const SizedBox(height: 24),
                    if (provider.hasCredit)
                      CustomerCreditSection(
                        debt: provider.currentDebt,
                        limit: provider.creditLimit,
                        isActive: provider.creditIsActive,
                        creditId: provider.creditId!,
                        customer: c,
                        movements: provider.creditMovements,
                        onPaymentRegistered: provider.loadAllData,
                      ),
                    const SizedBox(height: 40),
                  ]),
                ),
            ],
          ),
        ),

        // Columna Derecha (Detail)
        if (!provider.isLoading && provider.errorMessage == null)
          Expanded(
            flex: 6,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(top: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      CustomerLocationsSection(locations: provider.locations),
                      if (provider.topProducts.isNotEmpty)
                        CustomerTopProductsSection(
                          products: provider.topProducts,
                        ),
                      CustomerRecentOrdersSection(
                        orders: provider.recentOrders,
                      ),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          )
        else if (provider.isLoading)
          Expanded(
            flex: 6,
            child: CustomScrollView(
              physics: const NeverScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: const _CustomerDetailSkeleton(
                      isTabletRightColumn: true,
                    ),
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
