import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/shortcut_utils.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/movement_form_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/open_shift_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/close_shift_sheet.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:go_router/go_router.dart';

class PosHeader extends StatelessWidget {
  static bool _isShiftActionBusy = false;
  static bool _isMovementActionBusy = false;

  final TextEditingController searchController;
  final FocusNode? searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final bool searchByIngredient;
  final ValueChanged<bool> onToggleIngredientSearch;
  final VoidCallback? onScanBarcode;
  final VoidCallback? onBack;

  const PosHeader({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.searchByIngredient,
    required this.onToggleIngredientSearch,
    this.onScanBarcode,
    this.onBack,
    this.searchFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      buildWhen:
          (prev, current) =>
              prev.activeShift != current.activeShift ||
              prev.warehouses != current.warehouses ||
              prev.selectedWarehouseId != current.selectedWarehouseId ||
              prev.isLoading != current.isLoading,
      builder: (context, posState) {
        final isDesktop = MediaQuery.of(context).size.width >= 800;
        if (isDesktop) {
          return _buildDesktopHeader(context, posState);
        }
        return _buildMobileHeader(context, posState);
      },
    );
  }

  Widget _buildDesktopHeader(BuildContext context, PosState posState) {
    final activeShift = posState.activeShift;
    final isShiftOpen = activeShift != null && activeShift.isOpen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Barra Superior: Título, Movimiento, Turno, Almacén y Perfil ────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Caja POS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),

            // ── Botón Registrar Movimiento (Ingreso / Egreso) ───────
            _buildCashMovementButton(context, posState),
            const SizedBox(width: 10),

            // ── Indicador / Control de Turno de Caja ──────────────
            _buildShiftIndicator(context, posState, isShiftOpen),
            const SizedBox(width: 10),

            // ── Selector / Indicador de Almacén (Permiso: warehouses.view_all) ─
            _buildWarehouseSelector(context, posState),
            const SizedBox(width: 10),

