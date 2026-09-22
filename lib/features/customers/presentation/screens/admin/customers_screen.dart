import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customer_form_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customer_list_card.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customers_stats_header.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/top_customers_section.dart';
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
  final _searchFocusNode = FocusNode();
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
    _searchFocusNode.dispose();
    _scrollCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _openDetail(CustomerEntity customer) {
    context.go(
      '/customers/customer-detail/${customer.id}',
      extra: customer,
    );
  }

  Future<void> _openCreateCustomer() async {
    final customersCubit = context.read<CustomersCubit>();
    final statsCubit = context.read<CustomersStatsCubit>();
    final saved = await CustomerFormSheet.show(context);
    if (saved == true && mounted) {
      customersCubit.fetchCustomers(reset: true);
      statsCubit.loadStats();
    }
  }

  Future<void> _openEditCustomer(CustomerEntity customer) async {
    final customersCubit = context.read<CustomersCubit>();
    final statsCubit = context.read<CustomersStatsCubit>();
    final saved = await CustomerFormSheet.show(context, customer: customer);
    if (saved == true && mounted) {
      customersCubit.fetchCustomers(reset: true);
      statsCubit.loadStats();
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado: $text',
      type: SnackbarType.info,
      duration: const Duration(seconds: 2),
    );
  }

  void _showContextMenu(
    BuildContext context,
    Offset position,
    CustomerEntity customer,
  ) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        PopupMenuItem(
          value: 'detail',
          child: Row(
            children: const [
              Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Ver ficha completa', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: const [
              Icon(Icons.edit_outlined, size: 18, color: AppColors.slate),
              SizedBox(width: 10),
              Text('Editar datos', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        if (customer.phone != null && customer.phone!.isNotEmpty)
          PopupMenuItem(
            value: 'copy_phone',
            child: Row(
              children: const [
                Icon(Icons.copy_rounded, size: 18, color: AppColors.slate),
                SizedBox(width: 10),
                Text('Copiar teléfono', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        if (customer.documentNumber != null &&
            customer.documentNumber!.isNotEmpty)
          PopupMenuItem(
            value: 'copy_doc',
            child: Row(
              children: const [
                Icon(Icons.badge_outlined, size: 18, color: AppColors.slate),
                SizedBox(width: 10),
                Text('Copiar documento', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'detail':
          _openDetail(customer);
          break;
        case 'edit':
          _openEditCustomer(customer);
          break;
        case 'copy_phone':
          if (customer.phone != null) {
            _copyToClipboard(customer.phone!, 'Teléfono');
          }
          break;
        case 'copy_doc':
          if (customer.documentNumber != null) {
            _copyToClipboard(
              customer.documentNumber!,
              customer.documentType ?? 'Documento',
            );
          }
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyN, alt: true): () {
              _openCreateCustomer();
            },
            const SingleActivator(LogicalKeyboardKey.keyN, control: true):
                _openCreateCustomer,
            const SingleActivator(LogicalKeyboardKey.keyK, alt: true): () {
              _searchFocusNode.requestFocus();
            },
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
              _searchFocusNode.requestFocus();
            },
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_searchCtrl.text.isNotEmpty) {
                _searchCtrl.clear();
                context.read<CustomersCubit>().search('');
              }
              _searchFocusNode.unfocus();
            },
          },
          child: Focus(
            autofocus: false,
            child: AdminLayout(
              title: 'Clientes',
              showBackButton: true,
              settingsActions: const [
                PopupMenuItem(value: 'export', child: Text('Exportar a PDF')),
              ],
              onSettingsSelected: (value) {
                if (value == 'export') {
                  context.read<CustomersCubit>().exportPdf();
                }
              },
              // FAB solo visible en móvil (en desktop se usa el botón de toolbar)
              floatingActionButton:
                  (!isDesktop &&
                          _tabCtrl.index == 0 &&
                          _searchCtrl.text.isEmpty)
                      ? FloatingActionButton(
                        heroTag: 'add_customer',
                        backgroundColor: AppColors.primary,
                        onPressed: _openCreateCustomer,
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
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: CustomersStatsHeader()),
                    const SliverToBoxAdapter(child: TopCustomersSection()),
                    BlocSelector<CustomersStatsCubit, CustomersStatsState,
                        ({int total, int debt})>(
                      selector: (statsState) {
                        if (statsState is CustomersStatsLoaded) {
                          return (
                            total: statsState.totalCustomersCount,
                            debt: statsState.debtCustomersCount,
                          );
                        }
                        return (total: 0, debt: 0);
                      },
                      builder: (context, counts) {
                        if (isDesktop) {
                          return _buildDesktopToolbarSliver(
                            counts.total,
                            counts.debt,
                          );
                        }

                        return SliverMainAxisGroup(
                          slivers: [
                            _buildMobileSearchSliver(),
                            _buildMobileTabsSliver(counts.total, counts.debt),
                          ],
                        );
                      },
                    ),
                    BlocBuilder<CustomersCubit, CustomersState>(
                      builder: (context, state) =>
                          _buildListSliver(state, isDesktop),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── DESKTOP UNIFIED TOOLBAR (Stripe / Linear Pro Style) ──────────────────────

  Widget _buildDesktopToolbarSliver(int totalCount, int debtCount) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(opacity: 0.02),
          ),
          child: Row(
            children: [
              // Segmented Control de Pestañas
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(2.5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSegmentButton(
                      title: 'Todos los clientes',
                      count: totalCount,
                      isSelected: _tabCtrl.index == 0,
                      onTap: () {
                        setState(() => _tabCtrl.animateTo(0));
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildSegmentButton(
                      title: 'Con deuda activa',
                      count: debtCount,
                      isSelected: _tabCtrl.index == 1,
                      isAlert: debtCount > 0,
                      onTap: () {
                        setState(() => _tabCtrl.animateTo(1));
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              // Buscador compacto con ancho ergonómico delimitado
              SizedBox(
                width: 360,
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Buscar por nombre, documento o teléfono...',
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    suffixIcon: _buildSearchSuffix(isDesktop: true),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged:
                      (val) => context.read<CustomersCubit>().search(val.trim()),
                ),
              ),

              const Spacer(),

              // Botón secundario: Exportar PDF
              OutlinedButton.icon(
                icon: const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                label: const Text('Exportar PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => context.read<CustomersCubit>().exportPdf(),
              ),

              const SizedBox(width: 10),

              // Botón Primario: + Nuevo Cliente [N]
              FilledButton.icon(
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nuevo cliente'),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Alt + N',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _openCreateCustomer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    bool isAlert = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color:
                      isAlert
                          ? AppColors.error
                          : (isSelected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color:
                        isAlert
                            ? Colors.white
                            : (isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── MOBILE TOOLBAR (Apple HIG Style) ───────────────────────────────────────

  Widget _buildMobileSearchSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        child: Semantics(
          label: 'Buscar cliente',
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, documento o teléfono...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
              suffixIcon: _buildSearchSuffix(isDesktop: false),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged:
                (val) => context.read<CustomersCubit>().search(val.trim()),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTabsSliver(int totalCount, int debtCount) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _tabCtrl,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
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
          ),
        ),
      ),
    );
  }

  Widget? _buildSearchSuffix({required bool isDesktop}) {
    return BlocSelector<CustomersCubit, CustomersState, bool>(
      selector: (state) => state is CustomersLoading,
      builder: (context, isLoading) {
        if (isLoading) {
          return const Padding(
            padding: EdgeInsets.all(10.0),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (_searchCtrl.text.isNotEmpty) {
          return IconButton(
            icon: const Icon(Icons.clear_rounded, size: 18),
            splashRadius: 18,
            onPressed: () {
              _searchCtrl.clear();
              context.read<CustomersCubit>().search('');
            },
          );
        }
        if (isDesktop) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Alt + K',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  // ── LIST / TABLE BUILDER ───────────────────────────────────────────────────

  Widget _buildListSliver(CustomersState state, bool isDesktop) {
    if (state is CustomersLoading) {
      return isDesktop
          ? const _DesktopTableSkeleton()
          : const _CustomersSkeleton();
    } else if (state is CustomersLoaded) {
      if (state.customers.isEmpty) {
        return SliverFillRemaining(
          child: _buildEmptyState(state, isDesktop),
        );
      }

      if (isDesktop) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _DesktopCustomersTable(
              customers: state.customers,
              hasReachedMax: state.hasReachedMax,
              onOpenDetail: _openDetail,
              onEditCustomer: _openEditCustomer,
              onContextMenu: _showContextMenu,
              onLoadMore: () => context.read<CustomersCubit>().fetchCustomers(),
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
                              style: TextStyle(color: AppColors.textMuted),
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'Error al cargar clientes: ${state.message}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.read<CustomersCubit>().fetchCustomers(reset: true),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  Widget _buildEmptyState(CustomersLoaded state, bool isDesktop) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 56,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            state.showOnlyWithDebt
                ? 'No hay clientes con deuda activa'
                : 'No hay clientes registrados',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.showOnlyWithDebt
                ? 'Todos los clientes están al día con sus pagos.'
                : 'Agrega un cliente para comenzar a registrar compras.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          if (!state.showOnlyWithDebt && _searchCtrl.text.isEmpty)
            FilledButton.icon(
              onPressed: _openCreateCustomer,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Registrar primer cliente'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── DESKTOP DATA TABLE WIDGETS ────────────────────────────────────────────────

class _DesktopCustomersTable extends StatelessWidget {
  final List<CustomerEntity> customers;
  final bool hasReachedMax;
  final ValueChanged<CustomerEntity> onOpenDetail;
  final ValueChanged<CustomerEntity> onEditCustomer;
  final void Function(BuildContext context, Offset pos, CustomerEntity customer)
  onContextMenu;
  final VoidCallback onLoadMore;

  const _DesktopCustomersTable({
    required this.customers,
    required this.hasReachedMax,
    required this.onOpenDetail,
    required this.onEditCustomer,
    required this.onContextMenu,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(opacity: 0.03),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    'CLIENTE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'CONTACTO / DOC',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ESTADO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'COMPRAS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'DEUDA ACTUAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'TOTAL FACTURADO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Center(
                    child: Text(
                      'ACCIONES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          for (int i = 0; i < customers.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.divider,
              ),
            _DesktopCustomerRow(
              key: ValueKey(customers[i].id),
              customer: customers[i],
              onOpen: () => onOpenDetail(customers[i]),
              onEdit: () => onEditCustomer(customers[i]),
              onContextMenu: (pos) => onContextMenu(context, pos, customers[i]),
            ),
          ],

          if (!hasReachedMax)
            InkWell(
              onTap: onLoadMore,
              child: Container(
                padding: const EdgeInsets.all(12),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: const Text(
                  'Cargar más clientes...',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesktopCustomerRow extends StatefulWidget {
  final CustomerEntity customer;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final ValueChanged<Offset> onContextMenu;

  const _DesktopCustomerRow({
    super.key,
    required this.customer,
    required this.onOpen,
    required this.onEdit,
    required this.onContextMenu,
  });

  @override
  State<_DesktopCustomerRow> createState() => _DesktopCustomerRowState();
}

class _DesktopCustomerRowState extends State<_DesktopCustomerRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) => widget.onContextMenu(details.globalPosition),
        child: InkWell(
          onTap: widget.onOpen,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color:
                  _isHovered
                      ? AppColors.primary.withValues(alpha: 0.035)
                      : Colors.transparent,
            ),
            child: Row(
              children: [
                // Columna 1: Cliente (Avatar + Nombre + Doc)
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      _CustomerAvatarSmall(customer: c),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.fullName,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (c.documentNumber != null &&
                                c.documentNumber!.isNotEmpty)
                              Text(
                                '${c.documentType ?? 'DOC'}: ${c.documentNumber}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Columna 2: Contacto / Teléfono
                Expanded(
                  flex: 2,
                  child:
                      (c.phone != null && c.phone!.isNotEmpty)
                          ? Row(
                            children: [
                              const Icon(
                                Icons.phone_rounded,
                                size: 13,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                c.phone!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          )
                          : const Text(
                            '—',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                ),

                // Columna 3: Estado
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildStatusBadge(c),
                  ),
                ),

                // Columna 4: Compras
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_bag_rounded,
                              size: 11,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${c.orderCount} compras',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.info,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Columna 5: Deuda Actual
                Expanded(
                  flex: 2,
                  child:
                      c.currentDebt > 0
                          ? Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.danger.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  'S/ ${c.currentDebt.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          )
                          : const Text(
                            'Al día',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.success,
                            ),
                          ),
                ),

                // Columna 6: Total Facturado
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'S/ ${c.totalRevenue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        if (c.lastOrderAt != null)
                          Text(
                            DateFormat('dd/MM/yy', 'es').format(c.lastOrderAt!),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Columna 7: Acciones
                SizedBox(
                  width: 90,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        tooltip: 'Editar cliente',
                        splashRadius: 16,
                        color: AppColors.textSecondary,
                        onPressed: widget.onEdit,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        tooltip: 'Ver detalle',
                        splashRadius: 16,
                        color: AppColors.primary,
                        onPressed: widget.onOpen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(CustomerEntity c) {
    if (!c.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.slateLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Inactivo',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.slate,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (c.currentDebt > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'Con deuda',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.warningDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.successLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: const Text(
        'Activo',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.successDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CustomerAvatarSmall extends StatelessWidget {
  final CustomerEntity customer;

  const _CustomerAvatarSmall({required this.customer});

  @override
  Widget build(BuildContext context) {
    if (customer.avatarUrl != null && customer.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 17,
        backgroundColor: AppColors.background,
        backgroundImage: CachedNetworkImageProvider(customer.avatarUrl!),
      );
    }

    final color =
        Colors.primaries[customer.fullName.length % Colors.primaries.length];

    return CircleAvatar(
      radius: 17,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        customer.fullName.isNotEmpty ? customer.fullName[0].toUpperCase() : '?',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ── SKELETONS ADAPTATIVOS ───────────────────────────────────────────────────

class _DesktopTableSkeleton extends StatelessWidget {
  const _DesktopTableSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: AppColors.background,
                child: Row(
                  children: const [
                    AppShimmer(width: 80, height: 12, borderRadius: 4),
                    Spacer(),
                    AppShimmer(width: 80, height: 12, borderRadius: 4),
                  ],
                ),
              ),
              ...List.generate(
                6,
                (index) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.divider)),
                  ),
                  child: Row(
                    children: const [
                      AppShimmer(width: 34, height: 34, borderRadius: 17),
                      SizedBox(width: 12),
                      AppShimmer(width: 160, height: 14, borderRadius: 4),
                      Spacer(),
                      AppShimmer(width: 90, height: 14, borderRadius: 4),
                      SizedBox(width: 20),
                      AppShimmer(width: 70, height: 20, borderRadius: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  AppShimmer(width: 48, height: 48, borderRadius: 24),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShimmer(width: 150, height: 16, borderRadius: 4),
                        SizedBox(height: 8),
                        AppShimmer(width: 100, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  AppShimmer(width: 60, height: 24, borderRadius: 12),
                ],
              ),
            ),
          );
        }, childCount: 6),
      ),
    );
  }
}
