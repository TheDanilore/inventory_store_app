import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/credit_account_card.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/global_stats_bar.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/credit_account_modal.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/customer_credit_payment_modal.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/customer_credits_table.dart';

class CustomerCreditsScreen extends StatelessWidget {
  const CustomerCreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CustomerCreditListCubit>()..init(),
      child: const _CustomerCreditsScreenContent(),
    );
  }
}

class _CustomerCreditsScreenContent extends StatefulWidget {
  const _CustomerCreditsScreenContent();

  @override
  State<_CustomerCreditsScreenContent> createState() =>
      _CustomerCreditsScreenContentState();
}

class _CustomerCreditsScreenContentState
    extends State<_CustomerCreditsScreenContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _debounce;
  bool _isTableView = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<CustomerCreditListCubit>().setTab(_tabController.index);
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        context.read<CustomerCreditListCubit>().setSearch(query);
      }
    });
  }

  void _openCreateAccountModal({CustomerCreditEntity? accountToEdit}) {
    CreditAccountModal.show(
      context,
      accountToEdit: accountToEdit,
      onSaved: () {
        if (mounted) context.read<CustomerCreditListCubit>().loadData();
      },
    );
  }

  void _openPaymentModal(CustomerCreditEntity account) {
    if (!account.isActive || account.currentDebt <= 0) return;
    final cubit = context.read<CustomerCreditListCubit>();
    CustomerCreditPaymentModal.show(
      context,
      account: account,
      onSaved: () => cubit.loadData(),
      onSavePayment: (amount, accountId, orderId, notes, shiftId) async {
        await cubit.registerPayment(
          customerId: account.profileId,
          creditId: account.id,
          amount: amount,
          accountId: accountId,
          orderId: orderId,
          notes: notes,
          shiftId: shiftId,
        );
      },
    );
  }

  void _openMovementsScreen(CustomerCreditEntity account) {
    final cubit = context.read<CustomerCreditListCubit>();
    context
        .push(
          '/customer-credit-movements/${account.id}?name=${Uri.encodeComponent(account.customerName ?? '')}&debt=${account.currentDebt}&limit=${account.creditLimit}&customerId=${account.profileId}',
          extra: {
            'customerName': account.customerName,
            'currentDebt': account.currentDebt,
            'creditLimit': account.creditLimit,
            'customerId': account.profileId,
          },
        )
        .then((_) {
          if (mounted) cubit.loadData();
        });
  }

  Future<void> _toggleAccountStatus(CustomerCreditEntity account) async {
    final cubit = context.read<CustomerCreditListCubit>();
    try {
      await cubit.toggleAccountStatus(account.id, account.isActive);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message:
            account.isActive
                ? 'Línea de crédito suspendida'
                : 'Línea de crédito reactivada',
        type: SnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Error al cambiar estado: $e',
        type: SnackbarType.error,
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.info,
    );
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
      context.read<CustomerCreditListCubit>().loadData();
      AppSnackbar.show(
        context,
        message: 'Actualizando cuentas de clientes...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

    // Atajo [1] -> Pestaña Todas
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      _tabController.animateTo(0);
      setState(() {});
      return KeyEventResult.handled;
    }

    // Atajo [2] -> Pestaña Por Cobrar
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      _tabController.animateTo(1);
      setState(() {});
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
        _debounce?.cancel();
        context.read<CustomerCreditListCubit>().setSearch('');
      }
      _searchFocusNode.unfocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 640;
    final isDesktop = width >= 1024;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyShortcuts,
      child: BlocBuilder<CustomerCreditListCubit, CustomerCreditListState>(
        builder: (context, state) {
          final int accountsWithDebtCount =
              state.accounts
                  .where((a) => a.currentDebt > 0 && a.isActive)
                  .length;

          return AdminLayout(
            title: 'Cuentas por Cobrar',
            // En tablet/escritorio ocultamos el FAB flotante; la acción se ubica en el Toolbar superior
            floatingActionButton:
                isWide
                    ? null
                    : FloatingActionButton(
                      onPressed: () => _openCreateAccountModal(),
                      backgroundColor: AppColors.primary,
                      tooltip: 'Nueva Línea',
                      child: const Icon(Icons.add_rounded, color: Colors.white),
                    ),
            body: RefreshIndicator(
              color: AppColors.primary,
              onRefresh:
                  () async =>
                      context.read<CustomerCreditListCubit>().loadData(),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // --- 1. KPI BENTO METRIC BAR ---
                  if (!state.isLoading || state.accounts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: GlobalStatsBar(
                        totalDebt: state.totalDebt,
                        activeAccounts: state.activeAccounts,
                        suspendedAccounts: state.suspendedAccounts,
                        maxedOutAccounts: state.maxedOutAccounts,
                        accountsWithDebt: accountsWithDebtCount,
                      ),
                    ),

                  // --- 2. TOOLBAR UNIFICADO DE BÚSQUEDA Y ACCIONES ---
                  SliverToBoxAdapter(
                    child: AdminProToolbar(
                      isDesktop: isDesktop,
                      searchController: _searchCtrl,
                      searchFocusNode: _searchFocusNode,
                      searchHint: 'Buscar por cliente, documento o teléfono...',
                      onSearchChanged: _onSearchChanged,
                      onClearSearch: () {
                        _searchCtrl.clear();
                        _debounce?.cancel();
                        context.read<CustomerCreditListCubit>().setSearch('');
                      },
                      filterWidgets: [
                        _buildSegmentedFilter(accountsWithDebtCount),
                      ],
                      viewToggleConfig: AdminProViewToggleConfig(
                        isTableView: _isTableView,
                        onToggleTableView:
                            (val) => setState(() => _isTableView = val),
                      ),
                      onRefresh:
                          () =>
                              context
                                  .read<CustomerCreditListCubit>()
                                  .loadData(),
                      refreshTooltip: 'Refrescar créditos [R]',
                      primaryAction: AdminProToolbarAction(
                        label: 'Nueva Línea',
                        icon: Icons.add_rounded,
                        onPressed: () => _openCreateAccountModal(),
                        keyHint: 'N',
                      ),
                    ),
                  ),

                  // --- 3. CONTENIDO: CARDS O TABLA ---
                  if (state.isLoading && state.accounts.isEmpty)
                    (isWide && _isTableView)
                        ? const SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(child: AppTableShimmer()),
                        )
                        : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver:
                              isWide
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
                  else if (state.errorMessage.isNotEmpty &&
                      state.accounts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        icon: Icons.error_outline_rounded,
                        color: AppColors.danger,
                        title: 'Error de carga',
                        message: state.errorMessage,
                        action: FilledButton.icon(
                          onPressed:
                              () =>
                                  context
                                      .read<CustomerCreditListCubit>()
                                      .loadData(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                        ),
                      ),
                    )
                  else if (state.accounts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        icon: Icons.receipt_long_rounded,
                        title:
                            _searchCtrl.text.isNotEmpty
                                ? 'No se encontraron resultados'
                                : (_tabController.index == 1
                                    ? 'No hay créditos con deuda pendiente'
                                    : 'No hay líneas de crédito registradas'),
                        message:
                            _searchCtrl.text.isNotEmpty
                                ? 'No hay resultados que coincidan con "${_searchCtrl.text}".'
                                : 'Crea una nueva línea de crédito para autorizar ventas a plazo.',
                        action: FilledButton(
                          onPressed: () {
                            if (_searchCtrl.text.isNotEmpty) {
                              _searchCtrl.clear();
                              _debounce?.cancel();
                              context.read<CustomerCreditListCubit>().setSearch(
                                '',
                              );
                            } else {
                              _openCreateAccountModal();
                            }
                          },
                          child: Text(
                            _searchCtrl.text.isNotEmpty
                                ? 'Limpiar filtro'
                                : '+ Nueva Línea de Crédito',
                          ),
                        ),
                      ),
                    )
                  else if (isWide && _isTableView)
                    // VISTA DE ALTA DENSIDAD: TABLA PRO
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: CustomerCreditsTable(
                          accounts: state.accounts,
                          onPayTap: _openPaymentModal,
                          onHistoryTap: _openMovementsScreen,
                          onEditTap:
                              (account) => _openCreateAccountModal(
                                accountToEdit: account,
                              ),
                          onToggleStatusTap: _toggleAccountStatus,
                          onCopy: _copyToClipboard,
                        ),
                      ),
                    )
                  else
                    // VISTA VISUAL: TARJETAS DINÁMICAS
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver:
                          isWide
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
                                  final account = state.accounts[index];
                                  return CreditAccountCard(
                                    account: account,
                                    onTap:
                                        () => _showAccountOptions(
                                          context,
                                          account,
                                        ),
                                    onPayTap:
                                        account.isActive &&
                                                account.currentDebt > 0
                                            ? () => _openPaymentModal(account)
                                            : null,
                                    onHistoryTap:
                                        () => _openMovementsScreen(account),
                                  );
                                }, childCount: state.accounts.length),
                              )
                              : SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final account = state.accounts[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: CreditAccountCard(
                                      account: account,
                                      onTap:
                                          () => _showAccountOptions(
                                            context,
                                            account,
                                          ),
                                      onPayTap:
                                          account.isActive &&
                                                  account.currentDebt > 0
                                              ? () => _openPaymentModal(account)
                                              : null,
                                      onHistoryTap:
                                          () => _openMovementsScreen(account),
                                    ),
                                  );
                                }, childCount: state.accounts.length),
                              ),
                    ),

                  // --- 4. PAGINACIÓN FLUIDA AL PIE DEL SCROLL ---
                  _buildPaginationSliver(
                    currentPage: state.currentPage,
                    totalPages: state.totalPages,
                    totalItems: state.totalAccounts,
                    isLoading: state.isLoading,
                    context: context,
                  ),
                ],
              ),
            ),
          );
        },
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
    if (isLoading || totalItems == 0) {
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
              context.read<CustomerCreditListCubit>().setPage(page);
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            totalItems: totalItems,
            itemName: 'créditos de clientes',
          ),
        ),
      ),
    );
  }

  // --- SUBCOMPONENTES DE TOOLBAR ---

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
              isSelected: _tabController.index == 0,
              onTap: () {
                _tabController.animateTo(0);
                setState(() {});
              },
            ),
            const SizedBox(width: 4),
            _FilterTabButton(
              title: 'Por Cobrar',
              count: debtCount,
              shortcutHint: '2',
              isSelected: _tabController.index == 1,
              onTap: () {
                _tabController.animateTo(1);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountOptions(BuildContext context, CustomerCreditEntity account) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _getInitials(account.customerName),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.customerName ?? 'Cliente',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Deuda: S/ ${account.currentDebt.toStringAsFixed(2)} | Disp: S/ ${account.availableCredit.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          account.isActive && account.currentDebt > 0
                              ? const Color(0xFFF0FDF4)
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.payments_rounded,
                      color:
                          account.isActive && account.currentDebt > 0
                              ? const Color(0xFF16A34A)
                              : AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Registrar Pago / Abono',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    account.currentDebt <= 0
                        ? 'Esta línea no presenta saldo pendiente'
                        : 'Amortizar saldo deudor',
                    style: const TextStyle(fontSize: 12),
                  ),
                  enabled: account.isActive && account.currentDebt > 0,
                  onTap: () {
                    Navigator.pop(ctx);
                    _openPaymentModal(account);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Ver historial de movimientos',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Revisar cargos, abonos y comprobantes',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openMovementsScreen(account);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Editar Límite de Crédito',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Modificar cupo total asignado',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openCreateAccountModal(accountToEdit: account);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          account.isActive
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      account.isActive
                          ? Icons.block_rounded
                          : Icons.check_circle_rounded,
                      color:
                          account.isActive
                              ? AppColors.error
                              : AppColors.success,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    account.isActive ? 'Suspender Línea' : 'Reactivar Línea',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:
                          account.isActive
                              ? AppColors.error
                              : AppColors.success,
                    ),
                  ),
                  subtitle: Text(
                    account.isActive
                        ? 'Bloquear nuevas compras a crédito'
                        : 'Habilitar compras a crédito',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleAccountStatus(account);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'CL';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }
}

// -----------------------------------------------------------------------------
// Component: Filter Tab Button (Segmented Pill)
// -----------------------------------------------------------------------------
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
