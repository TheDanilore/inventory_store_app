import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_account_options_sheet.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_credit_account_sheet.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_credits_content_section.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_credits_kpi_section.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_credits_pagination_section.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_credits_toolbar_section.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_payment_sheet.dart';

class SupplierCreditsScreen extends StatefulWidget {
  const SupplierCreditsScreen({super.key});

  @override
  State<SupplierCreditsScreen> createState() => _SupplierCreditsScreenState();
}

class _SupplierCreditsScreenState extends State<SupplierCreditsScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _screenFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final ValueNotifier<bool> _isTableViewNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<String?> _selectedCreditIdNotifier =
      ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    final currentState = context.read<SupplierCreditsCubit>().state;
    if (currentState.searchQuery.isNotEmpty) {
      _searchCtrl.text = currentState.searchQuery;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    _scrollController.dispose();
    _isTableViewNotifier.dispose();
    _selectedCreditIdNotifier.dispose();
    super.dispose();
  }

  bool get _isInputFieldFocused {
    if (_searchFocusNode.hasFocus) return true;
    final primaryFocus = FocusManager.instance.primaryFocus;
    final focusContext = primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null ||
        focusContext.findAncestorStateOfType<EditableTextState>() != null;
  }

  KeyEventResult _handleKeyShortcuts(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final cubit = context.read<SupplierCreditsCubit>();
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
      cubit.loadAccounts(forceRefresh: true);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      cubit.setWithDebtOnly(false);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      cubit.setWithDebtOnly(true);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyV) {
      _isTableViewNotifier.value = !_isTableViewNotifier.value;
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (_selectedCreditIdNotifier.value != null) {
        _selectedCreditIdNotifier.value = null;
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        cubit.setSearchQuery('');
      }
      _searchFocusNode.unfocus();
      _screenFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    final accounts = cubit.state.accounts;
    if (accounts.isNotEmpty) {
      final selectedId = _selectedCreditIdNotifier.value;
      final currentIndex =
          selectedId != null
              ? accounts.indexWhere((a) => a.creditId == selectedId)
              : -1;

      if (key == LogicalKeyboardKey.arrowDown) {
        final nextIndex = (currentIndex + 1).clamp(0, accounts.length - 1);
        _selectedCreditIdNotifier.value = accounts[nextIndex].creditId;
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowUp) {
        final prevIndex = (currentIndex - 1).clamp(0, accounts.length - 1);
        _selectedCreditIdNotifier.value = accounts[prevIndex].creditId;
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        final account =
            currentIndex >= 0 ? accounts[currentIndex] : accounts.first;
        _openAccountOptions(account);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _openCreateAccountModal() {
    SupplierCreditAccountSheet.show(
      context,
      onSaved: (updated) {
        if (mounted) {
          context.read<SupplierCreditsCubit>().onAccountSaved(updated);
        }
      },
    );
  }

  void _openEditAccountModal(SupplierCreditEntity account) {
    SupplierCreditAccountSheet.show(
      context,
      accountToEdit: account,
      onSaved: (updated) {
        if (mounted) {
          context.read<SupplierCreditsCubit>().onAccountSaved(updated);
        }
      },
    );
  }

  void _openPaymentModal(SupplierCreditEntity account) {
    SupplierPaymentSheet.show(context, account: account);
  }

  Future<void> _navigateToHistory(SupplierCreditEntity account) async {
    final mutated = await context.push<bool>(
      '/supplier-credit-movements/${account.creditId}?name=${Uri.encodeComponent(account.supplierName)}&debt=${account.currentDebt}&limit=${account.creditLimit}',
      extra: {
        'supplierName': account.supplierName,
        'currentDebt': account.currentDebt,
        'creditLimit': account.creditLimit,
      },
    );
    if (mounted && mutated == true) {
      context.read<SupplierCreditsCubit>().loadAccounts(
        forceRefresh: true,
        silent: true,
      );
    }
  }

  Future<void> _openAccountOptions(SupplierCreditEntity account) async {
    _selectedCreditIdNotifier.value = account.creditId;

    final action = await AdaptiveDetailSheet.show<SupplierAccountAction>(
      context,
      desktopWidth: 420.0,
      barrierLabel: 'Cerrar opciones',
      builder:
          (ctx) => SupplierAccountOptionsSheet(
            account: account,
            isDialog: AdaptiveDetailSheet.isSideSheet(ctx),
          ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case SupplierAccountAction.viewHistory:
        await _navigateToHistory(account);
        break;
      case SupplierAccountAction.pay:
        _openPaymentModal(account);
        break;
      case SupplierAccountAction.edit:
        _openEditAccountModal(account);
        break;
      case SupplierAccountAction.toggleStatus:
        await context.read<SupplierCreditsCubit>().toggleAccountStatus(account);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 640;
    final isDesktop = width >= 1024;
    final cubit = context.read<SupplierCreditsCubit>();

    return Focus(
      focusNode: _screenFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyShortcuts,
      child: BlocListener<SupplierCreditsCubit, SupplierCreditsState>(
        listenWhen:
            (prev, curr) =>
                prev.mutationStatus != curr.mutationStatus &&
                (curr.mutationStatus == SupplierCreditMutationStatus.success ||
                    curr.mutationStatus ==
                        SupplierCreditMutationStatus.failure),
        listener: (context, state) {
          final msg = state.mutationMessage;
          if (msg != null && msg.isNotEmpty) {
            AppSnackbar.show(
              context,
              message: msg,
              type:
                  state.mutationStatus == SupplierCreditMutationStatus.success
                      ? SnackbarType.success
                      : SnackbarType.error,
            );
          }
          cubit.clearMutationFeedback();
        },
        child: AdminLayout(
          title: 'Créditos de Proveedores',
          floatingActionButton:
              !isDesktop
                  ? FloatingActionButton.extended(
                    heroTag: 'add_account_fab',
                    backgroundColor: AppColors.primary,
                    elevation: 4,
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text(
                      'Nuevo Crédito',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: _openCreateAccountModal,
                  )
                  : null,
          body: RefreshIndicator(
            onRefresh: () => cubit.loadAccounts(forceRefresh: true),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: AdminPageHeader(
                    title: 'Créditos de Proveedores',
                    subtitle:
                        'Gestiona líneas de crédito, pagos y saldos pendientes.',
                    isDesktop: isDesktop,
                    actions: [
                      AdminHeaderButton.primary(
                        label: 'Nuevo Crédito',
                        icon: Icons.add_rounded,
                        tooltip: 'Registrar nuevo crédito',
                        onPressed: _openCreateAccountModal,
                      ),
                    ],
                  ),
                ),
                const SliverToBoxAdapter(child: SupplierCreditsKpiSection()),
                SliverToBoxAdapter(
                  child: SupplierCreditsToolbarSection(
                    isDesktop: isDesktop,
                    searchController: _searchCtrl,
                    searchFocusNode: _searchFocusNode,
                    isTableViewNotifier: _isTableViewNotifier,
                    onSelectTab: (index) => cubit.setWithDebtOnly(index == 1),
                  ),
                ),
                SupplierCreditsContentSection(
                  isWide: isWide,
                  isTableViewNotifier: _isTableViewNotifier,
                  selectedCreditIdNotifier: _selectedCreditIdNotifier,
                  onAccountSelected: _openAccountOptions,
                  onPay: _openPaymentModal,
                  onViewHistory: _navigateToHistory,
                  onCreateAccount: _openCreateAccountModal,
                  onClearFilters: () {
                    _searchCtrl.clear();
                    cubit.clearFilters();
                  },
                ),
                SupplierCreditsPaginationSection(
                  onPageChanged: (page) {
                    cubit.setPage(page);
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
