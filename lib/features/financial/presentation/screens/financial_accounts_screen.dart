import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/focus_utils.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements/account_movements_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/account_form_sheet.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/accounts_tab.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/movement_form_sheet.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/movements_tab.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/shifts_tab.dart';

// FINANCIAL ACCOUNTS SCREEN (STRIPE & MERCURY TREASURY DASHBOARD)

class FinancialAccountsScreen extends StatefulWidget {
  const FinancialAccountsScreen({super.key});

  @override
  State<FinancialAccountsScreen> createState() =>
      _FinancialAccountsScreenState();
}

class _FinancialAccountsScreenState extends State<FinancialAccountsScreen>
    with TickerProviderStateMixin {
  late final TabController _mobileTabController;
  late final TabController _tabletTabController;
  final FocusNode _screenFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 3, vsync: this);
    _mobileTabController.addListener(() {
      if (mounted) setState(() {});
    });

    _tabletTabController = TabController(length: 2, vsync: this);
    _tabletTabController.addListener(() {
      if (mounted) setState(() {});
    });

    // Carga inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshAll();
        final profileId = context.read<AuthCubit>().state.currentUser?.id;
        context.read<CashShiftsCubit>().setProfileFilter(profileId);
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    _mobileTabController.dispose();
    _tabletTabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    context.read<FinancialAccountsCubit>().fetchAccounts();
    context.read<AccountMovementsCubit>().fetchMovements(page: 0);
    context.read<CashShiftsCubit>().fetchShifts();
  }

  void _onSelectAccount(FinancialAccountEntity account) {
    final movCubit = context.read<AccountMovementsCubit>();
    setState(() {
      if (_selectedAccountId == account.id) {
        _selectedAccountId = null;
        movCubit.setFilterAccount('Todas');
      } else {
        _selectedAccountId = account.id;
        movCubit.setFilterAccount(account.id);
      }
    });
  }

  void _clearAccountFilter() {
    if (_selectedAccountId != null) {
      setState(() => _selectedAccountId = null);
      context.read<AccountMovementsCubit>().setFilterAccount('Todas');
    }
  }

  bool get _isInputFieldFocused =>
      FocusUtils.isInputFieldFocused(_searchFocusNode);

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isControl = HardwareKeyboard.instance.isControlPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isModifier = isAlt || isControl || isMeta;
    final isTyping = _isInputFieldFocused;

    // Escape: Limpiar filtro de cuenta seleccionada o desenfocar
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (isTyping) {
        _searchFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (_selectedAccountId != null) {
        _clearAccountFilter();
        return KeyEventResult.handled;
      }
    }

    // Si el usuario escribe en un campo de texto, no interceptar ninguna tecla para permitir escritura natural
    if (isTyping) {
      return KeyEventResult.ignored;
    }

    // '/' o Alt+/: Enfocar buscador de movimientos
    if (event.logicalKey == LogicalKeyboardKey.slash && !isModifier) {
      _tabletTabController.animateTo(0);
      _mobileTabController.animateTo(1);
      _searchFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    // 'N' o Ctrl/Alt+N: Nuevo Movimiento (Side Sheet emergente)
    if ((event.logicalKey == LogicalKeyboardKey.keyN && !isModifier) ||
        (isModifier && event.logicalKey == LogicalKeyboardKey.keyN)) {
      MovementFormSheet.show(context);
      return KeyEventResult.handled;
    }

    // 'C' o Alt+C: Nueva Cuenta (Side Sheet emergente)
    if ((event.logicalKey == LogicalKeyboardKey.keyC && !isModifier) ||
        (isAlt && event.logicalKey == LogicalKeyboardKey.keyC)) {
      AccountFormSheet.show(context);
      return KeyEventResult.handled;
    }

    // 'R' o Ctrl/Alt+R: Actualizar
    if ((event.logicalKey == LogicalKeyboardKey.keyR && !isModifier) ||
        (isModifier && event.logicalKey == LogicalKeyboardKey.keyR)) {
      _refreshAll();
      return KeyEventResult.handled;
    }

    // '1', '2', '3': Cambiar pestaña activa
    if (event.logicalKey == LogicalKeyboardKey.digit1 && !isModifier) {
      _tabletTabController.animateTo(0);
      _mobileTabController.animateTo(0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit2 && !isModifier) {
      _tabletTabController.animateTo(1);
      _mobileTabController.animateTo(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit3 && !isModifier) {
      _mobileTabController.animateTo(2);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 768;
        final isDesktop = screenWidth >= 1100;

        return AdminLayout(
          title: 'Cuentas y Bancos',
          showBackButton: true,
          actions: isMobile
              ? [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Actualizar [R]',
                    onPressed: _refreshAll,
                  ),
                ]
              : [
                  FilledButton.icon(
                    onPressed: () => MovementFormSheet.show(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nuevo Movimiento [N]'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => AccountFormSheet.show(context),
                    icon: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 16,
                    ),
                    label: const Text('Nueva Cuenta [C]'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Actualizar [R]',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _refreshAll,
                  ),
                  const SizedBox(width: 4),
                ],
          floatingActionButton: isMobile ? _buildMobileFab() : null,
          body: Focus(
            focusNode: _screenFocusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: isMobile
                ? _buildMobileLayout()
                : _buildDesktopLayout(isDesktop),
          ),
        );
      },
    );
  }

  Widget? _buildMobileFab() {
    final index = _mobileTabController.index;
    if (index == 0) {
      return FloatingActionButton.extended(
        heroTag: 'mobile_fab_accounts',
        onPressed: () => AccountFormSheet.show(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Nueva Cuenta',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }
    if (index == 1) {
      return FloatingActionButton.extended(
        heroTag: 'mobile_fab_movements',
        onPressed: () => MovementFormSheet.show(context),
        backgroundColor: AppColors.teal,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Registrar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }
    return null;
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TabBar(
            controller: _mobileTabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: AppColors.tealDark,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.account_balance_wallet_rounded, size: 16),
                text: 'Cuentas',
                iconMargin: EdgeInsets.only(bottom: 2),
                height: 42,
              ),
              Tab(
                icon: Icon(Icons.swap_horiz_rounded, size: 16),
                text: 'Movimientos',
                iconMargin: EdgeInsets.only(bottom: 2),
                height: 42,
              ),
              Tab(
                icon: Icon(Icons.point_of_sale_rounded, size: 16),
                text: 'Turnos',
                iconMargin: EdgeInsets.only(bottom: 2),
                height: 42,
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _mobileTabController,
            children: [
              AccountsTab(
                showFab: false,
                selectedAccountId: _selectedAccountId,
                onSelectAccount: _onSelectAccount,
              ),
              MovementsTab(
                showFab: false,
                onClearAccountFilter: _clearAccountFilter,
                searchFocusNode: _searchFocusNode,
              ),
              const ShiftsTab(showOpenShiftButton: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(bool isDesktop) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Panel Izquierdo: Cuentas Financieras (Master) ───────────
        SizedBox(
          width: isDesktop ? 390 : 330,
          child: AccountsTab(
            showFab: false,
            selectedAccountId: _selectedAccountId,
            onSelectAccount: _onSelectAccount,
            onSelectAll: _clearAccountFilter,
          ),
        ),

        // ── Divisor sutil ──────────────────────────────────────────
        Container(width: 1, color: AppColors.border),

        // ── Panel Derecho: Movimientos y Turnos (Detail) ───────────
        Expanded(
          child: Column(
            children: [
              // Barra de pestañas elegante y plana
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TabBar(
                  controller: _tabletTabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A0F172A),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.tealDark,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.swap_horiz_rounded, size: 16),
                      text: 'Movimientos Recientes [1]',
                      iconMargin: EdgeInsets.only(bottom: 2),
                      height: 42,
                    ),
                    Tab(
                      icon: Icon(Icons.point_of_sale_rounded, size: 16),
                      text: 'Turnos de Caja [2]',
                      iconMargin: EdgeInsets.only(bottom: 2),
                      height: 42,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabletTabController,
                  children: [
                    MovementsTab(
                      showFab: false,
                      onClearAccountFilter: _clearAccountFilter,
                      searchFocusNode: _searchFocusNode,
                    ),
                    const ShiftsTab(showOpenShiftButton: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
