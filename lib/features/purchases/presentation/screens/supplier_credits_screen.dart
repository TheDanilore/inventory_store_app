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

class SupplierCreditsScreen extends StatefulWidget {
  const SupplierCreditsScreen({super.key});

  @override
  State<SupplierCreditsScreen> createState() => _SupplierCreditsScreenState();
}

class _SupplierCreditsScreenState extends State<SupplierCreditsScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  late final TabController _tabCtrl;
  bool _isTableView = true; // Desktop: por defecto vista tabla Pro de alta densidad

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    context.read<SupplierCreditsCubit>().setWithDebtOnly(_tabCtrl.index == 1);
  }

  // --- REGLA ESTRICTA DE AISLAMIENTO DE FOCO (FOCUS SHIELD) ---
  bool get _isInputFieldFocused {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    return primaryFocus.context?.widget is EditableText;
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
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        context.read<SupplierCreditsCubit>().setSearchQuery('');
      }
      _searchFocusNode.unfocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _openCreateAccountModal() {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final modal = SupplierCreditAccountSheet(
      isDialog: isDesktop,
      onSaved: () {
        context.read<SupplierCreditsCubit>().loadAccounts(refresh: true);
      },
    );

    if (isDesktop) {
      showDialog(context: context, builder: (_) => modal);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => modal,
      );
    }
  }

  void _navigateToHistory(SupplierCreditEntity account) {
    context.push(
      '/supplier-credit-movements/${account.creditId}?name=${Uri.encodeComponent(account.supplierName)}&debt=${account.currentDebt}&limit=${account.creditLimit}',
      extra: {
        'supplierName': account.supplierName,
        'currentDebt': account.currentDebt,
        'creditLimit': account.creditLimit,
      },
    ).then((_) {
      if (mounted) {
        context.read<SupplierCreditsCubit>().loadAccounts();
      }
    });
  }

  Future<void> _openAccountOptions(
    BuildContext screenContext,
    SupplierCreditEntity account,
  ) async {
    final isDesktop = MediaQuery.of(screenContext).size.width >= 800;
    final modal = SupplierAccountOptionsSheet(
      account: account,
      isDialog: isDesktop,
    );

    final action = await (isDesktop
        ? showDialog<SupplierAccountAction>(
          context: screenContext,
          builder: (_) => modal,
        )
        : showModalBottomSheet<SupplierAccountAction>(
          context: screenContext,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => modal,
        ));

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
                account.isActive ? 'Crédito suspendido.' : 'Crédito reactivado.',
            type: SnackbarType.success,
          );
        }
        break;
    }
  }

  void _openPaymentModal(SupplierCreditEntity account) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final cubit = context.read<SupplierCreditsCubit>();
    final modal = BlocProvider.value(
      value: cubit,
      child: SupplierPaymentSheet(
        account: account,
        isDialog: isDesktop,
        onPaymentSaved: () {
          cubit.loadAccounts(refresh: true);
        },
      ),
    );

    if (isDesktop) {
      showDialog(context: context, builder: (_) => modal);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => modal,
      );
    }
  }

  void _openEditAccountModal(SupplierCreditEntity account) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final modal = SupplierCreditAccountSheet(
      accountToEdit: account,
      isDialog: isDesktop,
      onSaved: () {
        context.read<SupplierCreditsCubit>().loadAccounts(refresh: true);
      },
    );

    if (isDesktop) {
      showDialog(context: context, builder: (_) => modal);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => modal,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;

    return Focus(
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
                  int.tryParse(stats['maxedOutAccounts']?.toString() ?? '0') ?? 0;
              final debtCount =
                  int.tryParse(stats['debtCount']?.toString() ?? '0') ?? 0;

              return Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh:
                          () => context.read<SupplierCreditsCubit>().loadAccounts(
                            refresh: true,
                          ),
                      child: CustomScrollView(
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
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x050F172A),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child:
                              isDesktop
                                  ? Row(
                                    children: [
                                      // Buscador con badge de atajo [/]
                                      Expanded(
                                        flex: 5,
                                        child: _buildSearchField(),
                                      ),
                                      const SizedBox(width: 12),

                                      // Segmented Control de Filtro
                                      _buildSegmentedFilter(debtCount),
                                      const SizedBox(width: 12),

                                      // Toggle Vista Cards vs Tabla
                                      _buildViewModeToggle(),
                                      const SizedBox(width: 8),

                                      // Botón Refrescar [R]
                                      IconButton(
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 20,
                                        ),
                                        color: AppColors.textSecondary,
                                        tooltip: 'Refrescar créditos [R]',
                                        onPressed:
                                            () => context
                                                .read<SupplierCreditsCubit>()
                                                .loadAccounts(refresh: true),
                                      ),
                                      const SizedBox(width: 8),

                                      // Botón Primario: Nueva Línea [N]
                                      SizedBox(
                                        height: 40,
                                        child: FilledButton.icon(
                                          onPressed: _openCreateAccountModal,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.add_rounded,
                                            size: 18,
                                          ),
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'Nueva Línea',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              _buildButtonKeyHint('N'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                  : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildSearchField(),
                                      const SizedBox(height: 10),
                                      _buildSegmentedFilter(debtCount),
                                    ],
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
                              onSelectAccount:
                                  (acc) => _openAccountOptions(context, acc),
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
                                        onTap:
                                            () => _openAccountOptions(
                                              context,
                                              account,
                                            ),
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
                                          onTap:
                                              () => _openAccountOptions(
                                                context,
                                                account,
                                              ),
                                          onPay:
                                              () => _openPaymentModal(account),
                                          onViewHistory:
                                              () => _navigateToHistory(account),
                                        ),
                                      );
                                    }, childCount: accounts.length),
                                  ),
                        ),

                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        ],
                      ),
                    ),
                  ),

                  // --- 4. PAGINACIÓN FIJA AL PIE (ESTILO PEDIDOS / STRIPE) ---
                  _buildPagination(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    totalItems: totalCount,
                    isLoading: isLoading,
                    isDesktop: isDesktop,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPagination({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required bool isLoading,
    required bool isDesktop,
  }) {
    if (totalPages < 1 || totalItems == 0) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      alignment: Alignment.center,
      child: SafeArea(
        top: false,
        bottom: !isDesktop,
        child: AdminPageBlocks(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: context.read<SupplierCreditsCubit>().setPage,
        ),
      ),
    );
  }

  // --- SUBCOMPONENTES DE TOOLBAR ---

  Widget _buildSearchField() {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocusNode,
        onChanged: context.read<SupplierCreditsCubit>().setSearchQuery,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: 'Buscar por proveedor o RUC...',
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.teal,
            size: 19,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchCtrl,
            builder: (context, value, _) {
              if (value.text.isNotEmpty) {
                return IconButton(
                  icon: const Icon(
                    Icons.cancel_rounded,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    context.read<SupplierCreditsCubit>().setSearchQuery('');
                  },
                );
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildKeyHint('/'),
                  ],
                ),
              );
            },
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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

  Widget _buildViewModeToggle() {
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
            IconButton(
              tooltip: 'Vista en Tabla Pro [V]',
              icon: Icon(
                Icons.table_rows_rounded,
                size: 18,
                color: _isTableView ? AppColors.tealDark : AppColors.textMuted,
              ),
              style: IconButton.styleFrom(
                backgroundColor:
                    _isTableView ? AppColors.surface : Colors.transparent,
                elevation: _isTableView ? 1 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
              ),
              onPressed: () => setState(() => _isTableView = true),
            ),
            IconButton(
              tooltip: 'Vista en Tarjetas [V]',
              icon: Icon(
                Icons.grid_view_rounded,
                size: 18,
                color: !_isTableView ? AppColors.tealDark : AppColors.textMuted,
              ),
              style: IconButton.styleFrom(
                backgroundColor:
                    !_isTableView ? AppColors.surface : Colors.transparent,
                elevation: !_isTableView ? 1 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
              ),
              onPressed: () => setState(() => _isTableView = false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyHint(String char) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildButtonKeyHint(String char) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
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
