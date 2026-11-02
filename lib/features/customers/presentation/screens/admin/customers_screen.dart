import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/bento_metrics/customers_bento_metrics_bar.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/common/top_vip_widgets.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customer_form_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customer_list_card.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customers_table_view.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/skeletons/customers_skeletons.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/components/customers_action_sheet_helper.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/components/customers_context_menu.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/components/customers_empty_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/components/customers_segmented_filter.dart';
import 'package:url_launcher/url_launcher.dart';

const String kTopCustomersRoute = '/customers/top-customers';

/// Pantalla principal de administración del directorio de clientes.
///
/// Refactorizada bajo principios de Clean Architecture y rendimiento:
/// - Garantía Zero-Shimmer (Frame 0 load) con Stale-While-Revalidate
/// - Ordenamiento memoizado fuera del ciclo de dibujo para dispositivos de baja gama
/// - Modularización de subcomponentes para máxima legibilidad y mantenibilidad
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
  final _screenFocusNode = FocusNode();
  final _scrollCtrl = ScrollController();

  // Estado de visualización y ordenamiento
  bool _isTableView = true;
  final String _sortColumn = 'name'; // 'name', 'orders', 'debt', 'revenue'
  final bool _sortAscending = true;

  // Cache/Memoización de ordenamiento para evitar recalcular en cada build()
  List<CustomerEntity>? _lastRawList;
  List<CustomerEntity>? _lastTopVipList;
  int _lastTabIndex = -1;
  String _lastSortCol = '';
  bool _lastSortAsc = true;
  List<CustomerEntity> _cachedSortedList = const [];

  // Estado de inspector lateral (Desktop / Tablet)
  CustomerEntity? _selectedCustomer;
  bool _isSideSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
        // Carga inicial o revalidación con Zero-Shimmer
        _reloadAll(silent: true);
      }
    });

    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        if (_tabCtrl.index == 0) {
          context.read<CustomersCubit>().fetchCustomers(
            reset: true,
            showOnlyWithDebt: false,
          );
        } else if (_tabCtrl.index == 1) {
          context.read<CustomersCubit>().toggleDebtFilter(true);
        } else if (_tabCtrl.index == 2) {
          context.read<TopCustomersCubit>().loadTopCustomers(5, true);
        }
        setState(() {});
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

  void _openTopCustomers() => context.push(kTopCustomersRoute);

  /// Carga o revalida datos con garantía Zero-Shimmer
  void _reloadAll({bool silent = false, bool forceRefresh = false}) {
    final custCubit = context.read<CustomersCubit>();
    final isAlreadyLoaded =
        custCubit.state is CustomersLoaded &&
        (custCubit.state as CustomersLoaded).hasCustomers;

    custCubit.fetchCustomers(
      reset: true,
      silent: silent || isAlreadyLoaded,
      forceRefresh: forceRefresh,
    );
    context.read<CustomersStatsCubit>().loadStats(
      silent: silent || isAlreadyLoaded,
    );
    context.read<TopCustomersCubit>().loadTopCustomers(
      5,
      silent || isAlreadyLoaded,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    _scrollCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── REGLA ESTRICTA DE AISLAMIENTO DE FOCO (FOCUS SHIELD) ────────────────────
  bool get _isInputFieldFocused {
    if (_searchFocusNode.hasFocus) return true;
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    final ctx = primaryFocus.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null ||
        ctx.findAncestorStateOfType<EditableTextState>() != null;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyN) {
      _openCreateCustomer();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyR) {
      _reloadAll(forceRefresh: true);
      AppSnackbar.show(
        context,
        message: 'Directorio de clientes actualizado',
        type: SnackbarType.info,
        duration: const Duration(seconds: 2),
      );
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyD) {
      final nextIdx = _tabCtrl.index == 1 ? 0 : 1;
      _tabCtrl.animateTo(nextIdx);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (_isSideSheetOpen && _selectedCustomer != null) {
        Navigator.of(context, rootNavigator: true).maybePop();
        return KeyEventResult.handled;
      }
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        context.read<CustomersCubit>().search('');
        return KeyEventResult.handled;
      }
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _openDetail(CustomerEntity customer) {
    context.go('/customers/customer-detail/${customer.id}', extra: customer);
  }

  Future<void> _openCreateCustomer() async {
    final customersCubit = context.read<CustomersCubit>();
    final statsCubit = context.read<CustomersStatsCubit>();
    final topCubit = context.read<TopCustomersCubit>();

    final saved = await CustomerFormSheet.show(context);
    if (saved == true && mounted) {
      customersCubit.fetchCustomers(reset: true, forceRefresh: true);
      statsCubit.loadStats();
      topCubit.loadTopCustomers();
      AppSnackbar.show(
        context,
        message: 'Cliente registrado exitosamente',
        type: SnackbarType.success,
      );
    }
  }

  Future<void> _openEditCustomer(CustomerEntity customer) async {
    final customersCubit = context.read<CustomersCubit>();
    final statsCubit = context.read<CustomersStatsCubit>();
    final topCubit = context.read<TopCustomersCubit>();

    final saved = await CustomerFormSheet.show(context, customer: customer);
    if (saved == true && mounted) {
      customersCubit.fetchCustomers(reset: true, forceRefresh: true);
      statsCubit.loadStats();
      topCubit.loadTopCustomers();
      AppSnackbar.show(
        context,
        message: 'Datos del cliente actualizados',
        type: SnackbarType.success,
      );
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

  Future<void> _launchWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    final fullPhone =
        cleanPhone.startsWith('51') ? cleanPhone : '51$cleanPhone';
    final url = Uri.parse('https://wa.me/$fullPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      AppSnackbar.show(
        context,
        message: 'No se pudo iniciar WhatsApp',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _launchPhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    final url = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else if (mounted) {
      AppSnackbar.show(
        context,
        message: 'No se pudo iniciar llamada',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _openDesktopCustomerInspector(CustomerEntity customer) async {
    if (!mounted || _isSideSheetOpen) return;
    _isSideSheetOpen = true;
    setState(() => _selectedCustomer = customer);

    await CustomerActionSheetHelper.openDesktopInspector(
      context: context,
      customer: customer,
      onEdit: () => _openEditCustomer(customer),
      onOpenFullDetail: () => _openDetail(customer),
      onWhatsApp: _launchWhatsApp,
      onCall: _launchPhoneCall,
      onCopy: _copyToClipboard,
    );

    _isSideSheetOpen = false;
    if (mounted) setState(() => _selectedCustomer = null);
  }

  void _showMobileCustomerActionSheet(CustomerEntity customer) {
    CustomerActionSheetHelper.showMobileActionSheet(
      context: context,
      customer: customer,
      onOpenDetail: () => _openDetail(customer),
      onEdit: () => _openEditCustomer(customer),
      onWhatsApp: _launchWhatsApp,
      onCall: _launchPhoneCall,
      onCopyDoc: (doc, type) => _copyToClipboard(doc, type),
    );
  }

  void _showContextMenu(
    BuildContext context,
    Offset position,
    CustomerEntity customer,
  ) {
    CustomersContextMenu.show(
      context: context,
      position: position,
      customer: customer,
      onInspector: () => _openDesktopCustomerInspector(customer),
      onDetail: () => _openDetail(customer),
      onEdit: () => _openEditCustomer(customer),
      onWhatsApp: _launchWhatsApp,
      onCopyPhone: (p) => _copyToClipboard(p, 'Teléfono'),
      onCopyDoc: (doc, type) => _copyToClipboard(doc, type),
    );
  }

  /// Memoización de ordenamiento para evitar recalcular en cada build frame
  List<CustomerEntity> _getMemoizedSortedCustomers(
    List<CustomerEntity> list,
    List<CustomerEntity> topVipList,
  ) {
    if (identical(_lastRawList, list) &&
        identical(_lastTopVipList, topVipList) &&
        _lastTabIndex == _tabCtrl.index &&
        _lastSortCol == _sortColumn &&
        _lastSortAsc == _sortAscending) {
      return _cachedSortedList;
    }

    _lastRawList = list;
    _lastTopVipList = topVipList;
    _lastTabIndex = _tabCtrl.index;
    _lastSortCol = _sortColumn;
    _lastSortAsc = _sortAscending;

    if (_tabCtrl.index == 2) {
      if (topVipList.isNotEmpty) {
        _cachedSortedList = topVipList;
        return _cachedSortedList;
      }
      final sortedVip = List<CustomerEntity>.from(list);
      sortedVip.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
      _cachedSortedList = sortedVip;
      return _cachedSortedList;
    }

    final sorted = List<CustomerEntity>.from(list);
    switch (_sortColumn) {
      case 'name':
        sorted.sort(
          (a, b) =>
              _sortAscending
                  ? a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase())
                  : b.fullName.toLowerCase().compareTo(
                    a.fullName.toLowerCase(),
                  ),
        );
        break;
      case 'orders':
        sorted.sort(
          (a, b) =>
              _sortAscending
                  ? a.orderCount.compareTo(b.orderCount)
                  : b.orderCount.compareTo(a.orderCount),
        );
        break;
      case 'debt':
        sorted.sort(
          (a, b) =>
              _sortAscending
                  ? a.currentDebt.compareTo(b.currentDebt)
                  : b.currentDebt.compareTo(a.currentDebt),
        );
        break;
      case 'revenue':
        sorted.sort(
          (a, b) =>
              _sortAscending
                  ? a.totalRevenue.compareTo(b.totalRevenue)
                  : b.totalRevenue.compareTo(a.totalRevenue),
        );
        break;
    }
    _cachedSortedList = sorted;
    return _cachedSortedList;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 720;
        final isTablet = width >= 720 && width < 1100;
        final isDesktop = width >= 1100;

        return Focus(
          focusNode: _screenFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: AdminLayout(
            title: 'Clientes',
            settingsActions: const [
              PopupMenuItem(value: 'export', child: Text('Exportar a PDF')),
              PopupMenuItem(
                value: 'reload',
                child: Text('Recargar directorio [R]'),
              ),
            ],
            onSettingsSelected: (value) {
              if (value == 'export') {
                context.read<CustomersCubit>().exportPdf();
              } else if (value == 'reload') {
                _reloadAll(forceRefresh: true);
              }
            },
            floatingActionButton:
                (isMobile && _tabCtrl.index == 0 && _searchCtrl.text.isEmpty)
                    ? FloatingActionButton.extended(
                      heroTag: 'add_customer_fab',
                      backgroundColor: AppColors.primary,
                      elevation: 4,
                      icon: const Icon(
                        Icons.person_add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Nuevo Cliente',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _openCreateCustomer,
                    )
                    : null,
            body: RefreshIndicator(
              onRefresh: () async => _reloadAll(forceRefresh: true),
              child: CustomScrollView(
                controller: _scrollCtrl,
                slivers: [
                  // 0. CABECERA EJECUTIVA STRIPE / LINEAR
                  SliverToBoxAdapter(
                    child: AdminPageHeader(
                      title: 'Directorio de Clientes',
                      subtitle:
                          'Gestiona tus clientes, su información y datos de contacto',
                      isDesktop: isDesktop,
                      actions: [
                        TopClientsHeaderButton(onPressed: _openTopCustomers),
                        AdminHeaderButton.primary(
                          label: 'Nuevo Cliente',
                          icon: Icons.person_add_rounded,
                          tooltip: 'Nuevo cliente (Atajo: N)',
                          onPressed: _openCreateCustomer,
                        ),
                      ],
                    ),
                  ),

                  // 1. FINTECH BENTO METRIC STRIP (Ultra-compacto con Stale-While-Revalidate)
                  SliverToBoxAdapter(
                    child: CustomersBentoMetricsBar(
                      isMobile: isMobile,
                      isTablet: isTablet,
                    ),
                  ),

                  // 2. TOOLBAR UNIFICADO PRO DE BÚSQUEDA Y ACCIONES
                  BlocBuilder<CustomersStatsCubit, CustomersStatsState>(
                    builder: (context, statsState) {
                      final totalCount =
                          statsState is CustomersStatsLoaded
                              ? statsState.totalCustomersCount
                              : 0;
                      final debtCount =
                          statsState is CustomersStatsLoaded
                              ? statsState.debtCustomersCount
                              : 0;

                      return BlocBuilder<TopCustomersCubit, TopCustomersState>(
                        builder: (context, topState) {
                          final topCount =
                              topState is TopCustomersLoaded
                                  ? topState.topCustomers.length
                                  : 0;

                          return SliverToBoxAdapter(
                            child: AdminProToolbar(
                              isDesktop: isDesktop,
                              searchController: _searchCtrl,
                              searchFocusNode: _searchFocusNode,
                              searchHint:
                                  'Buscar por nombre, documento o teléfono...',
                              onSearchChanged:
                                  (val) => context
                                      .read<CustomersCubit>()
                                      .search(val.trim()),
                              onClearSearch: () {
                                _searchCtrl.clear();
                                context.read<CustomersCubit>().search('');
                              },
                              filterWidgets: [
                                CustomersSegmentedFilter(
                                  selectedIndex: _tabCtrl.index,
                                  totalCount: totalCount,
                                  debtCount: debtCount,
                                  topCount: topCount,
                                  onTabSelected: (i) {
                                    setState(() => _tabCtrl.animateTo(i));
                                  },
                                ),
                              ],
                              filterGroups: [
                                AdminFilterGroup<int>(
                                  title: 'Clientes',
                                  icon: Icons.people_alt_outlined,
                                  selected: _tabCtrl.index,
                                  defaultValue: 0,
                                  onSelected:
                                      (i) =>
                                          setState(() => _tabCtrl.animateTo(i)),
                                  options: [
                                    AdminFilterOption(
                                      value: 0,
                                      label: 'Todos ($totalCount)',
                                    ),
                                    AdminFilterOption(
                                      value: 1,
                                      label:
                                          debtCount > 0
                                              ? 'Con deuda activa ($debtCount)'
                                              : 'Con deuda activa',
                                      color: AppColors.danger,
                                    ),
                                    AdminFilterOption(
                                      value: 2,
                                      label: '👑 Top VIP ($topCount)',
                                      color: const Color(0xFFB45309),
                                    ),
                                  ],
                                ),
                              ],
                              viewToggleConfig: AdminProViewToggleConfig(
                                isTableView: _isTableView,
                                onToggleTableView:
                                    (val) => setState(() => _isTableView = val),
                              ),
                              onRefresh: () => _reloadAll(forceRefresh: true),
                              refreshTooltip: 'Recargar directorio [R]',
                              trailingActions: [
                                Tooltip(
                                  message: 'Exportar a PDF',
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.picture_as_pdf_outlined,
                                      size: 19,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed:
                                        () =>
                                            context
                                                .read<CustomersCubit>()
                                                .exportPdf(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // 2.b Aviso contextual cuando el filtro "Top VIP" está activo
                  if (_tabCtrl.index == 2)
                    SliverToBoxAdapter(
                      child: TopVipBanner(onOpen: _openTopCustomers),
                    ),

                  // 3. LISTADO / DATA TABLE PRO CON CARGA Y ORDENAMIENTO
                  BlocBuilder<TopCustomersCubit, TopCustomersState>(
                    builder: (context, topState) {
                      final topList =
                          topState is TopCustomersLoaded
                              ? topState.topCustomers
                              : <CustomerEntity>[];

                      return BlocBuilder<CustomersCubit, CustomersState>(
                        builder: (context, state) {
                          return _buildContentSliver(
                            state: state,
                            topList: topList,
                            isMobile: isMobile,
                            isTablet: isTablet,
                            isDesktop: isDesktop,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentSliver({
    required CustomersState state,
    required List<CustomerEntity> topList,
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
  }) {
    if (state is CustomersLoading) {
      return (isMobile || !_isTableView)
          ? const CustomersCardSkeleton()
          : const DesktopTableSkeleton();
    } else if (state is CustomersLoaded) {
      final sortedList = _getMemoizedSortedCustomers(state.customers, topList);

      if (sortedList.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: CustomersEmptyState(
            tabIndex: _tabCtrl.index,
            searchQuery: _searchCtrl.text,
            onCreateCustomer: _openCreateCustomer,
          ),
        );
      }

      // MÓVIL O MODO TARJETAS
      if (isMobile || !_isTableView) {
        if (isMobile) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == sortedList.length) {
                    return _buildLoadMoreFooter(state.hasReachedMax);
                  }
                  final c = sortedList[index];
                  return CustomerListCard(
                    customer: c,
                    onTap: () => _showMobileCustomerActionSheet(c),
                  );
                },
                childCount: sortedList.length + (!state.hasReachedMax ? 1 : 0),
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              ),
            ),
          );
        } else {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 440,
                mainAxisExtent: 180,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final c = sortedList[index];
                  return CustomerListCard(
                    customer: c,
                    onTap: () => _openDesktopCustomerInspector(c),
                  );
                },
                childCount: sortedList.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              ),
            ),
          );
        }
      }

      // DESKTOP & TABLET: Data Table Pro con Sticky Header & Inspector
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: CustomersTableView(
            customers: sortedList,
            topVipList: topList,
            selectedCustomerId: _selectedCustomer?.id,
            initialSortColumn: _sortColumn,
            initialSortAscending: _sortAscending,
            hasReachedMax: state.hasReachedMax,
            onRowTap: _openDesktopCustomerInspector,
            onOpenDetail: _openDetail,
            onEditCustomer: _openEditCustomer,
            onWhatsApp: _launchWhatsApp,
            onContextMenu: _showContextMenu,
            onLoadMore: () => context.read<CustomersCubit>().fetchCustomers(),
          ),
        ),
      );
    } else if (state is CustomersError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                state.message.startsWith('Error al cargar clientes')
                    ? state.message
                    : 'Error al cargar clientes: ${state.message}',
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _reloadAll(forceRefresh: true),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  Widget _buildLoadMoreFooter(bool hasReachedMax) {
    if (hasReachedMax) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Fin del catálogo de clientes',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      );
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
