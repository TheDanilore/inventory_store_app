import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customer_form_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customers_stats_header.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/top_customers_section.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customer_list_card.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CustomersScreenContent();
  }
}

class _CustomersScreenContent extends StatefulWidget {
  const _CustomersScreenContent();

  @override
  State<_CustomersScreenContent> createState() =>
      _CustomersScreenContentState();
}

class _CustomersScreenContentState extends State<_CustomersScreenContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomersCubit>().fetchCustomers(reset: true);
      context.read<CustomersStatsCubit>().loadStats();
      context.read<TopCustomersCubit>().loadTopCustomers();
    });

    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        context.read<CustomersCubit>().toggleDebtFilter(_tabCtrl.index == 1);
      }
    });

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        final state = context.read<CustomersCubit>().state;
        if (state is CustomersLoaded && !state.hasReachedMax) {
          context.read<CustomersCubit>().fetchCustomers();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _openDetail(CustomerEntity customer) {
    context.go(
      '/admin/customers/customer-detail/${customer.id}',
      extra: customer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Clientes',
      showBackButton: false,
      settingsActions: const [
        PopupMenuItem(value: 'export', child: Text('Exportar a PDF')),
      ],
      onSettingsSelected: (value) {
        if (value == 'export') {
          context.read<CustomersCubit>().exportPdf();
        }
      },
      floatingActionButton:
          _tabCtrl.index == 0 && _searchCtrl.text.isEmpty
              ? FloatingActionButton(
                heroTag: 'add_customer',
                backgroundColor: AppColors.primary,
                onPressed: () async {
                  final customersCubit = context.read<CustomersCubit>();
                  final statsCubit = context.read<CustomersStatsCubit>();
                  final saved = await CustomerFormSheet.show(context);
                  if (saved == true && mounted) {
                    customersCubit.fetchCustomers(reset: true);
                    statsCubit.loadStats();
                  }
                },
                child: const Icon(
                  Icons.person_add_rounded,
                  color: Colors.white,
                ),
              )
              : null,
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<CustomersCubit>().fetchCustomers(reset: true);
          context.read<CustomersStatsCubit>().loadStats();
          context.read<TopCustomersCubit>().loadTopCustomers();
        },
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            const SliverToBoxAdapter(child: CustomersStatsHeader()),
            const SliverToBoxAdapter(child: TopCustomersSection()),
            _buildSearchSliver(),
            _buildTabsSliver(),
            BlocBuilder<CustomersCubit, CustomersState>(
              builder: (context, state) => _buildListSliver(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Semantics(
          label: 'Buscar cliente',
          child: BlocSelector<CustomersCubit, CustomersState, bool>(
            selector: (state) => state is CustomersLoading,
            builder: (context, isLoading) {
              return TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, documento o teléfono...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon:
                      isLoading
                          ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                          : _searchCtrl.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              context.read<CustomersCubit>().search('');
                            },
                          )
                          : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged:
                    (val) => context.read<CustomersCubit>().search(val.trim()),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTabsSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: BlocBuilder<CustomersStatsCubit, CustomersStatsState>(
            builder: (context, statsState) {
              int totalCount = 0;
              int debtCount = 0;

              if (statsState is CustomersStatsLoaded) {
                totalCount = statsState.totalCustomersCount;
                debtCount = statsState.debtCustomersCount;
              }

              return TabBar(
                controller: _tabCtrl,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Todos los clientes'),
                        if (totalCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalCount',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Con deuda activa'),
                        if (debtCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$debtCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildListSliver(CustomersState state) {
    if (state is CustomersLoading) {
      return const _CustomersSkeleton();
    } else if (state is CustomersLoaded) {
      if (state.customers.isEmpty) {
        return SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  state.showOnlyWithDebt
                      ? 'No hay clientes con deuda activa'
                      : 'No hay clientes registrados',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
                const SizedBox(height: 16),
                if (!state.showOnlyWithDebt && _searchCtrl.text.isEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const CustomerFormSheet(),
                      ).then((saved) {
                        if (saved == true && mounted) {
                          context.read<CustomersCubit>().fetchCustomers(
                            reset: true,
                          );
                          context.read<CustomersStatsCubit>().loadStats();
                        }
                      });
                    },
                    icon: const Icon(
                      Icons.person_add_rounded,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Registrar Cliente',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == state.customers.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child:
                        !state.hasReachedMax
                            ? const CircularProgressIndicator()
                            : const Text(
                              'No hay más clientes',
                              style: TextStyle(color: Colors.grey),
                            ),
                  ),
                );
              }
              final c = state.customers[index];
              return CustomerListCard(customer: c, onTap: () => _openDetail(c));
            },
            childCount: state.customers.length + (!state.hasReachedMax ? 1 : 0),
          ),
        ),
      );
    } else if (state is CustomersError) {
      return SliverFillRemaining(
        child: Center(child: Text('Error: ${state.message}')),
      );
    }

    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }
}

class _CustomersSkeleton extends StatelessWidget {
  const _CustomersSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const AppShimmer(width: 48, height: 48, borderRadius: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmer(width: 150, height: 16, borderRadius: 4),
                        SizedBox(height: 8),
                        AppShimmer(width: 100, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const AppShimmer(width: 60, height: 24, borderRadius: 12),
                ],
              ),
            ),
          );
        }, childCount: 6),
      ),
    );
  }
}
