import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/customers_provider.dart';
import 'package:inventory_store_app/screens/admin/customer_detail_screen.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_form_sheet.dart';
import 'package:inventory_store_app/screens/admin/widgets/customers_stats_header.dart';
import 'package:inventory_store_app/screens/admin/widgets/top_customers_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_list_card.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CustomersProvider(),
      child: const _CustomersScreenContent(),
    );
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

    // Escuchar el tab para cambiar filtro de deuda
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final provider = context.read<CustomersProvider>();
        provider.toggleDebtFilter(_tabCtrl.index == 1);
      }
    });

    // Paginación con el Scroll
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        final provider = context.read<CustomersProvider>();
        if (!provider.isLoading && provider.hasMore) {
          provider.fetchCustomers();
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

  void _openDetail(CustomerSummary customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(customer: customer),
      ),
    ).then((_) {
      if (mounted) {
        context.read<CustomersProvider>().reload();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomersProvider>();

    return AdminLayout(
      title: 'Clientes',
      showBackButton: true,
      settingsActions: const [
        PopupMenuItem(value: 'export', child: Text('Exportar a PDF')),
      ],
      onSettingsSelected: (value) {
        if (value == 'export') {
          if (!provider.isExporting) provider.exportToPdf();
        }
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const CustomerFormSheet(),
          ).then((saved) {
            if (saved == true && mounted) {
              provider.reload();
            }
          });
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text(
          'Nuevo Cliente',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.reload(),
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // BUSCADOR
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, documento o teléfono...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        provider.isSearching
                            ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                            : _searchCtrl.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                provider.search('');
                              },
                            )
                            : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => provider.search(val.trim()),
                ),
              ),
            ),

            // ESTADÍSTICAS GLOBALES
            SliverToBoxAdapter(child: CustomersStatsHeader(provider: provider)),

            // TOP 5
            if (provider.topCustomers.isNotEmpty &&
                _searchCtrl.text.isEmpty &&
                !provider.showOnlyWithDebt)
              SliverToBoxAdapter(
                child: TopCustomersSection(
                  top: provider.topCustomers,
                  onTap: _openDetail,
                ),
              ),

            // TABS
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
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
                      const Tab(text: 'Todos los clientes'),
                      Tab(
                        text:
                            provider.debtCustomersCount > 0
                                ? 'Con deuda activa (${provider.debtCustomersCount})'
                                : 'Con deuda activa',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // LISTA PRINCIPAL
            if (provider.isLoading && provider.customers.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.customers.isEmpty)
              SliverFillRemaining(
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
                        provider.showOnlyWithDebt
                            ? 'No hay clientes con deuda activa'
                            : 'No hay clientes registrados',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == provider.customers.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child:
                                provider.isLoading
                                    ? const CircularProgressIndicator()
                                    : const Text(
                                      'No hay más clientes',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                          ),
                        );
                      }

                      final c = provider.customers[index];
                      return CustomerListCard(
                        customer: c,
                        onTap: () => _openDetail(c),
                      );
                    },
                    childCount:
                        provider.customers.length + (provider.hasMore ? 1 : 0),
                  ),
                ),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ), // Padding FAB
          ],
        ),
      ),
    );
  }
}
