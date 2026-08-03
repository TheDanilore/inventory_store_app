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
                  tooltip: 'Volver al Menú Principal',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radius),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.point_of_sale_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Caja POS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),

                // ── Indicador / Control de Turno de Caja ──────────────
                InkWell(
                  onTap: () async {
                    if (isShiftOpen) {
                      final shiftsCubit = context.read<CashShiftsCubit>();
                      final expected = await shiftsCubit.calcExpected(
                        activeShift.id,
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
                      final cashAccounts = posState.accounts
                          .where((a) =>
                              (a['type']?.toString().toLowerCase() == 'caja' ||
                               a['type']?.toString().toLowerCase() == 'cash'))
                          .toList();
                      final opened = await OpenShiftSheet.show(
                        context,
                        accounts: cashAccounts.isNotEmpty
                            ? cashAccounts
                            : posState.accounts,
                      );
                      if (opened == true && context.mounted) {
                        context.read<PosCubit>().initPosData(forceRefresh: true);
                        context.read<CashShiftsCubit>().fetchShifts();
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isShiftOpen
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isShiftOpen
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isShiftOpen
                              ? Icons.lock_open_rounded
                              : Icons.lock_clock_rounded,
                          size: 14,
                          color: isShiftOpen
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isShiftOpen
                              ? 'Turno Abierto • S/ ${activeShift.openingAmount.toStringAsFixed(2)}'
                              : '⚠️ Caja Cerrada • Abrir Turno',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isShiftOpen
                                ? const Color(0xFF065F46)
                                : const Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // ── Selector de Almacén (Global para POS) ──────────────
                if (posState.warehouses.isNotEmpty)
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppColors.radius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: posState.selectedWarehouseId ??
                            (posState.warehouses.isNotEmpty
                                ? posState.warehouses.first.id
                                : null),
                        icon: const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppColors.textSecondary,
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        items: posState.warehouses.map((wh) {
                          return DropdownMenuItem<String>(
                            value: wh.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.warehouse_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(wh.name),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newWhId) {
                          if (newWhId != null &&
                              newWhId != posState.selectedWarehouseId) {
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
                  ),
                const SizedBox(width: 10),

                // ── Botón de Operaciones (Borradores y Ventas Recientes) ──────
                IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Ventas Recientes y Borradores',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radius),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Barra de Búsqueda y Filtros Rápidos ──────────────
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: searchByIngredient
                    ? const Color(0xFFECFDF5)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(AppColors.radius),
                border: Border.all(
                  color: searchByIngredient
                      ? const Color(0xFF10B981)
                      : AppColors.border,
                  width: searchByIngredient ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      focusNode: searchFocusNode,
                      onChanged: onSearchChanged,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: searchByIngredient
                            ? 'Ej: Glifosato, Clorpirifos, Paracetamol...'
                            : 'Buscar producto en caja...',
                        hintStyle: TextStyle(
                          color: searchByIngredient
                              ? const Color(0xFF6EE7B7)
                              : AppColors.textMuted,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          searchByIngredient
                              ? Icons.science_rounded
                              : Icons.search_rounded,
                          color: searchByIngredient
                              ? const Color(0xFF10B981)
                              : AppColors.textMuted,
                          size: 20,
                        ),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: searchController,
                          builder: (context, value, child) {
                            if (value.text.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
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
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Buscar por ingrediente activo',
                    child: InkWell(
                      onTap: () =>
                          onToggleIngredientSearch(!searchByIngredient),
                      child: Container(
                        padding: const EdgeInsets.only(left: 8, right: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ingrediente',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: searchByIngredient
                                    ? const Color(0xFF059669)
                                    : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 32,
                              height: 18,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                color: searchByIngredient
                                    ? const Color(0xFF10B981)
                                    : AppColors.border,
                              ),
                              child: Stack(
                                children: [
                                  AnimatedPositioned(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    left: searchByIngredient ? 16 : 2,
                                    top: 2,
                                    child: Container(
                                      width: 14,
                                      height: 14,
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
            ),
          ],
        );
      },
    );
  }
}
