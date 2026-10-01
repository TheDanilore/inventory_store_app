import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
  final _screenFocusNode = FocusNode();
  final _scrollCtrl = ScrollController();

  // Estado de ordenamiento
  String _sortColumn = 'name'; // 'name', 'orders', 'debt', 'revenue'
  bool _sortAscending = true;

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
          context.read<CustomersCubit>().fetchCustomers(reset: true, showOnlyWithDebt: false);
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

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = (column == 'name');
      }
    });
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

    await showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Cerrar inspector',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final drawerWidth = screenWidth >= 1440 ? 540.0 : 480.0;

        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: drawerWidth,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x28000000),
                    blurRadius: 24,
                    offset: Offset(-4, 0),
                  ),
                ],
              ),
              child: _CustomerSideSheetInspector(
                customer: customer,
                onClose: () => Navigator.of(dialogContext).pop(),
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
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, secAnim, child) {
        final curvedAnim = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curvedAnim),
          child: child,
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _MobileCustomerActionSheet(
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
          value: 'inspector',
          child: Row(
            children: const [
              Icon(Icons.view_sidebar_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Vista rápida (Inspector)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
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
        if (customer.phone != null && customer.phone!.isNotEmpty) ...[
          PopupMenuItem(
            value: 'whatsapp',
            child: Row(
              children: const [
                Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF25D366)),
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
        sorted.sort((a, b) => _sortAscending
            ? a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase())
            : b.fullName.toLowerCase().compareTo(a.fullName.toLowerCase()));
        break;
      case 'orders':
        sorted.sort((a, b) => _sortAscending
            ? a.orderCount.compareTo(b.orderCount)
            : b.orderCount.compareTo(a.orderCount));
        break;
      case 'debt':
        sorted.sort((a, b) => _sortAscending
            ? a.currentDebt.compareTo(b.currentDebt)
            : b.currentDebt.compareTo(a.currentDebt));
        break;
      case 'revenue':
        sorted.sort((a, b) => _sortAscending
            ? a.totalRevenue.compareTo(b.totalRevenue)
            : b.totalRevenue.compareTo(a.totalRevenue));
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
            showBackButton: true,
            settingsActions: const [
              PopupMenuItem(value: 'export', child: Text('Exportar a PDF')),
              PopupMenuItem(value: 'reload', child: Text('Recargar directorio [R]')),
            ],
            onSettingsSelected: (value) {
              if (value == 'export') {
                context.read<CustomersCubit>().exportPdf();
              } else if (value == 'reload') {
                _reloadAll();
              }
            },
            // FAB solo visible en móvil cuando no se está buscando
            floatingActionButton: (isMobile &&
                    _tabCtrl.index == 0 &&
                    _searchCtrl.text.isEmpty)
                ? FloatingActionButton.extended(
                    heroTag: 'add_customer_fab',
                    backgroundColor: AppColors.primary,
                    elevation: 4,
                    icon: const Icon(Icons.person_add_rounded, color: Colors.white),
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
                  // 1. FINTECH BENTO METRIC STRIP (Ultra-compacto y limpio)
                  SliverToBoxAdapter(
                    child: _CustomersBentoMetrics(
                      isMobile: isMobile,
                      isTablet: isTablet,
                    ),
                  ),

                  // 2. TOOLBAR UNIFICADA (Segmented control + Buscador ergonomico + CTA)
                  BlocBuilder<CustomersStatsCubit, CustomersStatsState>(
                    builder: (context, statsState) {
                      final totalCount = statsState is CustomersStatsLoaded
                          ? statsState.totalCustomersCount
                          : 0;
                      final debtCount = statsState is CustomersStatsLoaded
                          ? statsState.debtCustomersCount
                          : 0;

                      return BlocBuilder<TopCustomersCubit, TopCustomersState>(
                        builder: (context, topState) {
                          final topCount = topState is TopCustomersLoaded
                              ? topState.topCustomers.length
                              : 0;

                          if (isMobile) {
                            return SliverMainAxisGroup(
                              slivers: [
                                _buildMobileSearchSliver(),
                                _buildMobileTabsSliver(
                                  totalCount,
                                  debtCount,
                                  topCount,
                                ),
                              ],
                            );
                          }

                          return _buildDesktopToolbarSliver(
                            totalCount: totalCount,
                            debtCount: debtCount,
                            topCount: topCount,
                            isTablet: isTablet,
                          );
                        },
                      );
                    },
                  ),

                  // 3. LISTADO / DATA TABLE PRO CON CARGA Y ORDENAMIENTO
                  BlocBuilder<TopCustomersCubit, TopCustomersState>(
                    builder: (context, topState) {
                      final topList = topState is TopCustomersLoaded
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

  Widget _buildDesktopToolbarSliver({
    required int totalCount,
    required int debtCount,
    required int topCount,
    required bool isTablet,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(opacity: 0.02),
          ),
          child: Row(
            children: [
              // Segmented Control Pro con 3 Pestañas
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
              ),

              const SizedBox(width: 14),

              // Buscador Ergonómico con indicador visual de atajo [/]
              Expanded(
                flex: isTablet ? 3 : 2,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Buscar cliente por nombre, DNI o teléfono...',
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
                      onChanged: (val) =>
                          context.read<CustomersCubit>().search(val.trim()),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),
              if (!isTablet) const Spacer(),

              // Botón Secundario: Exportar PDF
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
                    horizontal: 13,
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
                    const SizedBox(width: 8),
                    _KbdBadge(label: 'N', inverted: true),
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
                    horizontal: 15,
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
          color: isSelected
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
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
                color: isSelected
                    ? (isGold ? AppColors.warningDark : AppColors.primary)
                    : AppColors.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isAlert
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
                    color: isAlert
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

  // ── 2. MOBILE TOOLBAR (Apple HIG Style) ─────────────────────────────────────

  Widget _buildMobileSearchSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        child: Semantics(
          label: 'Buscar cliente',
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, documento o teléfono...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
              ),
              suffixIcon: _buildSearchSuffix(isDesktop: false),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            onChanged: (val) =>
                context.read<CustomersCubit>().search(val.trim()),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTabsSliver(int totalCount, int debtCount, int topCount) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _tabCtrl,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            tabs: [
              Tab(text: 'Todos ($totalCount)'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Deuda'),
                    if (debtCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$debtCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(text: '👑 Top VIP ($topCount)'),
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
              width: 14,
              height: 14,
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
              children: const [
                _KbdBadge(label: '/'),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
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
      return isMobile
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

      // MÓVIL: Tarjetas individuales táctiles (Apple HIG)
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
      }

      // DESKTOP & TABLET: Data Table Pro con Sticky Header & Inspector
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: _DesktopCustomersTablePro(
            customers: sortedList,
            topVipList: topList,
            selectedCustomerId: _selectedCustomer?.id,
            sortColumn: _sortColumn,
            sortAscending: _sortAscending,
            hasReachedMax: state.hasReachedMax,
            onSort: _onSort,
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
        if (state is CustomersStatsLoading) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: List.generate(
                isMobile ? 2 : 4,
                (_) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: AppShimmer(width: double.infinity, height: 74, borderRadius: 14),
                  ),
                ),
              ),
            ),
          );
        }

        final total = state is CustomersStatsLoaded ? state.totalCustomersCount : 0;
        final active = state is CustomersStatsLoaded ? state.activeCustomersCount : 0;
        final revenue = state is CustomersStatsLoaded ? state.totalRevenue : 0.0;
        final debt = state is CustomersStatsLoaded ? state.totalDebt : 0.0;
        final activePct = total > 0 ? ((active / total) * 100).toStringAsFixed(0) : '0';

        final cards = [
          _MetricBentoCard(
            title: 'TOTAL CLIENTES',
            value: '$total',
            subtitle: 'Directorio activo',
            icon: Icons.people_alt_rounded,
            iconColor: AppColors.primary,
            iconBg: AppColors.primaryLight,
          ),
          _MetricBentoCard(
            title: 'CLIENTES ACTIVOS',
            value: '$active',
            subtitle: '$activePct% de cartera',
            icon: Icons.verified_user_rounded,
            iconColor: AppColors.successDark,
            iconBg: AppColors.successLight,
          ),
          _MetricBentoCard(
            title: 'FACTURACIÓN',
            value: _formatCompactMoney(revenue),
            subtitle: 'Ingresos históricos',
            icon: Icons.trending_up_rounded,
            iconColor: AppColors.info,
            iconBg: AppColors.infoLight,
            isMonospace: true,
          ),
          _MetricBentoCard(
            title: 'CUENTAS POR COBRAR',
            value: _formatCompactMoney(debt),
            subtitle: debt > 0 ? 'Saldos pendientes' : 'Al día',
            icon: Icons.account_balance_wallet_rounded,
            iconColor: debt > 0 ? AppColors.danger : AppColors.tealDark,
            iconBg: debt > 0 ? AppColors.dangerLight : AppColors.tealLight,
            isAlert: debt > 0,
            isMonospace: true,
          ),
        ];

        if (isMobile) {
          // En móvil: 2x2 grid compacto
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 8),
                    Expanded(child: cards[1]),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 8),
                    Expanded(child: cards[3]),
                  ],
                ),
              ],
            ),
          );
        }

        // En Desktop y Tablet: Fila horizontal de 4 tarjetas
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
              const SizedBox(width: 10),
              Expanded(child: cards[2]),
              const SizedBox(width: 10),
              Expanded(child: cards[3]),
            ],
          ),
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

