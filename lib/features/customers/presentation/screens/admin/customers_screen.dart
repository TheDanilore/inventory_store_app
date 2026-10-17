import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customer_form_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customer_list_card.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customers_table_view.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/widgets/admin_kpi_metrics_bar.dart';
import 'package:inventory_store_app/core/widgets/adaptive_side_sheet.dart';

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
        _reloadAll();
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

  void _reloadAll() {
    context.read<CustomersCubit>().fetchCustomers(reset: true);
    context.read<CustomersStatsCubit>().loadStats();
    context.read<TopCustomersCubit>().loadTopCustomers();
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

    await AdaptiveSideSheet.show(
      context: context,
      desktopWidth: drawerWidth,
      barrierLabel: 'Cerrar inspector',
      builder: (dialogContext, isSlideOver) {
        return _CustomerSideSheetInspector(
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
          (sheetCtx) => _MobileCustomerActionSheet(
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
        PopupMenuItem(
          value: 'inspector',
          child: Row(
            children: const [
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
        PopupMenuItem(
          value: 'detail',
          child: Row(
            children: const [
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
        if (customer.phone != null && customer.phone!.isNotEmpty) ...[
          PopupMenuItem(
            value: 'whatsapp',
            child: Row(
              children: const [
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
        ],
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
            // FAB solo visible en móvil cuando no se está buscando
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
                  // ── 0. CABECERA EJECUTIVA STRIPE / LINEAR (ARRIBA DE MÉTRICAS) ──
                  SliverToBoxAdapter(
                    child: AdminPageHeader(
                      title: 'Directorio de Clientes',
                      subtitle:
                          'Gestiona tus clientes, su información y datos de contacto',
                      isDesktop: isDesktop,
                      actions: [
                        AdminHeaderButton.primary(
                          label: 'Nuevo Cliente',
                          icon: Icons.person_add_rounded,
                          tooltip: 'Nuevo cliente (Atajo: N)',
                          onPressed: () => _openCreateCustomer(),
                        ),
                      ],
                    ),
                  ),

                  // 1. FINTECH BENTO METRIC STRIP (Ultra-compacto y limpio)
                  SliverToBoxAdapter(
                    child: _CustomersBentoMetrics(
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
                              // Desktop/tablet: control segmentado existente.
                              filterWidgets: [
                                _buildSegmentedFilter(
                                  totalCount: totalCount,
                                  debtCount: debtCount,
                                  topCount: topCount,
                                ),
                              ],
                              // Móvil: el mismo filtro como chips en el sheet (estado en vivo).
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

  // ── 1. FINTECH BENTO METRIC STRIP COMPONENT ─────────────────────────────────

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

  // ── 3. LIST / TABLE BUILDER ─────────────────────────────────────────────────

  Widget _buildContentSliver({
    required CustomersState state,
    required List<CustomerEntity> topList,
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
  }) {
    if (state is CustomersLoading) {
      return (isMobile || !_isTableView)
          ? const _CustomersSkeleton()
          : const _DesktopTableSkeleton();
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
                'Error al cargar clientes: ${state.message}',
                style: const TextStyle(color: AppColors.textSecondary),
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

// ── BENTO METRICS HEADER COMPONENT (Fintech Pro Look) ─────────────────────────

class _CustomersBentoMetrics extends StatelessWidget {
  final bool isMobile;
  final bool isTablet;

  const _CustomersBentoMetrics({
    required this.isMobile,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomersStatsCubit, CustomersStatsState>(
      builder: (context, state) {
        final isLoading = state is CustomersStatsLoading;
        final total =
            state is CustomersStatsLoaded ? state.totalCustomersCount : 0;
        final active =
            state is CustomersStatsLoaded ? state.activeCustomersCount : 0;
        final revenue =
            state is CustomersStatsLoaded ? state.totalRevenue : 0.0;
        final debt = state is CustomersStatsLoaded ? state.totalDebt : 0.0;
        final activePct =
            total > 0 ? ((active / total) * 100).toStringAsFixed(0) : '0';

        return AdminKpiMetricsBar(
          isLoading: isLoading,
          isDesktop: !isMobile,
          isMobileGrid: true,
          padding: EdgeInsets.fromLTRB(16, isMobile ? 10 : 12, 16, 6),
          items: [
            AdminKpiItem(
              title: 'TOTAL CLIENTES',
              value: '$total',
              subtitle: 'Directorio activo',
              icon: Icons.people_alt_rounded,
              accentColor: AppColors.primary,
              gradientColors: const [Colors.white, Color(0xFFF8FAFC)],
              iconGradient: const [Color(0xFF334155), Color(0xFF1E293B)],
              borderColor: const Color(0xFFE2E8F0),
              glowColor: const Color(0x1F0F172A),
            ),
            AdminKpiItem(
              title: 'CLIENTES ACTIVOS',
              value: '$active',
              subtitle: '$activePct% de cartera',
              icon: Icons.verified_user_rounded,
              accentColor: AppColors.successDark,
              gradientColors: const [Colors.white, Color(0xFFECFDF5)],
              iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
              borderColor: const Color(0xFFA7F3D0),
              glowColor: const Color(0x2E10B981),
            ),
            AdminKpiItem(
              title: 'FACTURACIÓN',
              value: _formatCompactMoney(revenue),
              subtitle: 'Ingresos históricos',
              icon: Icons.trending_up_rounded,
              accentColor: AppColors.info,
              gradientColors: const [Colors.white, Color(0xFFF0F9FF)],
              iconGradient: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
              borderColor: const Color(0xFFBAE6FD),
              glowColor: const Color(0x2E0EA5E9),
            ),
            AdminKpiItem(
              title: 'CUENTAS POR COBRAR',
              value: _formatCompactMoney(debt),
              subtitle: debt > 0 ? 'Saldos pendientes' : 'Al día',
              icon: Icons.account_balance_wallet_rounded,
              accentColor: debt > 0 ? AppColors.danger : AppColors.tealDark,
              gradientColors: [
                Colors.white,
                debt > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDFA),
              ],
              iconGradient:
                  debt > 0
                      ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
                      : const [Color(0xFF0D9488), Color(0xFF0F766E)],
              borderColor:
                  debt > 0 ? const Color(0xFFFECACA) : const Color(0xFF99F6E4),
              glowColor:
                  debt > 0 ? const Color(0x2EEF4444) : const Color(0x2E0D9488),
              valueColor: debt > 0 ? AppColors.danger : AppColors.textPrimary,
              isAlert: debt > 0,
            ),
          ],
        );
      },
    );
  }

  static String _formatCompactMoney(double value) {
    if (value >= 1000000) {
      return 'S/ ${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return 'S/ ${(value / 1000).toStringAsFixed(1)}K';
    }
    return 'S/ ${value.toStringAsFixed(0)}';
  }
}

// ── CUSTOMER SIDE SHEET INSPECTOR (Fintech / Stripe Pro Tool) ────────────────

class _CustomerSideSheetInspector extends StatelessWidget {
  final CustomerEntity customer;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onOpenFullDetail;
  final ValueChanged<String> onWhatsApp;
  final ValueChanged<String> onCall;
  final void Function(String text, String label) onCopy;

  const _CustomerSideSheetInspector({
    required this.customer,
    required this.onClose,
    required this.onEdit,
    required this.onOpenFullDetail,
    required this.onWhatsApp,
    required this.onCall,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final isUnlimited = c.creditLimit <= 0;
    final availableCredit =
        isUnlimited
            ? double.infinity
            : (c.creditLimit - c.currentDebt).clamp(0.0, double.infinity);
    final creditUsageRatio =
        (!isUnlimited && c.creditLimit > 0)
            ? (c.currentDebt / c.creditLimit).clamp(0.0, 1.0)
            : 0.0;

    return Column(
      children: [
        // Top Inspector Bar
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Ficha Rápida del Cliente',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              const _KbdBadge(label: 'Esc'),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                splashRadius: 18,
                onPressed: onClose,
              ),
            ],
          ),
        ),

        // Inspector Content Scrollable
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Profile Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.cardShadow(opacity: 0.02),
                  ),
                  child: Row(
                    children: [
                      _CustomerAvatarLarge(customer: c),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.fullName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        c.isActive
                                            ? AppColors.successLight
                                            : AppColors.slateLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c.isActive ? 'Activo' : 'Inactivo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          c.isActive
                                              ? AppColors.successDark
                                              : AppColors.slate,
                                    ),
                                  ),
                                ),
                                if (c.currentDebt > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.dangerLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Con Saldo Deudor',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Contact Details Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _InspectorDetailRow(
                        icon: Icons.badge_outlined,
                        label: c.documentType ?? 'Documento',
                        value: c.documentNumber ?? 'No registrado',
                        onCopy:
                            c.documentNumber != null
                                ? () => onCopy(c.documentNumber!, 'Documento')
                                : null,
                      ),
                      const Divider(height: 16, color: AppColors.divider),
                      _InspectorDetailRow(
                        icon: Icons.phone_outlined,
                        label: 'Teléfono',
                        value: c.phone ?? 'No registrado',
                        onCopy:
                            c.phone != null
                                ? () => onCopy(c.phone!, 'Teléfono')
                                : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Financial Overview Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ESTADO DE CUENTA Y CRÉDITO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _BalanceMiniCard(
                              title: 'Deuda Actual',
                              value: 'S/ ${c.currentDebt.toStringAsFixed(2)}',
                              isAlert: c.currentDebt > 0,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _BalanceMiniCard(
                              title: 'Límite Crédito',
                              value:
                                  isUnlimited
                                      ? 'Sin límite (∞)'
                                      : 'S/ ${c.creditLimit.toStringAsFixed(2)}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _BalanceMiniCard(
                              title: 'Crédito Disponible',
                              value:
                                  isUnlimited
                                      ? 'Ilimitado'
                                      : 'S/ ${availableCredit.toStringAsFixed(2)}',
                              isSuccess: isUnlimited || availableCredit > 0,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _BalanceMiniCard(
                              title: 'Facturación Total',
                              value: 'S/ ${c.totalRevenue.toStringAsFixed(2)}',
                            ),
                          ),
                        ],
                      ),
                      if (!isUnlimited && c.creditLimit > 0) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: creditUsageRatio,
                            minHeight: 6,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              creditUsageRatio > 0.85
                                  ? AppColors.danger
                                  : (creditUsageRatio > 0.5
                                      ? AppColors.warning
                                      : AppColors.teal),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(creditUsageRatio * 100).toStringAsFixed(0)}% del límite de crédito consumido',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Direct Contact Action Buttons
                if (c.phone != null && c.phone!.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                          ),
                          label: const Text('WhatsApp'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => onWhatsApp(c.phone!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.phone_outlined, size: 16),
                          label: const Text('Llamar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => onCall(c.phone!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Buttons Full Detail & Edit
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Editar datos'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: onEdit,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('Ficha completa'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: onOpenFullDetail,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final bool isAlert;
  final bool isSuccess;

  const _BalanceMiniCard({
    required this.title,
    required this.value,
    this.isAlert = false,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    Color valColor = AppColors.textPrimary;
    if (isAlert) valColor = AppColors.danger;
    if (isSuccess) valColor = AppColors.successDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              isAlert
                  ? AppColors.danger.withValues(alpha: 0.25)
                  : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: valColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _InspectorDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (onCopy != null)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            tooltip: 'Copiar',
            splashRadius: 16,
            color: AppColors.textSecondary,
            onPressed: onCopy,
          ),
      ],
    );
  }
}

// ── MOBILE BOTTOM SHEET (Apple HIG Style) ───────────────────────────────────

class _MobileCustomerActionSheet extends StatelessWidget {
  final CustomerEntity customer;
  final VoidCallback onOpenDetail;
  final VoidCallback onEdit;
  final VoidCallback onWhatsApp;
  final VoidCallback onCall;
  final VoidCallback onCopyDoc;

  const _MobileCustomerActionSheet({
    required this.customer,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onWhatsApp,
    required this.onCall,
    required this.onCopyDoc,
  });

  @override
  Widget build(BuildContext context) {
    final c = customer;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              _CustomerAvatarLarge(customer: c),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.fullName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${c.documentType ?? 'DOC'}: ${c.documentNumber ?? 'Sin documento'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),

          // Acciones con target táctil mínimo de 48dp
          ListTile(
            leading: const Icon(
              Icons.visibility_outlined,
              color: AppColors.primary,
            ),
            title: const Text('Ver ficha y pedidos completos'),
            onTap: onOpenDetail,
          ),
          if (c.phone != null && c.phone!.isNotEmpty) ...[
            ListTile(
              leading: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF25D366),
              ),
              title: const Text('Enviar mensaje de WhatsApp'),
              subtitle: Text(c.phone!),
              onTap: onWhatsApp,
            ),
            ListTile(
              leading: const Icon(
                Icons.phone_outlined,
                color: AppColors.textPrimary,
              ),
              title: const Text('Llamar por teléfono'),
              onTap: onCall,
            ),
          ],
          if (c.documentNumber != null && c.documentNumber!.isNotEmpty)
            ListTile(
              leading: const Icon(
                Icons.copy_rounded,
                color: AppColors.textSecondary,
              ),
              title: const Text('Copiar número de documento'),
              onTap: onCopyDoc,
            ),
          ListTile(
            leading: const Icon(
              Icons.edit_outlined,
              color: AppColors.textSecondary,
            ),
            title: const Text('Editar información'),
            onTap: onEdit,
          ),
        ],
      ),
    );
  }
}

// ── AVATARS Y UTILIDADES VISUALES ───────────────────────────────────────────

class _CustomerAvatarLarge extends StatelessWidget {
  final CustomerEntity customer;

  const _CustomerAvatarLarge({required this.customer});

  @override
  Widget build(BuildContext context) {
    if (customer.avatarUrl != null && customer.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.background,
        backgroundImage: CachedNetworkImageProvider(customer.avatarUrl!),
      );
    }

    final color =
        Colors.primaries[customer.fullName.length % Colors.primaries.length];

    return CircleAvatar(
      radius: 26,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        customer.fullName.isNotEmpty ? customer.fullName[0].toUpperCase() : '?',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}

class _KbdBadge extends StatelessWidget {
  final String label;

  const _KbdBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.slate,
        ),
      ),
    );
  }
}

// ── SKELETONS ADAPTATIVOS DE CARGA ──────────────────────────────────────────

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
                7,
                (index) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.divider),
                    ),
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
