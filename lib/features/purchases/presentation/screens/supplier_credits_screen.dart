import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_state.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';

import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_global_stats_bar.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_credit_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_credits_table.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_account_options_sheet.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_credit_account_sheet.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_payment_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/widgets/adaptive_side_sheet.dart';

class SupplierCreditsScreen extends StatefulWidget {
  const SupplierCreditsScreen({super.key});

  @override
  State<SupplierCreditsScreen> createState() => _SupplierCreditsScreenState();
}

class _SupplierCreditsScreenState extends State<SupplierCreditsScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _screenFocusNode = FocusNode();
  final _scrollController = ScrollController();
  late final TabController _tabCtrl;
  bool _isTableView =
      true; // Desktop: por defecto vista tabla Pro de alta densidad
  SupplierCreditEntity? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
      }
      final cubit = context.read<SupplierCreditsCubit>();
      final currentState = cubit.state;
      if (currentState is SupplierCreditsLoaded) {
        _searchCtrl.text = currentState.searchQuery;
        _tabCtrl.index = currentState.withDebtOnly ? 1 : 0;
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    _scrollController.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  List<SupplierCreditEntity> get _currentAccounts {
    final state = context.read<SupplierCreditsCubit>().state;
    if (state is SupplierCreditsLoaded) return state.accounts;
    if (state is SupplierCreditsLoading) return state.currentAccounts;
    if (state is SupplierCreditsError) return state.currentAccounts;
    return const [];
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    context.read<SupplierCreditsCubit>().setWithDebtOnly(_tabCtrl.index == 1);
  }

  // --- REGLA ESTRICTA DE AISLAMIENTO DE FOCO (FOCUS SHIELD) ---
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

  KeyEventResult _handleKeyShortcuts(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario está escribiendo en un campo de texto, aislar atajos
    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Atajo [/] -> Enfocar buscador
    if (key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    // Atajo [N] -> Nueva Línea de Crédito
    if (key == LogicalKeyboardKey.keyN) {
      _openCreateAccountModal();
      return KeyEventResult.handled;
    }

    // Atajo [R] -> Recargar datos
    if (key == LogicalKeyboardKey.keyR) {
      context.read<SupplierCreditsCubit>().loadAccounts(refresh: true);
      AppSnackbar.show(
        context,
        message: 'Actualizando cuentas de proveedores...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

    // Atajo [1] -> Pestaña Todas
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      _tabCtrl.animateTo(0);
      return KeyEventResult.handled;
    }

    // Atajo [2] -> Pestaña Por Pagar
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      _tabCtrl.animateTo(1);
      return KeyEventResult.handled;
    }

    // Atajo [V] -> Alternar Vista (Cards vs Tabla)
    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    // Atajo [Esc] -> Limpiar búsqueda o desenfocar
    if (key == LogicalKeyboardKey.escape) {
      if (_selectedAccount != null) {
        setState(() => _selectedAccount = null);
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        context.read<SupplierCreditsCubit>().setSearchQuery('');
      }
      _searchFocusNode.unfocus();
      _screenFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    // Flechas arriba y abajo para navegar cuentas y Enter para abrir opciones
    final accounts = _currentAccounts;
    if (accounts.isNotEmpty) {
      final currentIndex =
          _selectedAccount != null
              ? accounts.indexWhere(
                (a) => a.creditId == _selectedAccount!.creditId,
              )
              : -1;

      if (key == LogicalKeyboardKey.arrowDown) {
        final nextIndex = (currentIndex + 1).clamp(0, accounts.length - 1);
        setState(() => _selectedAccount = accounts[nextIndex]);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowUp) {
        final prevIndex = (currentIndex - 1).clamp(0, accounts.length - 1);
        setState(() => _selectedAccount = accounts[prevIndex]);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        final account = _selectedAccount ?? accounts.first;
        _openAccountOptions(context, account);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _openCreateAccountModal() {
    AdaptiveSideSheet.show<void>(
      context: context,
      desktopWidth: 480.0,
      barrierLabel: 'Cerrar crédito',
      builder:
          (ctx, isSlideOver) => SupplierCreditAccountSheet(
            isDialog: isSlideOver,
            onSaved: () {
              context.read<SupplierCreditsCubit>().loadAccounts(refresh: true);
            },
          ),
    );
  }

  void _navigateToHistory(SupplierCreditEntity account) {
    context
        .push(
          '/supplier-credit-movements/${account.creditId}?name=${Uri.encodeComponent(account.supplierName)}&debt=${account.currentDebt}&limit=${account.creditLimit}',
          extra: {
            'supplierName': account.supplierName,
            'currentDebt': account.currentDebt,
            'creditLimit': account.creditLimit,
          },
        )
        .then((_) {
          if (mounted) {
            context.read<SupplierCreditsCubit>().loadAccounts();
          }
        });
  }

  Future<void> _openAccountOptions(
    BuildContext screenContext,
    SupplierCreditEntity account,
  ) async {
    final action = await AdaptiveSideSheet.show<SupplierAccountAction>(
      context: screenContext,
      desktopWidth: 420.0,
      barrierLabel: 'Cerrar opciones',
      builder:
          (ctx, isSlideOver) => SupplierAccountOptionsSheet(
            account: account,
            isDialog: isSlideOver,
          ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case SupplierAccountAction.viewHistory:
        if (!mounted) return;
        _navigateToHistory(account);
        break;

      case SupplierAccountAction.pay:
        if (!mounted) return;
        _openPaymentModal(account);
        break;

      case SupplierAccountAction.edit:
        if (!mounted) return;
        _openEditAccountModal(account);
        break;

      case SupplierAccountAction.toggleStatus:
        if (!mounted) return;
        await context.read<SupplierCreditsCubit>().toggleAccountStatus(account);
        if (mounted) {
          AppSnackbar.show(
            context,
            message:
                account.isActive
                    ? 'Crédito suspendido.'
                    : 'Crédito reactivado.',
            type: SnackbarType.success,
          );
        }
        break;
    }
  }

  void _openPaymentModal(SupplierCreditEntity account) {
    SupplierPaymentSheet.show(
      context,
      account: account,
      onPaymentSaved: () {
        context.read<SupplierCreditsCubit>().loadAccounts(refresh: true);
      },
    );
  }

  void _openEditAccountModal(SupplierCreditEntity account) {
    AdaptiveSideSheet.show<void>(
      context: context,
      desktopWidth: 480.0,
      barrierLabel: 'Cerrar edición de crédito',
      builder:
          (ctx, isSlideOver) => SupplierCreditAccountSheet(
            accountToEdit: account,
            isDialog: isSlideOver,
            onSaved: () {
              context.read<SupplierCreditsCubit>().loadAccounts(refresh: true);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;
    final isDesktopOrTablet = MediaQuery.sizeOf(context).width >= 800;

    return Focus(
      focusNode: _screenFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyShortcuts,
      child: BlocListener<SupplierCreditsCubit, SupplierCreditsState>(
        listener: (context, state) {
          if (state is SupplierCreditsError) {
            AppSnackbar.show(
              context,
              message: state.message,
              type: SnackbarType.error,
            );
            context.read<SupplierCreditsCubit>().clearError();
          }
        },
        child: AdminLayout(
          title: 'Créditos de Proveedores',
          showBackButton: true,
          actions:
              isDesktopOrTablet
                  ? null
                  : [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Actualizar cuentas',
                      onPressed: () {
                        context.read<SupplierCreditsCubit>().loadAccounts(
                          refresh: true,
                        );
                      },
                    ),
                  ],
          // En escritorio ocultamos el FAB flotante; la acción se ubica en el Toolbar superior
          floatingActionButton:
              isDesktop
                  ? null
                  : FloatingActionButton(
                    onPressed: _openCreateAccountModal,
                    backgroundColor: AppColors.primary,
                    tooltip: 'Nueva Línea',
                    child: const Icon(Icons.add_rounded, color: Colors.white),
                  ),
          body: BlocBuilder<SupplierCreditsCubit, SupplierCreditsState>(
            builder: (context, state) {
              final isLoading =
                  state is SupplierCreditsLoading ||
                  state is SupplierCreditsInitial;
              final isError = state is SupplierCreditsError;

              List<SupplierCreditEntity> accounts = [];
              bool withDebtOnly = false;
              int currentPage = 0;
              int totalPages = 1;
              int totalCount = 0;
              Map<String, dynamic> stats = {};
              String? errorMessage;

              if (state is SupplierCreditsLoaded) {
                accounts = state.accounts;
                withDebtOnly = state.withDebtOnly;
                currentPage = state.currentPage;
                totalPages = state.totalPages;
                totalCount = state.totalCount;
                stats = state.stats;
              } else if (state is SupplierCreditsLoading) {
                accounts = state.currentAccounts;
                withDebtOnly = state.withDebtOnly;
                currentPage = state.currentPage;
                totalPages =
                    state.totalCount == 0
                        ? 1
                        : (state.totalCount / SupplierCreditsCubit.pageSize)
                            .ceil();
                totalCount = state.totalCount;
                stats = state.stats;
              } else if (state is SupplierCreditsError) {
                accounts = state.currentAccounts;
                withDebtOnly = state.withDebtOnly;
                currentPage = state.currentPage;
                totalPages =
                    state.totalCount == 0
                        ? 1
                        : (state.totalCount / SupplierCreditsCubit.pageSize)
                            .ceil();
                totalCount = state.totalCount;
                stats = state.stats;
                errorMessage = state.message;
              } else if (state is SupplierCreditSaving) {
                accounts = state.currentAccounts;
                withDebtOnly = state.withDebtOnly;
                currentPage = state.currentPage;
                totalPages =
                    state.totalCount == 0
                        ? 1
                        : (state.totalCount / SupplierCreditsCubit.pageSize)
                            .ceil();
                totalCount = state.totalCount;
                stats = state.stats;
              } else if (state is SupplierCreditSaveSuccess) {
                accounts = state.currentAccounts;
                withDebtOnly = state.withDebtOnly;
                currentPage = state.currentPage;
                totalPages =
                    state.totalCount == 0
                        ? 1
                        : (state.totalCount / SupplierCreditsCubit.pageSize)
                            .ceil();
                totalCount = state.totalCount;
                stats = state.stats;
              } else if (state is SupplierCreditSaveError) {
                accounts = state.currentAccounts;
                withDebtOnly = state.withDebtOnly;
                currentPage = state.currentPage;
                totalPages =
                    state.totalCount == 0
                        ? 1
                        : (state.totalCount / SupplierCreditsCubit.pageSize)
                            .ceil();
                totalCount = state.totalCount;
                stats = state.stats;
                errorMessage = state.message;
              }

              final totalDebt =
                  double.tryParse(stats['totalDebt']?.toString() ?? '0') ?? 0.0;
              final activeAccounts =
                  int.tryParse(stats['activeAccounts']?.toString() ?? '0') ?? 0;
              final suspendedAccounts =
                  int.tryParse(stats['suspendedAccounts']?.toString() ?? '0') ??
                  0;
              final maxedOutAccounts =
                  int.tryParse(stats['maxedOutAccounts']?.toString() ?? '0') ??
                  0;
              final debtCount =
                  int.tryParse(stats['debtCount']?.toString() ?? '0') ?? 0;

              return RefreshIndicator(
                onRefresh:
                    () => context.read<SupplierCreditsCubit>().loadAccounts(
                      refresh: true,
                    ),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // --- 1. KPI BENTO METRIC BAR ---
                    SliverToBoxAdapter(
                      child: SupplierGlobalStatsBar(
                        totalDebt: totalDebt,
                        activeAccounts: activeAccounts,
                        suspendedAccounts: suspendedAccounts,
                        maxedOutAccounts: maxedOutAccounts,
                      ),
                    ),

                    // --- 2. TOOLBAR UNIFICADO DE BÚSQUEDA Y ACCIONES ---
                    SliverToBoxAdapter(
                      child: AdminProToolbar(
                        isDesktop: isDesktop,
                        searchController: _searchCtrl,
                        searchFocusNode: _searchFocusNode,
                        searchHint: 'Buscar por proveedor o RUC...',
                        onSearchChanged:
                            context.read<SupplierCreditsCubit>().setSearchQuery,
                        onClearSearch: () {
                          _searchCtrl.clear();
                          context.read<SupplierCreditsCubit>().setSearchQuery(
                            '',
                          );
                        },
                        filterWidgets: [_buildSegmentedFilter(debtCount)],
                        viewToggleConfig: AdminProViewToggleConfig(
                          isTableView: _isTableView,
                          onToggleTableView:
                              (val) => setState(() => _isTableView = val),
                        ),
                        onRefresh:
                            () => context
                                .read<SupplierCreditsCubit>()
                                .loadAccounts(refresh: true),
                        primaryAction: AdminProToolbarAction(
                          label: 'Nueva Línea',
                          icon: Icons.add_rounded,
                          onPressed: _openCreateAccountModal,
                          keyHint: 'N',
                        ),
                      ),
                    ),

                    // --- 2.5 ENCABEZADO DE NAVEGACIÓN Y CONTADOR ---
                    if (!isLoading && accounts.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                          child: Row(
                            children: [
                              Text(
                                '${accounts.length} ${accounts.length == 1 ? "cuenta" : "cuentas"} en esta página',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isDesktop) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: const Text(
                                    '↑ ↓ navegar',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  'Pág. ${currentPage + 1} / $totalPages',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // --- 3. CONTENIDO: CARDS O TABLA ---
                    if (isLoading && accounts.isEmpty)
                      (isDesktop && _isTableView)
                          ? const SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverToBoxAdapter(
                              child: AppTableShimmer(),
                            ),
                          )
                          : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver:
                                isDesktop
                                    ? SliverGrid(
                                      gridDelegate:
                                          const SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: 420,
                                            mainAxisExtent: 220,
                                            crossAxisSpacing: 16,
                                            mainAxisSpacing: 16,
                                          ),
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) => const AppShimmer(
                                          width: double.infinity,
                                          height: double.infinity,
                                          borderRadius: 16,
                                        ),
                                        childCount: 6,
                                      ),
                                    )
                                    : SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) => const Padding(
                                          padding: EdgeInsets.only(bottom: 12),
                                          child: AppShimmer(
                                            width: double.infinity,
                                            height: 180,
                                            borderRadius: 16,
                                          ),
                                        ),
                                        childCount: 4,
                                      ),
                                    ),
                          )
                    else if (isError &&
                        errorMessage != null &&
                        accounts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppEmptyState(
                          icon: Icons.error_outline_rounded,
                          color: AppColors.danger,
                          title: 'Ocurrió un error',
                          message: errorMessage,
                          action: ElevatedButton.icon(
                            onPressed:
                                () => context
                                    .read<SupplierCreditsCubit>()
                                    .loadAccounts(refresh: true),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                          ),
                        ),
                      )
                    else if (accounts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppEmptyState(
                          icon: Icons.receipt_long_rounded,
                          title:
                              _searchCtrl.text.isNotEmpty
                                  ? 'No se encontraron resultados'
                                  : (withDebtOnly
                                      ? 'No hay créditos con deuda'
                                      : 'No hay líneas de crédito registradas'),
                          message:
                              'Intenta cambiar los filtros o realizar otra búsqueda.',
                        ),
                      )
                    else if (isDesktop && _isTableView)
                      // VISTA DE ALTA DENSIDAD: TABLA PRO
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: SupplierCreditsTable(
                            accounts: accounts,
                            selectedAccount: _selectedAccount,
                            onSelectAccount: (acc) {
                              setState(() => _selectedAccount = acc);
                              _openAccountOptions(context, acc);
                            },
                            onPay: _openPaymentModal,
                            onViewHistory: _navigateToHistory,
                          ),
                        ),
                      )
                    else
                      // VISTA VISUAL: TARJETAS DINÁMICAS
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver:
                            isDesktop
                                ? SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 420,
                                        mainAxisExtent: 220,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final account = accounts[index];
                                    return SupplierCreditCard(
                                      account: account,
                                      isSelected:
                                          _selectedAccount?.creditId ==
                                          account.creditId,
                                      onTap: () {
                                        setState(
                                          () => _selectedAccount = account,
                                        );
                                        _openAccountOptions(context, account);
                                      },
                                      onPay: () => _openPaymentModal(account),
                                      onViewHistory:
                                          () => _navigateToHistory(account),
                                    );
                                  }, childCount: accounts.length),
                                )
                                : SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final account = accounts[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: SupplierCreditCard(
                                        account: account,
                                        isSelected:
                                            _selectedAccount?.creditId ==
                                            account.creditId,
                                        onTap: () {
                                          setState(
                                            () => _selectedAccount = account,
                                          );
                                          _openAccountOptions(context, account);
                                        },
                                        onPay: () => _openPaymentModal(account),
                                        onViewHistory:
                                            () => _navigateToHistory(account),
                                      ),
                                    );
                                  }, childCount: accounts.length),
                                ),
                      ),

                    // --- 4. PAGINACIÓN FLUIDA AL PIE DEL SCROLL ---
                    _buildPaginationSliver(
                      currentPage: currentPage,
                      totalPages: totalPages,
                      totalItems: totalCount,
                      isLoading: isLoading,
                      context: context,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationSliver({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required bool isLoading,
    required BuildContext context,
  }) {
    if (totalPages <= 1 || isLoading || totalItems == 0) {
      return const SliverToBoxAdapter(child: SizedBox(height: 24));
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(opacity: 0.03),
          ),
          child: AdminPageBlocks(
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: (page) {
              context.read<SupplierCreditsCubit>().setPage(page);
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            totalItems: totalItems,
            itemName: 'líneas de crédito',
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedFilter(int debtCount) {
    return SizedBox(
      height: 40,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterTabButton(
              title: 'Todas',
              shortcutHint: '1',
              isSelected: _tabCtrl.index == 0,
              onTap: () => _tabCtrl.animateTo(0),
            ),
            const SizedBox(width: 4),
            _FilterTabButton(
              title: 'Por Pagar',
              count: debtCount,
              shortcutHint: '2',
              isSelected: _tabCtrl.index == 1,
              onTap: () => _tabCtrl.animateTo(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTabButton extends StatelessWidget {
  final String title;
  final int? count;
  final String shortcutHint;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTabButton({
    required this.title,
    this.count,
    required this.shortcutHint,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
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
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.danger : AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                shortcutHint,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
