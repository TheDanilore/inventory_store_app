import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
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
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/inspector/customer_side_sheet_inspector.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/inspector/mobile_customer_action_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/skeletons/customers_skeletons.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ruta de la pantalla "Top Clientes" (ranking + ruleta de sorteo).
const String kTopCustomersRoute = '/top-customers';

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

  // Estado de inspector lateral (Desktop / Tablet)
  CustomerEntity? _selectedCustomer;
  bool _isSideSheetOpen = false;

  @override
  void initState() {
    super.initState();
    // 3 Pestañas: 0 = Todos, 1 = Con deuda, 2 = Top VIP
    _tabCtrl = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
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
          context.read<TopCustomersCubit>().loadTopCustomers();
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

  /// Carga o revalida datos. Si ya hay datos en memoria (caché), no parpadea ni emite Shimmer.
  void _reloadAll({bool silent = false}) {
    final custCubit = context.read<CustomersCubit>();
    final isAlreadyLoaded =
        custCubit.state is CustomersLoaded &&
        (custCubit.state as CustomersLoaded).hasCustomers;

    custCubit.fetchCustomers(reset: true, silent: silent || isAlreadyLoaded);
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
    final context = primaryFocus.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null ||
        context.findAncestorStateOfType<EditableTextState>() != null;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario escribe en un campo de texto, aislamos los atajos de tecla única
    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Atajo [/] -> Enfocar buscador con selección total
    if (key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    // Atajo [N] -> Nuevo Cliente
    if (key == LogicalKeyboardKey.keyN) {
      _openCreateCustomer();
      return KeyEventResult.handled;
    }

    // Atajo [R] -> Recargar directorio y métricas
    if (key == LogicalKeyboardKey.keyR) {
      _reloadAll();
      AppSnackbar.show(
        context,
        message: 'Directorio de clientes actualizado',
        type: SnackbarType.info,
        duration: const Duration(seconds: 2),
      );
      return KeyEventResult.handled;
    }

    // Atajo [D] -> Alternar filtro de deudores
    if (key == LogicalKeyboardKey.keyD) {
      final nextIdx = _tabCtrl.index == 1 ? 0 : 1;
      _tabCtrl.animateTo(nextIdx);
      return KeyEventResult.handled;
    }

    // Atajo [V] -> Alternar Vista (Tabla vs Tarjetas)
    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    // Atajo [Escape] -> Limpiar búsqueda o cerrar inspector
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
      customersCubit.fetchCustomers(reset: true);
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
      customersCubit.fetchCustomers(reset: true);
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
    } else {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo iniciar WhatsApp',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _launchPhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    final url = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo iniciar llamada',
          type: SnackbarType.error,
        );
      }
    }
  }

  // Inspector Lateral Pro (Stripe / Linear Style)
  Future<void> _openDesktopCustomerInspector(CustomerEntity customer) async {
    if (!mounted || _isSideSheetOpen) return;
    _isSideSheetOpen = true;
    setState(() => _selectedCustomer = customer);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = screenWidth >= 1440 ? 560.0 : 500.0;

    await AdaptiveDetailSheet.show(
      context,
      desktopWidth: drawerWidth,
      barrierLabel: 'Cerrar inspector',
      builder: (dialogContext) {
        return CustomerSideSheetInspector(
          customer: customer,
          onClose: () => Navigator.of(dialogContext).maybePop(),
          onEdit: () {
            Navigator.of(dialogContext).pop();
            _openEditCustomer(customer);
          },
          onOpenFullDetail: () {
            Navigator.of(dialogContext).pop();
            _openDetail(customer);
          },
          onWhatsApp: (p) => _launchWhatsApp(p),
          onCall: (p) => _launchPhoneCall(p),
          onCopy: _copyToClipboard,
        );
      },
    );
    _isSideSheetOpen = false;
    if (mounted) setState(() => _selectedCustomer = null);
  }

  // Modal Inferior Táctil (Apple HIG Style)
  void _showMobileCustomerActionSheet(CustomerEntity customer) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (sheetCtx) => MobileCustomerActionSheet(
            customer: customer,
            onOpenDetail: () {
              Navigator.of(sheetCtx).pop();
              _openDetail(customer);
            },
            onEdit: () {
              Navigator.of(sheetCtx).pop();
              _openEditCustomer(customer);
            },
            onWhatsApp: () {
              Navigator.of(sheetCtx).pop();
              if (customer.phone != null) _launchWhatsApp(customer.phone!);
            },
            onCall: () {
              Navigator.of(sheetCtx).pop();
              if (customer.phone != null) _launchPhoneCall(customer.phone!);
            },
            onCopyDoc: () {
              Navigator.of(sheetCtx).pop();
              if (customer.documentNumber != null) {
                _copyToClipboard(
                  customer.documentNumber!,
                  customer.documentType ?? 'Documento',
                );
              }
            },
          ),
    );
  }

  void _showContextMenu(
    BuildContext context,
    Offset position,
    CustomerEntity customer,
  ) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
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
        const PopupMenuItem(
          value: 'inspector',
          child: Row(
            children: [
              Icon(
                Icons.view_sidebar_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Text('Vista rápida (Inspector)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'detail',
          child: Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Text('Ver ficha completa', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: AppColors.slate),
              SizedBox(width: 10),
              Text('Editar datos', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        if (customer.phone != null && customer.phone!.isNotEmpty) ...[
          const PopupMenuItem(
            value: 'whatsapp',
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: Color(0xFF25D366),
                ),
                SizedBox(width: 10),
                Text('Enviar WhatsApp', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'copy_phone',
            child: Row(
              children: [
                Icon(Icons.copy_rounded, size: 18, color: AppColors.slate),
                SizedBox(width: 10),
                Text('Copiar teléfono', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
        if (customer.documentNumber != null &&
            customer.documentNumber!.isNotEmpty)
          const PopupMenuItem(
            value: 'copy_doc',
            child: Row(
              children: [
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
        case 'inspector':
          _openDesktopCustomerInspector(customer);
          break;
        case 'detail':
          _openDetail(customer);
          break;
        case 'edit':
          _openEditCustomer(customer);
          break;
        case 'whatsapp':
          if (customer.phone != null) _launchWhatsApp(customer.phone!);
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

  List<CustomerEntity> _sortCustomers(
    List<CustomerEntity> list,
    List<CustomerEntity> topVipList,
  ) {
    // Si estamos en la pestaña 2 (Top VIP), mostramos la lista VIP directamente
    if (_tabCtrl.index == 2) {
      if (topVipList.isNotEmpty) {
        return topVipList;
      }
      final sortedVip = List<CustomerEntity>.from(list);
      sortedVip.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
      return sortedVip;
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
    return sorted;
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
                _reloadAll();
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
                      ),
                      label: const Text(
                        'Nuevo cliente',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: _openCreateCustomer,
                    )
                    : null,
            body: RefreshIndicator(
              onRefresh: () async => _reloadAll(),
              child: CustomScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
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
                          onPressed: () => _openCreateCustomer(),
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
                                _buildSegmentedFilter(
                                  totalCount: totalCount,
                                  debtCount: debtCount,
                                  topCount: topCount,
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
                              onRefresh: _reloadAll,
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

  Widget _buildSegmentedFilter({
    required int totalCount,
    required int debtCount,
    required int topCount,
  }) {
    return Container(
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
            title: 'Todos',
            count: totalCount,
            isSelected: _tabCtrl.index == 0,
            onTap: () => setState(() => _tabCtrl.animateTo(0)),
          ),
          const SizedBox(width: 4),
          _buildSegmentButton(
            title: 'Con deuda activa',
            count: debtCount,
            isSelected: _tabCtrl.index == 1,
            isAlert: debtCount > 0,
            onTap: () => setState(() => _tabCtrl.animateTo(1)),
          ),
          const SizedBox(width: 4),
          _buildSegmentButton(
            title: '👑 Top VIP',
            count: topCount,
            isSelected: _tabCtrl.index == 2,
            isGold: true,
            onTap: () => setState(() => _tabCtrl.animateTo(2)),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    bool isAlert = false,
    bool isGold = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.surface
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
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
                color:
                    isSelected
                        ? (isGold ? AppColors.warningDark : AppColors.primary)
                        : AppColors.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color:
                      isAlert
                          ? AppColors.error
                          : (isGold
                              ? AppColors.warning.withValues(alpha: 0.15)
                              : (isSelected
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : AppColors.border)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color:
                        isAlert
                            ? Colors.white
                            : (isGold
                                ? AppColors.warningDark
                                : (isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary)),
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
      final sortedList = _sortCustomers(state.customers, topList);

      if (sortedList.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(state),
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
              delegate: SliverChildBuilderDelegate((context, index) {
                final c = sortedList[index];
                return CustomerListCard(
                  customer: c,
                  onTap: () => _openDesktopCustomerInspector(c),
                );
              }, childCount: sortedList.length),
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
            onRowTap: (c) => _openDesktopCustomerInspector(c),
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
                onPressed: _reloadAll,
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

  Widget _buildEmptyState(CustomersLoaded state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 52,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _tabCtrl.index == 1
                ? 'No hay clientes con deuda activa'
                : (_tabCtrl.index == 2
                    ? 'Aún no hay compras registradas para el ranking VIP'
                    : 'No se encontraron clientes registrados'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _tabCtrl.index == 1
                ? 'Todos los clientes se encuentran al día con sus saldos.'
                : 'Crea un nuevo registro para comenzar a procesar ventas.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          if (_tabCtrl.index == 0 && _searchCtrl.text.isEmpty)
            FilledButton.icon(
              onPressed: _openCreateCustomer,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Registrar nuevo cliente'),
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