class _MetricBentoCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final bool isAlert;
  final bool isMonospace;

  const _MetricBentoCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.isAlert = false,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlert ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border,
        ),
        boxShadow: AppColors.cardShadow(opacity: 0.02),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isAlert ? AppColors.danger : AppColors.textPrimary,
                    fontFeatures: isMonospace
                        ? const [FontFeature.tabularFigures()]
                        : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isAlert ? AppColors.danger : AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── DESKTOP DATA TABLE PRO ───────────────────────────────────────────────────

class _DesktopCustomersTablePro extends StatelessWidget {
  final List<CustomerEntity> customers;
  final List<CustomerEntity> topVipList;
  final String? selectedCustomerId;
  final String sortColumn;
  final bool sortAscending;
  final bool hasReachedMax;
  final ValueChanged<String> onSort;
  final ValueChanged<CustomerEntity> onRowTap;
  final ValueChanged<CustomerEntity> onOpenDetail;
  final ValueChanged<CustomerEntity> onEditCustomer;
  final ValueChanged<String> onWhatsApp;
  final void Function(BuildContext context, Offset pos, CustomerEntity customer)
      onContextMenu;
  final VoidCallback onLoadMore;

  const _DesktopCustomersTablePro({
    required this.customers,
    required this.topVipList,
    required this.selectedCustomerId,
    required this.sortColumn,
    required this.sortAscending,
    required this.hasReachedMax,
    required this.onSort,
    required this.onRowTap,
    required this.onOpenDetail,
    required this.onEditCustomer,
    required this.onWhatsApp,
    required this.onContextMenu,
    required this.onLoadMore,
  });