            // ── Chip Usuario: Avatar - Nombre - Rol ─────────────────
            _buildUserProfileChip(context),
          ],
        ),
        const SizedBox(height: 12),
        // ── Barra de Búsqueda ──────────────
        _buildSearchBar(context),
      ],
    );
  }

  Widget _buildMobileHeader(BuildContext context, PosState posState) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState.currentUser;
    final fullName =
        user?.fullName.trim().isNotEmpty == true
            ? user!.fullName.trim()
            : 'Usuario';
    final avatarUrl = user?.avatarUrl;
    final names = fullName.split(' ').where((s) => s.isNotEmpty).toList();
    final initials =
        names.isNotEmpty
            ? (names.length >= 2
                ? '${names[0][0]}${names[1][0]}'.toUpperCase()
                : names[0][0].toUpperCase())
            : 'U';

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textPrimary,
                  ),
                  tooltip: 'Volver al ERP',
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.point_of_sale_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Caja POS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              // Avatar con tap a opciones
              GestureDetector(
                onTap: () => _showMobileOptionsSheet(context, posState),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundImage:
                      avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                  child:
                      avatarUrl == null || avatarUrl.isEmpty
                          ? Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          )
                          : null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showMobileOptionsSheet(context, posState),
                icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
                tooltip: 'Opciones de Caja',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchBar(context),
        ],
      ),
    );
  }

  void _showMobileOptionsSheet(BuildContext context, PosState posState) {
    final posCubit = context.read<PosCubit>();
    final cashShiftsCubit = context.read<CashShiftsCubit>();
    final cartCubit = context.read<CartCubit>();
    final authCubit = context.read<AuthCubit>();

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: posCubit),
            BlocProvider.value(value: cashShiftsCubit),
            BlocProvider.value(value: cartCubit),
            BlocProvider.value(value: authCubit),
          ],
          child: BlocBuilder<PosCubit, PosState>(
            buildWhen:
                (prev, current) =>
                    prev.activeShift != current.activeShift ||
                    prev.warehouses != current.warehouses ||
                    prev.selectedWarehouseId != current.selectedWarehouseId ||
                    prev.isLoading != current.isLoading,
            builder: (ctx, state) {
              final activeShift = state.activeShift;
              final isShiftOpen = activeShift != null && activeShift.isOpen;
              final user = authCubit.state.currentUser;
              final fullName =
                  user?.fullName.trim().isNotEmpty == true
                      ? user!.fullName.trim()
                      : 'Usuario';
              final roleName = user?.role ?? 'cajero';
              final roleLabel = AppRoles.getLabel(roleName);
              final avatarUrl = user?.avatarUrl;
              final names =
                  fullName.split(' ').where((s) => s.isNotEmpty).toList();
              final initials =
                  names.isNotEmpty
                      ? (names.length >= 2
                          ? '${names[0][0]}${names[1][0]}'.toUpperCase()
                          : names[0][0].toUpperCase())
                      : 'U';

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSheetDragHandle(
                      padding: EdgeInsets.only(bottom: 16),
                    ),

                    // ── Card de Identidad de Usuario ─────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.15,
                            ),
                            backgroundImage:
                                avatarUrl != null && avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                            child:
                                avatarUrl == null || avatarUrl.isEmpty
                                    ? Text(
                                      initials,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  roleLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Movimientos de Dinero (Ingreso / Egreso) ─────────
                    const Text(
                      'Movimientos de Dinero',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.tealDark,
                              backgroundColor: AppColors.teal.withValues(
                                alpha: 0.08,
                              ),
                              side: BorderSide(
                                color: AppColors.teal.withValues(alpha: 0.3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openCashMovement(
                                context,
                                state,
                                initialType: 'INCOME',
                              );
                            },
                            icon: const Icon(
                              Icons.arrow_downward_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Ingreso',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              backgroundColor: AppColors.danger.withValues(
                                alpha: 0.08,
                              ),
                              side: BorderSide(
                                color: AppColors.danger.withValues(alpha: 0.3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openCashMovement(
                                context,
                                state,
                                initialType: 'EXPENSE',
                              );
                            },
                            icon: const Icon(
                              Icons.arrow_upward_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Egreso',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      'Turno de Caja',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildShiftIndicator(ctx, state, isShiftOpen),
                    const SizedBox(height: 18),

                    const Text(
                      'Almacén Activo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildWarehouseSelector(ctx, state),
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.divider, height: 1),
                    const SizedBox(height: 14),

                    // ── Botón Cerrar Sesión ─────────────────────────────────
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        backgroundColor: AppColors.error.withValues(
                          alpha: 0.06,
                        ),
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.25),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmAndLogout(context);
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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

  Future<void> _confirmAndLogout(BuildContext context) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Cerrar Sesión',
      message: '¿Estás seguro de que deseas salir y cerrar tu sesión?',
      confirmText: 'Cerrar Sesión',
      confirmColor: AppColors.error,
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthCubit>().logout();
    }
  }

  Widget _buildShiftIndicator(
    BuildContext context,
    PosState posState,
    bool isShiftOpen,
  ) {
    if (posState.isLoading &&
        posState.activeShift == null &&
        posState.accounts.isEmpty) {
      return Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Verificando turno...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final activeShift = posState.activeShift;
    final rawName = activeShift?.openedByName?.trim() ?? '';
    final tooltipMsg =
        isShiftOpen
            ? 'Cajero: ${rawName.isNotEmpty ? rawName : "Cajero en turno"} • Apertura: S/ ${activeShift?.openingAmount.toStringAsFixed(2) ?? "0.00"}\n(Clic para cerrar turno)'
            : 'La caja física está cerrada. Clic para abrir turno.';

    return Tooltip(
      message: tooltipMsg,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () async {
          if (_isShiftActionBusy) return;
          _isShiftActionBusy = true;
          try {
            if (isShiftOpen) {
              final shiftsCubit = context.read<CashShiftsCubit>();
              final expected = await shiftsCubit.calcExpected(
                activeShift!.id,
                activeShift.accountId ?? '',
                activeShift.openingAmount,
              );
              if (!context.mounted) return;
              final closed = await CloseShiftSheet.show(
                context,
                shift: activeShift,
                expectedAmount: expected,
              );
              if (closed == true && context.mounted) {
                context.read<PosCubit>().clearActiveShift();
                await context.read<PosCubit>().refreshAccountsAndShift();
                if (context.mounted) {
                  context.read<CashShiftsCubit>().fetchShifts();
                }
              }
            } else {
              final cashAccounts =
                  posState.accounts
                      .where((a) => PosCalculatorUtils.accountRequiresShift(a))
                      .toList();
              final opened = await OpenShiftSheet.show(
                context,
                accounts: cashAccounts,
              );
              if (opened == true && context.mounted) {
                await context.read<PosCubit>().refreshAccountsAndShift();
                if (context.mounted) {
                  context.read<CashShiftsCubit>().fetchShifts();
                }
              }
            }
          } finally {
            _isShiftActionBusy = false;
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color:
                isShiftOpen
                    ? AppColors.success.withValues(alpha: 0.1)
                    : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  isShiftOpen
                      ? AppColors.success.withValues(alpha: 0.4)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isShiftOpen) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ] else ...[
                const Icon(
                  Icons.lock_clock_rounded,
                  size: 16,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                isShiftOpen
                    ? (() {
                      final rawName = activeShift?.openedByName?.trim() ?? '';
                      final firstName =
                          rawName.isNotEmpty ? rawName.split(' ').first : '';
                      return firstName.isNotEmpty
                          ? 'Turno Abierto ($firstName)'
                          : 'Turno Abierto • S/ ${activeShift!.openingAmount.toStringAsFixed(2)}';
                    })()
                    : 'Caja Física Cerrada • Abrir Turno',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      isShiftOpen
                          ? const Color(0xFF065F46)
                          : const Color(0xFF92400E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarehouseSelector(BuildContext context, PosState posState) {
    if (posState.isLoading && posState.warehouses.isEmpty) {
      return Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Cargando almacén...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (posState.warehouses.isEmpty) {
      return Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: AppColors.error,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: const Text(
                'Sin almacenes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              onPressed:
                  () =>
                      context.read<PosCubit>().initPosData(forceRefresh: true),
              child: const Text('Reintentar', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    final canViewAll = context.hasPermission(AppPermissions.warehousesViewAll);
    final currentWh = posState.warehouses.firstWhere(
      (w) => w.id == posState.selectedWarehouseId,
      orElse: () => posState.warehouses.first,
    );

    // Si el usuario no cuenta con el permiso warehouses.view_all o solo hay un almacén:
    // Mostrar pill fijo con candado de asignación
    if (!canViewAll || posState.warehouses.length == 1) {
      return Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.store_mall_directory_rounded,
              size: 17,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                currentWh.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (!canViewAll) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Almacén asignado exclusivamente a tu usuario.',
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Usuario con permiso warehouses.view_all: Dropdown interactivo para alternar
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: MediaQuery.of(context).size.width < 800,
          value:
              posState.selectedWarehouseId ??
              (posState.warehouses.isNotEmpty
                  ? posState.warehouses.first.id
                  : null),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          items:
              posState.warehouses.map((wh) {
                return DropdownMenuItem<String>(
                  value: wh.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warehouse_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(wh.name),
                    ],
                  ),
                );
              }).toList(),
          onChanged: (newWhId) {
            if (newWhId != null && newWhId != posState.selectedWarehouseId) {
              context.read<PosCubit>().setWarehouse(newWhId);

              final cart = context.read<CartCubit>();
              if (cart.state.items.isNotEmpty) {
                cart.clearCart();
                AppSnackbar.show(
                  context,
                  message:
                      'Almacén cambiado. El carrito se vació para sincronizar stocks.',
                  type: SnackbarType.warning,
                );
              } else {
                AppSnackbar.show(
                  context,
                  message: 'Almacén activo cambiado correctamente',
                  type: SnackbarType.info,
                );
              }
            }
          },
        ),
      ),
    );
  }

  // ── Botón Registrar Movimiento (Ingreso / Egreso) ───────────────────────────
  Widget _buildCashMovementButton(BuildContext context, PosState posState) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Registrar movimiento de dinero (Ingreso / Egreso)',
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        onSelected:
            (type) => _openCashMovement(
              context,
              posState,
              initialType: type == 'ANY' ? 'INCOME' : type,
            ),
        itemBuilder:
            (context) => [
              const PopupMenuItem(
                value: 'INCOME',
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      color: AppColors.tealDark,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Registrar Ingreso',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'EXPENSE',
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Registrar Egreso',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'ANY',
                child: Row(
                  children: [
                    Icon(
                      Icons.swap_horiz_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Nuevo Movimiento / Transferencia',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Movimiento',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCashMovement(
    BuildContext context,
    PosState posState, {
    String? initialType,
  }) async {
    if (_isMovementActionBusy) return;
    _isMovementActionBusy = true;

    try {
      String? cashAccountId = posState.activeShift?.accountId;
      if (cashAccountId == null) {
        final cashAcc = posState.accounts.firstWhere(
          (a) => PosCalculatorUtils.accountRequiresShift(a),
          orElse:
              () =>
                  posState.accounts.isNotEmpty
                      ? posState.accounts.first
                      : <String, dynamic>{},
        );
        cashAccountId = cashAcc['id'] as String?;
      }

      final saved = await MovementFormSheet.show(
        context,
        initialType: initialType ?? 'INCOME',
        preselectedAccountId: cashAccountId,
      );

      if (saved == true && context.mounted) {
        context.read<PosCubit>().initPosData(forceRefresh: true);
        if (cashAccountId != null) {
          context.read<PosCubit>().checkActiveShift(cashAccountId);
        }
        AppSnackbar.show(
          context,
          message: 'Movimiento de dinero registrado exitosamente.',
          type: SnackbarType.success,
        );
      }
    } finally {
      _isMovementActionBusy = false;
    }
  }

  // ── Chip Usuario: Avatar - Nombre - Rol ────────────────────────────────────
  Widget _buildUserProfileChip(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState.currentUser;
    final fullName =
        user?.fullName.trim().isNotEmpty == true
            ? user!.fullName.trim()
            : 'Usuario';
    final avatarUrl = user?.avatarUrl;
    final roleName = user?.role ?? 'cajero';
    final roleDisplay = AppRoles.getLabel(roleName);

    final names = fullName.split(' ').where((s) => s.isNotEmpty).toList();
    final initials =
        names.isNotEmpty
            ? (names.length >= 2
                ? '${names[0][0]}${names[1][0]}'.toUpperCase()
                : names[0][0].toUpperCase())
            : 'U';

    return PopupMenuButton<String>(
      tooltip: 'Opciones de Usuario ($fullName)',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: (val) {
        if (val == 'logout') {
          _confirmAndLogout(context);
        }
      },
      itemBuilder:
          (ctx) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    roleDisplay,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                  SizedBox(width: 10),
                  Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage:
                  avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
              child:
                  avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      )
                      : null,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    roleDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    const activeBlue = Color(0xFF2563EB);
    const activeBorderBlue = Color(0xFF3B82F6);

    return Row(
      children: [
        // ── Selector Segmentado de Modo de Búsqueda ───────────
        Container(
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Modo Producto (Cubo 3D)
              Tooltip(
                message: 'Buscar por Producto (${AppShortcutLabels.modPlus}I)',
                child: InkWell(
                  onTap: () {
                    if (searchByIngredient) onToggleIngredientSearch(false);
                  },
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(7),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          !searchByIngredient
                              ? Colors.white
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border:
                          !searchByIngredient
                              ? Border.all(
                                color: AppColors.border.withValues(alpha: 0.6),
                                width: 1,
                              )
                              : null,
                      boxShadow:
                          !searchByIngredient
                              ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                              : null,
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color:
                          !searchByIngredient
                              ? activeBlue
                              : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 3),

              // 2. Modo Ingrediente Activo (Matraz químico / Tubo)
              Tooltip(
                message:
                    'Buscar por Ingrediente Activo (${AppShortcutLabels.modPlus}I)',
                child: InkWell(
                  onTap: () {
                    if (!searchByIngredient) onToggleIngredientSearch(true);
                  },
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(7),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          searchByIngredient
                              ? Colors.white
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border:
                          searchByIngredient
                              ? Border.all(
                                color: AppColors.border.withValues(alpha: 0.6),
                                width: 1,
                              )
                              : null,
                      boxShadow:
                          searchByIngredient
                              ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                              : null,
                    ),
                    child: Icon(
                      Icons.science_outlined,
                      size: 18,
                      color:
                          searchByIngredient ? activeBlue : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // ── Campo de Entrada con Borde Activo y Prefijo Dinámico ───────────────
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: activeBorderBlue, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: activeBorderBlue.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    onSubmitted: (val) {
                      onSearchChanged(val);
                    },
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          searchByIngredient
                              ? 'Buscar por ingrediente activo...'
                              : 'Buscar producto por nombre o SKU...',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        searchByIngredient
                            ? Icons.science_outlined
                            : Icons.inventory_2_outlined,
                        color: activeBlue,
                        size: 18,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: searchController,
                            builder: (context, value, child) {
                              if (value.text.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return IconButton(
                                icon: const Icon(
                                  Icons.cancel_rounded,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: () {
                                  searchController.clear();
                                  onSearchChanged('');
                                },
                                tooltip: 'Borrar búsqueda',
                              );
                            },
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),

                // ── Botón de Buscar Explícito ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: FilledButton.icon(
                    onPressed: () {
                      onSearchChanged(searchController.text);
                      searchFocusNode?.unfocus();
                    },
                    icon: const Icon(Icons.search_rounded, size: 15),
                    label: Text(
                      isDesktop ? 'Buscar' : '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: activeBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 12 : 8,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Botón de Escáner Cámara Barcode / QR ───────────────────────────
        if (onScanBarcode != null) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Escanear código de barras o QR',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onScanBarcode,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 42,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 12 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.teal.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.tealDark,
                        size: 20,
                      ),
                      if (isDesktop) ...[
                        const SizedBox(width: 6),
                        const Text(
                          'Escanear',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tealDark,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

        // ── Indicador de Pistola / Lector Físico Listo ─────────────
        if (isDesktop) ...[
          const SizedBox(width: 8),
          Tooltip(
            message:
                'Receptor de códigos listo. Haz clic para configurar lectores, ver equipos vinculados o calibrar disparos.',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => context.go('/settings?tab=5'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.barcode_reader,
                        color: Color(0xFF059669),
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Lector USB/BT Listo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.tune_rounded,
                        color: Color(0xFF059669),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
