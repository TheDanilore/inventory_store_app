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
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/credit_account_card.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/global_stats_bar.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/credit_account_modal.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/customer_credit_payment_modal.dart';

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
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<CustomerCreditListCubit>().setTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 950;
        final isTablet = width >= 600 && width < 950;

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, alt: true): () {
              _searchFocusNode.requestFocus();
            },
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
              _searchFocusNode.requestFocus();
            },
            const SingleActivator(LogicalKeyboardKey.keyN, alt: true): () {
              _openCreateAccountModal();
            },
            const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
              _openCreateAccountModal();
            },
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_searchCtrl.text.isNotEmpty) {
                _searchCtrl.clear();
                _debounce?.cancel();
                context.read<CustomerCreditListCubit>().setSearch('');
              } else {
                _searchFocusNode.unfocus();
              }
            },
          },
          child: BlocBuilder<CustomerCreditListCubit, CustomerCreditListState>(
            builder: (context, state) {
              final int accountsWithDebtCount =
                  state.accounts.where((a) => a.currentDebt > 0).length;

              return AdminLayout(
                title: 'Cuentas por Cobrar',
                showBackButton: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refrescar datos',
                    onPressed: () {
                      context.read<CustomerCreditListCubit>().loadData();
                    },
                  ),
                ],
                floatingActionButton:
                    isDesktop
                        ? null
                        : FloatingActionButton.extended(
                          onPressed: () => _openCreateAccountModal(),
                          backgroundColor: AppColors.primary,
                          icon: const Icon(
                            Icons.domain_add_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Nuevo Crédito',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                body: Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh:
                            () async => context
                                .read<CustomerCreditListCubit>()
                                .loadData(),
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // 1. Bento Metric Cards (Stripe / Linear style)
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

                            // 2. Adaptive Unified Toolbar
                            SliverToBoxAdapter(
                              child: _buildAdaptiveToolbar(
                                state: state,
                                isDesktop: isDesktop,
                                isTablet: isTablet,
                              ),
                            ),

                            // 3. Content States
                            if (state.isLoading && state.accounts.isEmpty)
                              SliverToBoxAdapter(
                                child:
                                    isDesktop
                                        ? const _DesktopCreditsSkeleton()
                                        : const _MobileCreditsSkeleton(),
                              )
                            else if (state.errorMessage.isNotEmpty &&
                                state.accounts.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: AppEmptyState(
                                  icon: Icons.error_outline_rounded,
                                  color: AppColors.error,
                                  title: 'Error de carga',
                                  message: state.errorMessage,
                                  action: FilledButton(
                                    onPressed:
                                        () => context
                                            .read<CustomerCreditListCubit>()
                                            .loadData(),
                                    child: const Text('Reintentar'),
                                  ),
                                ),
                              )
                            else if (state.accounts.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: AppEmptyState(
                                  icon: Icons.credit_card_off_rounded,
                                  title: 'No se encontraron líneas de crédito',
                                  message:
                                      _searchCtrl.text.isNotEmpty
                                          ? 'No hay resultados que coincidan con "${_searchCtrl.text}".'
                                          : 'Crea una nueva línea de crédito para autorizar ventas a plazo.',
                                  action: FilledButton(
                                    onPressed: () {
                                      if (_searchCtrl.text.isNotEmpty) {
                                        _searchCtrl.clear();
                                        _onSearchChanged('');
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
                            else if (isDesktop)
                              // Desktop View: High-Density Data Table
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  6,
                                  16,
                                  24,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: _CustomerCreditsDataTable(
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
                            else if (isTablet)
                              // Tablet View: 2-Column Responsive Card Grid
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  6,
                                  16,
                                  24,
                                ),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        mainAxisExtent: 220,
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
                                ),
                              )
                            else
                              // Mobile View: Refined Apple HIG Cards
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  6,
                                  16,
                                  24,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final account = state.accounts[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
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
                                                ? () =>
                                                    _openPaymentModal(account)
                                                : null,
                                        onHistoryTap:
                                            () => _openMovementsScreen(account),
                                      ),
                                    );
                                  }, childCount: state.accounts.length),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // 4. Pagination
                    if (!state.isLoading && state.totalPages > 1)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: const Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: AdminPageBlocks(
                            currentPage: state.currentPage,
                            totalPages: state.totalPages,
                            onPageChanged:
                                (page) => context
                                    .read<CustomerCreditListCubit>()
                                    .setPage(page),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAdaptiveToolbar({
    required CustomerCreditListState state,
    required bool isDesktop,
    required bool isTablet,
  }) {
    final int debtCount =
        state.accounts.where((a) => a.currentDebt > 0 && a.isActive).length;
    final int totalCount = state.accounts.length;

    if (isDesktop) {
      // Desktop: Unified 48px Pro Toolbar
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Segmented Pills
            _SegmentedTabPill(
              label: 'Todas',
              count: totalCount,
              isSelected: _tabController.index == 0,
              onTap: () => _tabController.animateTo(0),
            ),
            const SizedBox(width: 8),
            _SegmentedTabPill(
              label: 'Con Deuda',
              count: debtCount,
              isSelected: _tabController.index == 1,
              isAlert: debtCount > 0,
              onTap: () => _tabController.animateTo(1),
            ),
            const Spacer(),
            // Search field
            SizedBox(
              width: 340,
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar cliente, DNI o teléfono...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  suffixIcon:
                      _searchCtrl.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            splashRadius: 14,
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          )
                          : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Alt + K',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Primary Action Button
            FilledButton.icon(
              onPressed: () => _openCreateAccountModal(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Row(
                children: [
                  Text(
                    'Nueva Línea',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '[Alt + N]',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isTablet) {
      // Tablet: 2-row clean toolbar
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _SegmentedTabPill(
                  label: 'Todas',
                  count: totalCount,
                  isSelected: _tabController.index == 0,
                  onTap: () => _tabController.animateTo(0),
                ),
                const SizedBox(width: 8),
                _SegmentedTabPill(
                  label: 'Con Deuda',
                  count: debtCount,
                  isSelected: _tabController.index == 1,
                  isAlert: debtCount > 0,
                  onTap: () => _tabController.animateTo(1),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _openCreateAccountModal(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Nueva Línea',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar cliente, DNI o teléfono...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                suffixIcon:
                    _searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                        : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile: Touch-friendly layout
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar cliente, DNI o teléfono...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
              ),
              suffixIcon:
                  _searchCtrl.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      )
                      : null,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textMuted,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: [
                Tab(text: 'Todas ($totalCount)'),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Con Deuda'),
                      if (debtCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$debtCount',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
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
        ],
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
// Component: Segmented Tab Pill
// -----------------------------------------------------------------------------
class _SegmentedTabPill extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final bool isAlert;
  final VoidCallback onTap;

  const _SegmentedTabPill({
    required this.label,
    required this.count,
    required this.isSelected,
    this.isAlert = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Colors.white.withValues(alpha: 0.22)
                        : (isAlert
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color:
                      isSelected
                          ? Colors.white
                          : (isAlert
                              ? const Color(0xFFDC2626)
                              : AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Component: High-Density Desktop Data Table
// -----------------------------------------------------------------------------
class _CustomerCreditsDataTable extends StatelessWidget {
  final List<CustomerCreditEntity> accounts;
  final void Function(CustomerCreditEntity) onPayTap;
  final void Function(CustomerCreditEntity) onHistoryTap;
  final void Function(CustomerCreditEntity) onEditTap;
  final void Function(CustomerCreditEntity) onToggleStatusTap;
  final void Function(String text, String label) onCopy;

  const _CustomerCreditsDataTable({
    required this.accounts,
    required this.onPayTap,
    required this.onHistoryTap,
    required this.onEditTap,
    required this.onToggleStatusTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    'CLIENTE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
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
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'DEUDA ACTUAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'LÍMITE TOTAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'DISPONIBLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Text(
                      'USO %',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'ACCIONES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Table Rows (direct list without shrinkWrap viewport overhead)
          for (int i = 0; i < accounts.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _DesktopTableRow(
              key: ValueKey(accounts[i].id),
              account: accounts[i],
              onPayTap: () => onPayTap(accounts[i]),
              onHistoryTap: () => onHistoryTap(accounts[i]),
              onEditTap: () => onEditTap(accounts[i]),
              onToggleStatusTap: () => onToggleStatusTap(accounts[i]),
              onCopy: onCopy,
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopTableRow extends StatefulWidget {
  final CustomerCreditEntity account;
  final VoidCallback onPayTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onEditTap;
  final VoidCallback onToggleStatusTap;
  final void Function(String text, String label) onCopy;

  const _DesktopTableRow({
    super.key,
    required this.account,
    required this.onPayTap,
    required this.onHistoryTap,
    required this.onEditTap,
    required this.onToggleStatusTap,
    required this.onCopy,
  });

  @override
  State<_DesktopTableRow> createState() => _DesktopTableRowState();
}

class _DesktopTableRowState extends State<_DesktopTableRow> {
  bool _isHovered = false;

  void _showContextMenu(TapDownDetails details) {
    final account = widget.account;
    final position = RelativeRect.fromRect(
      details.globalPosition & const Size(40, 40),
      Offset.zero & MediaQuery.of(context).size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      items: [
        PopupMenuItem(
          value: 'pay',
          enabled: account.isActive && account.currentDebt > 0,
          child: Row(
            children: const [
              Icon(
                Icons.payments_rounded,
                size: 18,
                color: Color(0xFF16A34A),
              ),
              SizedBox(width: 10),
              Text('Registrar Pago / Abono'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'history',
          child: Row(
            children: const [
              Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Ver historial de movimientos'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: const [
              Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 10),
              Text('Editar límite de crédito'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'toggle_status',
          child: Row(
            children: [
              Icon(
                account.isActive
                    ? Icons.block_rounded
                    : Icons.check_circle_rounded,
                size: 18,
                color: account.isActive ? AppColors.error : AppColors.success,
              ),
              const SizedBox(width: 10),
              Text(
                account.isActive ? 'Suspender Línea' : 'Reactivar Línea',
                style: TextStyle(
                  color: account.isActive ? AppColors.error : AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (account.customerDocument != null &&
            account.customerDocument!.isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'copy_doc',
            child: Row(
              children: const [
                Icon(Icons.copy_rounded, size: 18, color: AppColors.textMuted),
                SizedBox(width: 10),
                Text('Copiar Documento'),
              ],
            ),
          ),
        ],
        if (account.customerPhone != null &&
            account.customerPhone!.isNotEmpty) ...[
          PopupMenuItem(
            value: 'copy_phone',
            child: Row(
              children: const [
                Icon(Icons.phone_rounded, size: 18, color: AppColors.textMuted),
                SizedBox(width: 10),
                Text('Copiar Teléfono'),
              ],
            ),
          ),
        ],
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'pay':
          widget.onPayTap();
          break;
        case 'history':
          widget.onHistoryTap();
          break;
        case 'edit':
          widget.onEditTap();
          break;
        case 'toggle_status':
          widget.onToggleStatusTap();
          break;
        case 'copy_doc':
          if (account.customerDocument != null) {
            widget.onCopy(account.customerDocument!, 'Documento');
          }
          break;
        case 'copy_phone':
          if (account.customerPhone != null) {
            widget.onCopy(account.customerPhone!, 'Teléfono');
          }
          break;
      }
    });
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'CL';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final double pct =
        account.creditLimit > 0
            ? (account.currentDebt / account.creditLimit)
            : 0.0;
    final isMaxedOut =
        account.currentDebt >= account.creditLimit && account.creditLimit > 0;
    final isRisk = pct >= 0.8 && !isMaxedOut;

    final Color statusColor =
        !account.isActive
            ? AppColors.danger
            : (isMaxedOut
                ? AppColors.danger
                : (isRisk
                    ? const Color(0xFFEA580C)
                    : (account.currentDebt > 0
                        ? const Color(0xFFD97706)
                        : const Color(0xFF0D9488))));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: _showContextMenu,
        onTap: widget.onHistoryTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          child: Row(
            children: [
              // 1. Cliente
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _getInitials(account.customerName),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.customerName ?? 'Cliente Desconocido',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            account.customerDocument != null &&
                                    account.customerDocument!.isNotEmpty
                                ? 'Doc: ${account.customerDocument}'
                                : (account.customerPhone != null &&
                                        account.customerPhone!.isNotEmpty
                                    ? 'Tel: ${account.customerPhone}'
                                    : 'Sin documento'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Estado
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusChip(account, isMaxedOut, isRisk),
                ),
              ),

              // 3. Deuda Actual
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'S/ ${account.currentDebt.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color:
                          account.currentDebt > 0
                              ? (isMaxedOut || isRisk
                                  ? AppColors.danger
                                  : AppColors.textPrimary)
                              : AppColors.success,
                    ),
                  ),
                ),
              ),

              // 4. Límite Total
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'S/ ${account.creditLimit.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),

              // 5. Disponible
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'S/ ${account.availableCredit.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          account.isActive
                              ? const Color(0xFF0D9488)
                              : AppColors.textMuted,
                    ),
                  ),
                ),
              ),

              // 6. Uso %
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              statusColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 7. Acciones Rápidas
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (account.isActive && account.currentDebt > 0) ...[
                      FilledButton.tonalIcon(
                        onPressed: widget.onPayTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF0FDF4),
                          foregroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: const BorderSide(color: Color(0xFFBBF7D0)),
                          ),
                        ),
                        icon: const Icon(Icons.payments_rounded, size: 14),
                        label: const Text(
                          'Abonar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    IconButton(
                      icon: const Icon(Icons.history_rounded, size: 18),
                      tooltip: 'Ver historial',
                      splashRadius: 16,
                      color: AppColors.textSecondary,
                      onPressed: widget.onHistoryTap,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 17),
                      tooltip: 'Editar límite',
                      splashRadius: 16,
                      color: AppColors.textSecondary,
                      onPressed: widget.onEditTap,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      tooltip: 'Más opciones',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onSelected: (val) {
                        switch (val) {
                          case 'pay':
                            widget.onPayTap();
                            break;
                          case 'history':
                            widget.onHistoryTap();
                            break;
                          case 'edit':
                            widget.onEditTap();
                            break;
                          case 'toggle_status':
                            widget.onToggleStatusTap();
                            break;
                        }
                      },
                      itemBuilder:
                          (ctx) => [
                            if (account.isActive && account.currentDebt > 0)
                              const PopupMenuItem(
                                value: 'pay',
                                child: Text('💵 Abonar a cuenta'),
                              ),
                            const PopupMenuItem(
                              value: 'history',
                              child: Text('📜 Historial'),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('✏️ Editar límite'),
                            ),
                            PopupMenuItem(
                              value: 'toggle_status',
                              child: Text(
                                account.isActive
                                    ? '🚫 Suspender'
                                    : '✅ Reactivar',
                              ),
                            ),
                          ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    CustomerCreditEntity account,
    bool isMaxedOut,
    bool isRisk,
  ) {
    if (!account.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: const Text(
          'Suspendida',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDC2626),
          ),
        ),
      );
    }
    if (isMaxedOut) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: const Text(
          'Al Límite',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDC2626),
          ),
        ),
      );
    }
    if (isRisk) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Text(
          'Riesgo',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD97706),
          ),
        ),
      );
    }
    if (account.currentDebt > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Text(
          'Con Deuda',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF16A34A),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Text(
        'Activa',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Component: Skeletons (Desktop Table & Mobile Cards)
// -----------------------------------------------------------------------------
class _DesktopCreditsSkeleton extends StatelessWidget {
  const _DesktopCreditsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: AppShimmer(width: 80, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 2,
                  child: AppShimmer(width: 60, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppShimmer(width: 70, height: 12, borderRadius: 4),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppShimmer(width: 70, height: 12, borderRadius: 4),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppShimmer(width: 70, height: 12, borderRadius: 4),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: AppShimmer(width: 50, height: 12, borderRadius: 4),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppShimmer(width: 80, height: 12, borderRadius: 4),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (int i = 0; i < 6; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: const [
                        AppShimmer(width: 36, height: 36, borderRadius: 8),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppShimmer(width: 120, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            AppShimmer(width: 80, height: 10, borderRadius: 3),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: AppShimmer(width: 60, height: 20, borderRadius: 6),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AppShimmer(width: 65, height: 14, borderRadius: 4),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AppShimmer(width: 65, height: 14, borderRadius: 4),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AppShimmer(width: 65, height: 14, borderRadius: 4),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.only(left: 20),
                      child: AppShimmer(width: 60, height: 6, borderRadius: 3),
                    ),
                  ),
                  const Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AppShimmer(width: 70, height: 24, borderRadius: 6),
                    ),
                  ),
                ],
              ),
            ),
            if (i < 5) const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _MobileCreditsSkeleton extends StatelessWidget {
  const _MobileCreditsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  AppShimmer(width: 40, height: 40, borderRadius: 10),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppShimmer(width: 140, height: 14, borderRadius: 4),
                      SizedBox(height: 4),
                      AppShimmer(width: 80, height: 10, borderRadius: 3),
                    ],
                  ),
                  Spacer(),
                  AppShimmer(width: 60, height: 18, borderRadius: 6),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppShimmer(width: 60, height: 10, borderRadius: 2),
                      SizedBox(height: 4),
                      AppShimmer(width: 90, height: 20, borderRadius: 4),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppShimmer(width: 80, height: 12, borderRadius: 3),
                      SizedBox(height: 4),
                      AppShimmer(width: 60, height: 10, borderRadius: 2),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const AppShimmer(
                width: double.infinity,
                height: 6,
                borderRadius: 3,
              ),
            ],
          ),
        );
      },
    );
  }
}