  int? _getVipRank(String id) {
    final idx = topVipList.indexWhere((c) => c.id == id);
    return idx != -1 ? idx + 1 : null;
  }

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
          // STICKY / FIXED HEADER
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                _buildHeaderCell(
                  label: 'CLIENTE',
                  columnKey: 'name',
                  flex: 3,
                ),
                _buildHeaderCell(
                  label: 'DOCUMENTO',
                  flex: 2,
                ),
                _buildHeaderCell(
                  label: 'TELÉFONO',
                  flex: 2,
                ),
                _buildHeaderCell(
                  label: 'ESTADO',
                  flex: 2,
                ),
                _buildHeaderCell(
                  label: 'COMPRAS',
                  columnKey: 'orders',
                  flex: 2,
                ),
                _buildHeaderCell(
                  label: 'DEUDA ACTUAL',
                  columnKey: 'debt',
                  flex: 2,
                ),
                _buildHeaderCell(
                  label: 'TOTAL FACTURADO',
                  columnKey: 'revenue',
                  flex: 2,
                  align: TextAlign.right,
                ),
                const SizedBox(
                  width: 100,
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

          // FILAS DE CLIENTES
          for (int i = 0; i < customers.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.divider,
              ),
            _DesktopCustomerRowPro(
              key: ValueKey(customers[i].id),
              customer: customers[i],
              vipRank: _getVipRank(customers[i].id),
              isSelected: selectedCustomerId == customers[i].id,
              onTap: () => onRowTap(customers[i]),
              onOpenDetail: () => onOpenDetail(customers[i]),
              onEdit: () => onEditCustomer(customers[i]),
              onWhatsApp: () {
                if (customers[i].phone != null) onWhatsApp(customers[i].phone!);
              },
              onContextMenu: (pos) => onContextMenu(context, pos, customers[i]),
            ),
          ],

