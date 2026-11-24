import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/bento_metrics/customers_bento_metrics_bar.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/common/top_vip_widgets.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/components/customers_action_sheet_helper.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/components/customers_context_menu.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customer_form_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/sections/customers_content_section.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/sections/customers_toolbar_section.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

const String kTopCustomersRoute = '/customers/top-customers';

/// Pantalla principal de administración del directorio de clientes.
///
/// Garantiza carga Frame 0 (Zero-Shimmer) al navegar de regreso, guards de
/// concurrencia en scroll infinito, ValueNotifiers para evitar rebuilds del
/// Scaffold completo y listeners desvinculados en dispose().
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
  late final ValueNotifier<int> _tabIndexNotifier;
  final ValueNotifier<bool> _isTableViewNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<String?> _selectedCustomerIdNotifier =
      ValueNotifier<String?>(null);

  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _screenFocusNode = FocusNode();
  final _scrollCtrl = ScrollController();

  bool _isSideSheetOpen = false;
  bool _scrollLoadDispatched = false;

  @override
  void initState() {
    super.initState();
    final custState = context.read<CustomersCubit>().state;
    final initialTab =
        custState is CustomersLoaded ? custState.activeTabIndex : 0;
    if (custState is CustomersLoaded && custState.query.isNotEmpty) {
      _searchCtrl.text = custState.query;
    }

    _tabCtrl = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTab.clamp(0, 2),
    );
    _tabIndexNotifier = ValueNotifier<int>(_tabCtrl.index);
    _tabCtrl.addListener(_onTabChanged);
    _scrollCtrl.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _screenFocusNode.requestFocus();
      context.read<CustomersCubit>().ensureLoaded();
      context.read<CustomersStatsCubit>().ensureLoaded();
      context.read<TopCustomersCubit>().ensureLoaded(limit: 5);
    });
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    final idx = _tabCtrl.index;
    _tabIndexNotifier.value = idx;
    final customersCubit = context.read<CustomersCubit>();
    customersCubit.setActiveTab(idx);

    if (idx == 0) {
      customersCubit.fetchCustomers(reset: true, showOnlyWithDebt: false);
    } else if (idx == 1) {
      customersCubit.toggleDebtFilter(true);
    } else if (idx == 2) {
      context.read<TopCustomersCubit>().ensureLoaded(limit: 5);
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _tabCtrl.index == 2) return;
    final position = _scrollCtrl.position;
    if (position.pixels < position.maxScrollExtent - 200) {
      _scrollLoadDispatched = false;
      return;
    }

    if (_scrollLoadDispatched) return;
    final state = context.read<CustomersCubit>().state;
    if (state is CustomersLoaded &&
        !state.hasReachedMax &&
        !state.isLoadingMore) {
      _scrollLoadDispatched = true;
      context.read<CustomersCubit>().fetchCustomers().whenComplete(() {
        _scrollLoadDispatched = false;
      });
    }
  }

  void _selectTab(int index) {
    if (_tabCtrl.index == index) return;
    _tabCtrl.animateTo(index);
  }

  Future<void> _forceReloadAll() async {
    final custCubit = context.read<CustomersCubit>();
    final statsCubit = context.read<CustomersStatsCubit>();
    final topCubit = context.read<TopCustomersCubit>();

    custCubit.invalidateCache();
    await Future.wait([
      custCubit.fetchCustomers(reset: true, forceRefresh: true),
      statsCubit.loadStats(forceRefresh: true),
      topCubit.loadTopCustomers(5, false, null, null, true),
    ]);
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _scrollCtrl.removeListener(_onScroll);
    _tabCtrl.dispose();
    _tabIndexNotifier.dispose();
    _isTableViewNotifier.dispose();
    _selectedCustomerIdNotifier.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

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
      _forceReloadAll();
      AppSnackbar.show(
        context,
        message: 'Directorio de clientes actualizado',
        type: SnackbarType.info,
        duration: const Duration(seconds: 2),
      );
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyD) {
      _selectTab(_tabCtrl.index == 1 ? 0 : 1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyV) {
      _isTableViewNotifier.value = !_isTableViewNotifier.value;
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (_isSideSheetOpen && _selectedCustomerIdNotifier.value != null) {
        Navigator.of(context, rootNavigator: true).maybePop();
        return KeyEventResult.handled;
      }
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        context.read<CustomersCubit>().search('');
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _openTopCustomers() => context.push(kTopCustomersRoute);

  void _openDetail(CustomerEntity customer) {
    context.go('/customers/customer-detail/${customer.id}', extra: customer);
  }

  Future<void> _openCreateCustomer() async {
    final saved = await CustomerFormSheet.show(context);
    if (saved == true && mounted) {
      await _forceReloadAll();
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Cliente registrado exitosamente',
        type: SnackbarType.success,
      );
    }
  }

  Future<void> _openEditCustomer(CustomerEntity customer) async {
    final saved = await CustomerFormSheet.show(context, customer: customer);
    if (saved == true && mounted) {
      await _forceReloadAll();
      if (!mounted) return;
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
    _selectedCustomerIdNotifier.value = customer.id;

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
    if (mounted) _selectedCustomerIdNotifier.value = null;
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
                _forceReloadAll();
              }
            },
            floatingActionButton:
                isMobile
                    ? AnimatedBuilder(
                      animation: Listenable.merge([
                        _tabIndexNotifier,
                        _searchCtrl,
                      ]),
                      builder: (context, _) {
                        if (_tabIndexNotifier.value != 0 ||
                            _searchCtrl.text.isNotEmpty) {
                          return const SizedBox.shrink();
                        }
                        return FloatingActionButton.extended(
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
                        );
                      },
                    )
                    : null,
            body: RefreshIndicator(
              onRefresh: _forceReloadAll,
              child: CustomScrollView(
                controller: _scrollCtrl,
                slivers: [
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
                  SliverToBoxAdapter(
                    child: CustomersBentoMetricsBar(
                      isMobile: isMobile,
                      isTablet: isTablet,
                    ),
                  ),
                  CustomersToolbarSection(
                    isDesktop: isDesktop,
                    searchController: _searchCtrl,
                    searchFocusNode: _searchFocusNode,
                    tabIndexNotifier: _tabIndexNotifier,
                    isTableViewNotifier: _isTableViewNotifier,
                    onTabSelected: _selectTab,
                    onRefresh: _forceReloadAll,
                    onOpenTopCustomers: _openTopCustomers,
                  ),
                  CustomersContentSection(
                    isMobile: isMobile,
                    tabIndexNotifier: _tabIndexNotifier,
                    isTableViewNotifier: _isTableViewNotifier,
                    selectedCustomerIdNotifier: _selectedCustomerIdNotifier,
                    searchController: _searchCtrl,
                    onCreateCustomer: _openCreateCustomer,
                    onReload: _forceReloadAll,
                    onOpenDetail: _openDetail,
                    onEditCustomer: _openEditCustomer,
                    onWhatsApp: _launchWhatsApp,
                    onDesktopInspector: _openDesktopCustomerInspector,
                    onMobileActionSheet: _showMobileCustomerActionSheet,
                    onContextMenu: _showContextMenu,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
