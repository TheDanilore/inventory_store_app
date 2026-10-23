import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
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

/// Pantalla Principal de Cuentas y Tesorería Financiera (ERP)
///
/// Arquitectura Master-Detail responsiva:
/// - Desktop/Tablet: Panel izquierdo fijo con Cuentas (Master) + Panel derecho con Movimientos y Turnos (Detail).
/// - Móvil: Pestañas segmentadas inferiores (Cuentas, Movimientos, Turnos).
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

    // Carga inicial coordinada
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

  Future<void> _openAccountForm() async {
    final res = await AccountFormSheet.show(context);
    if (res == true && mounted) {
      _refreshAll();
    }
  }

  void _navigateToTab(int unifiedIndex) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (isMobile) {
      if (unifiedIndex >= 0 && unifiedIndex < _mobileTabController.length) {
        _mobileTabController.animateTo(unifiedIndex);
      }
    } else {
      // En desktop: 0 -> Cuentas ya está en pantalla, 1 -> Movimientos (índice 0), 2 -> Turnos (índice 1)
      if (unifiedIndex == 1) {
        _tabletTabController.animateTo(0);
      } else if (unifiedIndex == 2) {
        _tabletTabController.animateTo(1);
      }
    }
  }

  bool get _isInputFieldFocused =>
      FocusUtils.isInputFieldFocused(_searchFocusNode);

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isControl = HardwareKeyboard.instance.isControlPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
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

    // '?' o Shift+/: Ver atajos de teclado
    if (event.logicalKey == LogicalKeyboardKey.slash && isShift) {
      _showShortcutsDialog();
      return KeyEventResult.handled;
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
      _openAccountForm();
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
      _navigateToTab(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit2 && !isModifier) {
      _navigateToTab(2);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit3 && !isModifier) {
      _navigateToTab(0);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _showShortcutsDialog() {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.keyboard_outlined,
                  color: AppColors.tealDark,
                  size: 22,
                ),
                SizedBox(width: 10),
                Text(
                  'Atajos de Teclado',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildShortcutRow('N', 'Registrar nuevo movimiento financiero'),
                _buildShortcutRow('C', 'Crear nueva cuenta o caja'),
                _buildShortcutRow('R', 'Actualizar datos y saldos'),
                _buildShortcutRow(
                  '/',
                  'Enfocar barra de búsqueda de movimientos',
                ),
                _buildShortcutRow('1', 'Pestaña: Movimientos recientes'),
                _buildShortcutRow('2', 'Pestaña: Turnos de caja'),
                _buildShortcutRow(
                  'Esc',
                  'Limpiar filtro de cuenta o desenfocar',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Entendido',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildShortcutRow(String keyChar, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _KbdBadge(keyChar),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.currentUser;
    final canManageAccounts =
        user?.isAdmin == true ||
        (user?.hasPermission(AppPermissions.financialAccountsManage) ?? false);
    final canCreateMovements =
        user?.isAdmin == true ||
        (user?.hasPermission(AppPermissions.financialMovementsCreate) ?? false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 768;
        final isDesktop = screenWidth >= 1100;

        return AdminLayout(
          title: 'Cuentas y Bancos',
          actions:
              isMobile
                  ? [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Actualizar [R]',
                      onPressed: _refreshAll,
                    ),
                  ]
                  : [
                    if (canCreateMovements)
                      FilledButton.icon(
                        onPressed: () => MovementFormSheet.show(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Nuevo Movimiento'),
                            SizedBox(width: 8),
                            _KbdBadge('N', isPrimary: true),
                          ],
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    if (canCreateMovements && canManageAccounts)
                      const SizedBox(width: 8),
                    if (canManageAccounts)
                      OutlinedButton.icon(
                        onPressed: _openAccountForm,
                        icon: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 16,
                        ),
                        label: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Nueva Cuenta'),
                            SizedBox(width: 8),
                            _KbdBadge('C'),
                          ],
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Atajos de teclado [?]',
                      icon: const Icon(Icons.keyboard_outlined, size: 20),
                      onPressed: _showShortcutsDialog,
                    ),
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
            child:
                isMobile
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
        onPressed: _openAccountForm,
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
          width: isDesktop ? 380 : 340,
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
              // Cabecera segmentada compacta y elegante
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TabBar(
                        controller: _tabletTabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F0F172A),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: AppColors.tealDark,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
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
                            height: 36,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swap_horiz_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Movimientos Recientes'),
                                SizedBox(width: 6),
                                _KbdBadge('1'),
                              ],
                            ),
                          ),
                          Tab(
                            height: 36,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.point_of_sale_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Turnos de Caja'),
                                SizedBox(width: 6),
                                _KbdBadge('2'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_selectedAccountId != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.teal.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.filter_alt_rounded,
                              size: 13,
                              color: AppColors.tealDark,
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Filtro de cuenta activo',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.tealDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _clearAccountFilter,
                              borderRadius: BorderRadius.circular(10),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 13,
                                  color: AppColors.tealDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

/// Badge estilo tecla de teclado moderna (`<kbd>`) para atajos rápidos en UI.
class _KbdBadge extends StatelessWidget {
  final String text;
  final bool isPrimary;

  const _KbdBadge(this.text, {this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isPrimary
            ? Colors.white.withValues(alpha: 0.22)
            : const Color(0xFFF1F5F9);

    final textColor = isPrimary ? Colors.white : const Color(0xFF475569);

    final borderColor =
        isPrimary
            ? Colors.white.withValues(alpha: 0.4)
            : const Color(0xFFCBD5E1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor, width: 0.9),
        boxShadow:
            isPrimary
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