          if (!hasReachedMax)
            InkWell(
              onTap: onLoadMore,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                  color: AppColors.background,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Cargar más clientes...',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell({
    required String label,
    String? columnKey,
    required int flex,
    TextAlign align = TextAlign.left,
  }) {
    if (columnKey == null) {
      return Expanded(
        flex: flex,
        child: Text(
          label,
          textAlign: align,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.slate,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    final isCurrent = sortColumn == columnKey;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => onSort(columnKey),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: align == TextAlign.right
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w700,
                  color: isCurrent ? AppColors.primary : AppColors.slate,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isCurrent
                    ? (sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 13,
                color: isCurrent ? AppColors.primary : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopCustomerRowPro extends StatefulWidget {
  final CustomerEntity customer;
  final int? vipRank;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onOpenDetail;
  final VoidCallback onEdit;
  final VoidCallback onWhatsApp;
  final ValueChanged<Offset> onContextMenu;

  const _DesktopCustomerRowPro({
    super.key,
    required this.customer,
    this.vipRank,
    required this.isSelected,
    required this.onTap,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onWhatsApp,
    required this.onContextMenu,
  });

  @override
  State<_DesktopCustomerRowPro> createState() => _DesktopCustomerRowProState();
}

class _DesktopCustomerRowProState extends State<_DesktopCustomerRowPro> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) =>
            widget.onContextMenu(details.globalPosition),
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : (_isHovered
                      ? AppColors.primary.withValues(alpha: 0.035)
                      : Colors.transparent),
            ),
            child: Row(
              children: [
                // Columna 1: Cliente (Avatar + Nombre + Medalla VIP)
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
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    c.fullName,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.vipRank != null) ...[
                                  const SizedBox(width: 6),
                                  _VipRankBadge(rank: widget.vipRank!),
                                ],
                              ],
                            ),
                            if (c.createdAt != null)
                              Text(
                                'Registrado: ${DateFormat('dd/MM/yy', 'es').format(c.createdAt!)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Columna 2: Documento
                Expanded(
                  flex: 2,
                  child: (c.documentNumber != null && c.documentNumber!.isNotEmpty)
                      ? Text(
                          '${c.documentType ?? 'DOC'}: ${c.documentNumber}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : const Text(
                          '—',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                ),

                // Columna 3: Teléfono / Contacto Directo
                Expanded(
                  flex: 2,
                  child: (c.phone != null && c.phone!.isNotEmpty)
                      ? Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              c.phone!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
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

                // Columna 4: Estado
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildStatusBadge(c),
                  ),
                ),

                // Columna 5: Compras
                Expanded(
                  flex: 2,
                  child: c.orderCount > 0
                      ? Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
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
                                    Icons.shopping_bag_outlined,
                                    size: 11,
                                    color: AppColors.info,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${c.orderCount} compras',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.info,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Sin compras',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                ),

                // Columna 6: Deuda Actual
                Expanded(
                  flex: 2,
                  child: c.currentDebt > 0
                      ? Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.danger.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                'S/ ${c.currentDebt.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.danger,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Al día',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.successDark,
                          ),
                        ),
                ),

                // Columna 7: Total Facturado
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
                            color: AppColors.textPrimary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (c.lastOrderAt != null)
                          Text(
                            'Últ: ${DateFormat('dd/MM/yy', 'es').format(c.lastOrderAt!)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Columna 8: Acciones Dinámicas en Hover
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (c.phone != null && c.phone!.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 15,
                            color: Color(0xFF25D366),
                          ),
                          tooltip: 'Enviar WhatsApp',
                          splashRadius: 15,
                          onPressed: widget.onWhatsApp,
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        tooltip: 'Editar cliente',
                        splashRadius: 15,
                        color: AppColors.textSecondary,
                        onPressed: widget.onEdit,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                        tooltip: 'Ficha completa',
                        splashRadius: 15,
                        color: AppColors.primary,
                        onPressed: widget.onOpenDetail,
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
        color: AppColors.successLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: const Text(
        'Activo',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.successDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── VIP RANK BADGE ──────────────────────────────────────────────────────────

class _VipRankBadge extends StatelessWidget {
  final int rank;

  const _VipRankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color border;
    Color text;

    switch (rank) {
      case 1:
        label = '🥇 VIP 1';
        bg = const Color(0xFFFEF3C7);
        border = const Color(0xFFF59E0B);
        text = const Color(0xFFB45309);
        break;
      case 2:
        label = '🥈 VIP 2';
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFF94A3B8);
        text = const Color(0xFF475569);
        break;
      case 3:
        label = '🥉 VIP 3';
        bg = const Color(0xFFFFEDD5);
        border = const Color(0xFFF97316);
        text = const Color(0xFFC2410C);
        break;
      default:
        label = '⭐ $rank°';
        bg = AppColors.primaryLight;
        border = AppColors.primary.withValues(alpha: 0.3);
        text = AppColors.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
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
    final availableCredit = (c.creditLimit - c.currentDebt).clamp(0.0, double.infinity);
    final creditUsageRatio = c.creditLimit > 0
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
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.primary),
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
                                    color: c.isActive
                                        ? AppColors.successLight
                                        : AppColors.slateLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c.isActive ? 'Activo' : 'Inactivo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: c.isActive
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
                        onCopy: c.documentNumber != null
                            ? () => onCopy(c.documentNumber!, 'Documento')
                            : null,
                      ),
                      const Divider(height: 16, color: AppColors.divider),
                      _InspectorDetailRow(
                        icon: Icons.phone_outlined,
                        label: 'Teléfono',
                        value: c.phone ?? 'No registrado',
                        onCopy: c.phone != null
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
                              value: 'S/ ${c.creditLimit.toStringAsFixed(2)}',
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
                              value: 'S/ ${availableCredit.toStringAsFixed(2)}',
                              isSuccess: availableCredit > 0,
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
                      if (c.creditLimit > 0) ...[
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
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 16),
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
          color: isAlert ? AppColors.danger.withValues(alpha: 0.25) : AppColors.border,
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
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
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
            leading: const Icon(Icons.visibility_outlined,
                color: AppColors.primary),
            title: const Text('Ver ficha y pedidos completos'),
            onTap: onOpenDetail,
          ),
          if (c.phone != null && c.phone!.isNotEmpty) ...[
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF25D366)),
              title: const Text('Enviar mensaje de WhatsApp'),
              subtitle: Text(c.phone!),
              onTap: onWhatsApp,
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined,
                  color: AppColors.textPrimary),
              title: const Text('Llamar por teléfono'),
              onTap: onCall,
            ),
          ],
          if (c.documentNumber != null && c.documentNumber!.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.copy_rounded,
                  color: AppColors.textSecondary),
              title: const Text('Copiar número de documento'),
              onTap: onCopyDoc,
            ),
          ListTile(
            leading: const Icon(Icons.edit_outlined,
                color: AppColors.textSecondary),
            title: const Text('Editar información'),
            onTap: onEdit,
          ),
        ],
      ),
    );
  }
}

// ── AVATARS Y UTILIDADES VISUALES ───────────────────────────────────────────

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
  final bool inverted;

  const _KbdBadge({required this.label, this.inverted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: inverted
            ? Colors.white.withValues(alpha: 0.22)
            : AppColors.border,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: inverted ? Colors.white : AppColors.slate,
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
