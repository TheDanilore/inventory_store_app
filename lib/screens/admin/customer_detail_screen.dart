import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/customer_detail_provider.dart';
import 'package:inventory_store_app/providers/admin/customers_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/screens/admin/widgets/customers/customer_form_sheet.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_detail/customer_header_card.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_detail/customer_kpi_row.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_detail/customer_credit_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_detail/customer_addresses_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_detail/customer_top_products_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_detail/customer_recent_orders_section.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

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
      // Refresh the list of customers and the details
      context.read<CustomersProvider>().fetchCustomers();
      context.read<CustomerDetailProvider>().loadAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerDetailProvider>();
    final c = provider.customer;

    return AdminLayout(
      title: 'Detalle del Cliente',
      showBackButton: true,
      settingsActions: const [
        PopupMenuItem(value: 'edit', child: Text('Editar cliente')),
      ],
      onSettingsSelected: (value) {
        if (value == 'edit') {
          _openEditCustomer(context);
        }
      },
      body: RefreshIndicator(
        onRefresh: provider.loadAllData,
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
              const SliverFillRemaining(child: _CustomerDetailSkeleton())
            else if (provider.errorMessage != null)
              SliverFillRemaining(
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
                  if (provider.addresses.isNotEmpty)
                    CustomerAddressesSection(addresses: provider.addresses),
                  if (provider.topProducts.isNotEmpty)
                    CustomerTopProductsSection(products: provider.topProducts),
                  CustomerRecentOrdersSection(orders: provider.recentOrders),
                  const SizedBox(height: 40),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomerDetailSkeleton extends StatelessWidget {
  const _CustomerDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(child: AppShimmer(height: 80, borderRadius: 16)),
              SizedBox(width: 12),
              Expanded(child: AppShimmer(height: 80, borderRadius: 16)),
              SizedBox(width: 12),
              Expanded(child: AppShimmer(height: 80, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 24),
          const AppShimmer(width: 150, height: 24, borderRadius: 4),
          const SizedBox(height: 16),
          const AppShimmer(height: 120, borderRadius: 16),
          const SizedBox(height: 24),
          const AppShimmer(width: 180, height: 24, borderRadius: 4),
          const SizedBox(height: 16),
          const AppShimmer(height: 200, borderRadius: 16),
        ],
      ),
    );
  }
}
