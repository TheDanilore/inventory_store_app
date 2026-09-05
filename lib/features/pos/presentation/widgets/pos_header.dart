import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/open_shift_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/close_shift_sheet.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';

class PosHeader extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode? searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final bool searchByIngredient;
  final ValueChanged<bool> onToggleIngredientSearch;
  final VoidCallback onBack;

  const PosHeader({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.searchByIngredient,
    required this.onToggleIngredientSearch,
    required this.onBack,
    this.searchFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
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
        // ── Barra Superior: Título, Estado de Caja y Almacén Activo ────────
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
              ),
              tooltip: 'Volver',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
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

            // ── Indicador / Control de Turno de Caja ──────────────
            _buildShiftIndicator(context, posState, isShiftOpen),
            const SizedBox(width: 12),

            // ── Selector de Almacén (Global para POS) ──────────────
            _buildWarehouseSelector(context, posState),
            const SizedBox(width: 12),

            // ── Botón de Operaciones ──────
            IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.textPrimary,
              ),
              tooltip: 'Operaciones de Caja',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ── Barra de Búsqueda ──────────────
        _buildSearchBar(context),
      ],
    );
  }

  Widget _buildMobileHeader(BuildContext context, PosState posState) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
                tooltip: 'Volver',
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ), // Regla 48dp
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border, width: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Caja',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.textPrimary,
                ),
                tooltip: 'Operaciones',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border, width: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showMobileOptionsSheet(context, posState),
                icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
                tooltip: 'Opciones de Caja',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: posCubit),
            BlocProvider.value(value: cashShiftsCubit),
            BlocProvider.value(value: cartCubit),
          ],
          child: BlocBuilder<PosCubit, PosState>(
            builder: (ctx, state) {
              final activeShift = state.activeShift;
              final isShiftOpen = activeShift != null && activeShift.isOpen;

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      'Opciones de Caja',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Turno de Caja',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 56, // Touch area
                      child: _buildShiftIndicator(ctx, state, isShiftOpen),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Almacén Activo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 56,
                      child: _buildWarehouseSelector(ctx, state),
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

  Widget _buildShiftIndicator(
    BuildContext context,
    PosState posState,
    bool isShiftOpen,
  ) {
    final activeShift = posState.activeShift;
    return InkWell(
      onTap: () async {
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
            context.read<PosCubit>().initPosData(forceRefresh: true);
            context.read<CashShiftsCubit>().fetchShifts();
          }
        } else {
          final cashAccounts =
              posState.accounts
                  .where((a) => PosCalculatorUtils.accountRequiresShift(a))
                  .toList();
          final opened = await OpenShiftSheet.show(
            context,
            accounts:
                cashAccounts, // Pasar estricto las cajas para que el Empty State lo maneje si no hay
          );
          if (opened == true && context.mounted) {
            context.read<PosCubit>().initPosData(forceRefresh: true);
            context.read<CashShiftsCubit>().fetchShifts();
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isShiftOpen ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isShiftOpen
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : const Color(0xFFEF4444).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isShiftOpen ? Icons.lock_open_rounded : Icons.lock_clock_rounded,
              size: 16,
              color: isShiftOpen ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 8),
            Text(
              isShiftOpen
                  ? (activeShift?.openedByName != null &&
                          activeShift!.openedByName!.isNotEmpty
                      ? 'Turno Abierto (${activeShift.openedByName})'
                      : 'Turno Abierto • S/ ${activeShift!.openingAmount.toStringAsFixed(2)}')
                  : 'Caja Cerrada • Abrir Turno',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color:
                    isShiftOpen
                        ? const Color(0xFF065F46)
                        : const Color(0xFF991B1B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseSelector(BuildContext context, PosState posState) {
    if (posState.warehouses.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded:
              MediaQuery.of(context).size.width <
              800, // Expand in mobile bottom sheet
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
            fontSize: 14,
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

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      height: 52, // Regla 48dp min, 52 es mejor para touch
      decoration: BoxDecoration(
        color:
            searchByIngredient ? const Color(0xFFECFDF5) : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              searchByIngredient ? const Color(0xFF10B981) : AppColors.border,
          width: searchByIngredient ? 1.5 : 0.5,
        ),
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
          Expanded(
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              onChanged: onSearchChanged,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText:
                    searchByIngredient
                        ? 'Buscar ingrediente activo...'
                        : 'Buscar producto...',
                hintStyle: TextStyle(
                  color:
                      searchByIngredient
                          ? const Color(0xFF6EE7B7)
                          : AppColors.textMuted,
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  searchByIngredient
                      ? Icons.science_rounded
                      : Icons.search_rounded,
                  color:
                      searchByIngredient
                          ? const Color(0xFF10B981)
                          : AppColors.textMuted,
                  size: 22,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, value, child) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(
                        Icons.cancel_rounded,
                        size: 20,
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
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.border),
          Tooltip(
            message: 'Buscar por ingrediente activo',
            child: InkWell(
              onTap: () => onToggleIngredientSearch(!searchByIngredient),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ingrediente',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            searchByIngredient
                                ? const Color(0xFF059669)
                                : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 36,
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color:
                            searchByIngredient
                                ? const Color(0xFF10B981)
                                : AppColors.border,
                      ),
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            left: searchByIngredient ? 18 : 2,
                            top: 2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
