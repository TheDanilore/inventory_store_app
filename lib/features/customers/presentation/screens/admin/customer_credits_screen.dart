import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/credit_account_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/customer_credit_payment_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/sections/customer_account_options_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/sections/customer_credits_content_section.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/sections/customer_credits_kpi_section.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/sections/customer_credits_pagination_section.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/sections/customer_credits_toolbar_section.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

/// Pantalla modularizada de gestión de cuentas por cobrar de clientes.
///
/// Implementa Zero-Shimmer (Frame 0 desde CustomerCreditsLruCache + SWR),
/// BlocSelectors por sección, FAB móvil corregido y limpieza estricta de recursos.
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
  late final TabController _tabController;
  late final ValueNotifier<int> _tabIndexNotifier;
  final ValueNotifier<bool> _isTableViewNotifier = ValueNotifier<bool>(true);

  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final hydrated = context.read<CustomerCreditListCubit>().state;
    final initialTab = hydrated.withDebtOnly ? 1 : 0;
    if (hydrated.searchQuery.isNotEmpty) {
      _searchCtrl.text = hydrated.searchQuery;
    }

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialTab,
    );
    _tabIndexNotifier = ValueNotifier<int>(initialTab);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final idx = _tabController.index;
    _tabIndexNotifier.value = idx;
    context.read<CustomerCreditListCubit>().setTab(idx);
  }

  void _selectTab(int index) {
    if (_tabController.index == index) return;
    _tabController.animateTo(index);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _tabIndexNotifier.dispose();
    _isTableViewNotifier.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        context.read<CustomerCreditListCubit>().setSearch(query);
      }
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    context.read<CustomerCreditListCubit>().setSearch('');
  }

  void _openCreateAccountModal({CustomerCreditEntity? accountToEdit}) {
    final cubit = context.read<CustomerCreditListCubit>();
    CreditAccountSheet.show(
      context,
      accountToEdit: accountToEdit,
      onCreateAccount: cubit.createCreditAccount,
      onUpdateLimit: cubit.updateCreditLimit,
      onSaved: () {
        if (mounted) cubit.loadData(forceRefresh: true, silent: true);
      },
    );
  }

  void _openPaymentModal(CustomerCreditEntity account) {
    if (!account.isActive || account.currentDebt <= 0) return;
    final cubit = context.read<CustomerCreditListCubit>();
    CustomerCreditPaymentSheet.show(
      context,
      account: account,
      onSaved: () => cubit.loadData(forceRefresh: true, silent: true),
      onSavePayment: (
        amount,
        accountId,
        orderId,
        notes,
        shiftId,
        idempotencyKey,
      ) async {
        await cubit.registerPayment(
          customerId: account.effectiveCustomerId,
          creditId: account.id,
          amount: amount,
          accountId: accountId,
          orderId: orderId,
          notes: notes,
          shiftId: shiftId,
          idempotencyKey: idempotencyKey,
        );
      },
    );
  }

  void _openMovementsScreen(CustomerCreditEntity account) {
    final cubit = context.read<CustomerCreditListCubit>();
    final customerId = account.effectiveCustomerId;
    context
        .push(
          '/customer-credit-movements/${account.id}?name=${Uri.encodeComponent(account.customerName ?? '')}&debt=${account.currentDebt}&limit=${account.creditLimit}&customerId=$customerId',
          extra: {
            'customerName': account.customerName,
            'currentDebt': account.currentDebt,
            'creditLimit': account.creditLimit,
            'customerId': customerId,
          },
        )
        .then((_) {
          if (mounted) cubit.refreshIfNeeded();
        });
  }

  Future<void> _toggleAccountStatus(CustomerCreditEntity account) async {
    final cubit = context.read<CustomerCreditListCubit>();
    final result = await cubit.toggleAccountStatus(
      account.id,
      account.isActive,
    );
    if (!mounted) return;
    result.fold(
      (failure) => AppSnackbar.show(
        context,
        message: failure.message,
        type: SnackbarType.error,
      ),
      (updated) => AppSnackbar.show(
        context,
        message:
            updated.isActive
                ? 'Línea de crédito reactivada'
                : 'Línea de crédito suspendida',
        type: SnackbarType.success,
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.info,
    );
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

  KeyEventResult _handleKeyShortcuts(FocusNode node, KeyEvent event) {
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
      _openCreateAccountModal();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      context.read<CustomerCreditListCubit>().loadData(
        forceRefresh: true,
        silent: true,
      );
      AppSnackbar.show(
        context,
        message: 'Actualizando cuentas de clientes...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      _selectTab(0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      _selectTab(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyV) {
      _isTableViewNotifier.value = !_isTableViewNotifier.value;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_searchCtrl.text.isNotEmpty) _clearSearch();
      _searchFocusNode.unfocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = width >= 640;
        final isDesktop = width >= 1024;

        return Focus(
          autofocus: true,
          onKeyEvent: _handleKeyShortcuts,
          child: AdminLayout(
            title: 'Cuentas por Cobrar',
            floatingActionButton:
                !isWide
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
                          heroTag: 'add_customer_credit_fab',
                          backgroundColor: AppColors.primary,
                          elevation: 4,
                          icon: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Nueva Línea',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: _openCreateAccountModal,
                        );
                      },
                    )
                    : null,
            body: RefreshIndicator(
              color: AppColors.primary,
              onRefresh:
                  () => context.read<CustomerCreditListCubit>().loadData(
                    forceRefresh: true,
                    silent: true,
                  ),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: AdminPageHeader(
                      title: 'Cuentas por Cobrar',
                      subtitle: 'Gestiona tus cuentas por cobrar',
                      isDesktop: isDesktop,
                      actions: [
                        AdminHeaderButton.primary(
                          label: 'Nueva Línea',
                          icon: Icons.add_rounded,
                          tooltip: 'Nueva línea de crédito (Atajo: N)',
                          onPressed: _openCreateAccountModal,
                        ),
                      ],
                    ),
                  ),
                  const CustomerCreditsKpiSection(),
                  CustomerCreditsToolbarSection(
                    isDesktop: isDesktop,
                    searchController: _searchCtrl,
                    searchFocusNode: _searchFocusNode,
                    tabIndexNotifier: _tabIndexNotifier,
                    isTableViewNotifier: _isTableViewNotifier,
                    onSearchChanged: _onSearchChanged,
                    onClearSearch: _clearSearch,
                    onTabSelected: _selectTab,
                    onRefresh:
                        () => context.read<CustomerCreditListCubit>().loadData(
                          forceRefresh: true,
                          silent: true,
                        ),
                  ),
                  CustomerCreditsContentSection(
                    isWide: isWide,
                    isTableViewNotifier: _isTableViewNotifier,
                    onPayTap: _openPaymentModal,
                    onHistoryTap: _openMovementsScreen,
                    onEditTap:
                        (acc) => _openCreateAccountModal(accountToEdit: acc),
                    onToggleStatusTap: _toggleAccountStatus,
                    onShowAccountOptions:
                        (acc) => CustomerAccountOptionsSheet.show(
                          context,
                          account: acc,
                          onPay: () => _openPaymentModal(acc),
                          onHistory: () => _openMovementsScreen(acc),
                          onEditLimit:
                              () =>
                                  _openCreateAccountModal(accountToEdit: acc),
                          onToggleStatus: () => _toggleAccountStatus(acc),
                        ),
                    onCopy: _copyToClipboard,
                    onCreateAccount: _openCreateAccountModal,
                    onClearSearch: _clearSearch,
                    onRetry:
                        () => context.read<CustomerCreditListCubit>().loadData(
                          forceRefresh: true,
                        ),
                  ),
                  CustomerCreditsPaginationSection(
                    scrollController: _scrollController,
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
