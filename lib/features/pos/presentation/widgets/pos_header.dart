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
  final VoidCallback? onBack;

  const PosHeader({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.searchByIngredient,
    required this.onToggleIngredientSearch,
    this.onBack,
    this.searchFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      buildWhen: (prev, current) =>
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
        // ── Barra Superior: Título, Estado de Caja y Almacén Activo ────────
        Row(
          children: [
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
              if (onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  tooltip: 'Volver al ERP',
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
            buildWhen: (prev, current) =>
                prev.activeShift != current.activeShift ||
                prev.warehouses != current.warehouses ||
                prev.selectedWarehouseId != current.selectedWarehouseId ||
                prev.isLoading != current.isLoading,
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
                    _buildShiftIndicator(ctx, state, isShiftOpen),
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
                    _buildWarehouseSelector(ctx, state),
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
    if (posState.isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final activeShift = posState.activeShift;
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
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
            accounts:
                cashAccounts, // Pasar estricto las cajas para que el Empty State lo maneje si no hay
          );
          if (opened == true && context.mounted) {
            await context.read<PosCubit>().refreshAccountsAndShift();
            if (context.mounted) {
              context.read<CashShiftsCubit>().fetchShifts();
            }
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isShiftOpen
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isShiftOpen
                    ? AppColors.success.withValues(alpha: 0.35)
                    : AppColors.error.withValues(alpha: 0.3),
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
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
            ],
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
                        : AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseSelector(BuildContext context, PosState posState) {
    if (posState.isLoading) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
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
            SizedBox(width: 10),
            Text(
              'Cargando almacén...',
              style: TextStyle(
                fontSize: 13,
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
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.25),
            width: 0.5,
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
                'Sin almacenes disponibles',
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
              onPressed: () => context.read<PosCubit>().initPosData(forceRefresh: true),
              child: const Text('Reintentar', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

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
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    const activeBlue = Color(0xFF2563EB);
    const activeBorderBlue = Color(0xFF3B82F6);

    return Row(
      children: [
        // ── Selector Segmentado de Modo de Búsqueda (Estilo Captura) ───────────
        Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Modo Producto (Cubo 3D)
              Tooltip(
                message: 'Buscar por Producto (Alt+T)',
                child: InkWell(
                  onTap: () {
                    if (searchByIngredient) onToggleIngredientSearch(false);
                  },
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: !searchByIngredient ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: !searchByIngredient
                          ? Border.all(color: AppColors.border.withValues(alpha: 0.6), width: 1)
                          : null,
                      boxShadow: !searchByIngredient
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
                      size: 20,
                      color: !searchByIngredient ? activeBlue : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // 2. Modo Ingrediente Activo (Matraz químico / Tubo)
              Tooltip(
                message: 'Buscar por Ingrediente Activo (Alt+T)',
                child: InkWell(
                  onTap: () {
                    if (!searchByIngredient) onToggleIngredientSearch(true);
                  },
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: searchByIngredient ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: searchByIngredient
                          ? Border.all(color: AppColors.border.withValues(alpha: 0.6), width: 1)
                          : null,
                      boxShadow: searchByIngredient
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
                      size: 20,
                      color: searchByIngredient ? activeBlue : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // ── Campo de Entrada con Borde Activo y Prefijo Dinámico ───────────────
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: activeBorderBlue,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: activeBorderBlue.withValues(alpha: 0.08),
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
                    onSubmitted: (val) {
                      onSearchChanged(val);
                    },
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: searchByIngredient
                          ? 'Buscar por ingrediente activo...'
                          : 'Buscar producto por nombre o SKU...',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                      // Icono dinámico según el modo seleccionado (Captura 3)
                      prefixIcon: Icon(
                        searchByIngredient
                            ? Icons.science_outlined
                            : Icons.inventory_2_outlined,
                        color: activeBlue,
                        size: 20,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: searchController,
                            builder: (context, value, child) {
                              if (value.text.isEmpty) return const SizedBox.shrink();
                              return IconButton(
                                icon: const Icon(
                                  Icons.cancel_rounded,
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
                          if (isDesktop)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'Alt K',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                // ── Botón de Buscar Explícito ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: FilledButton.icon(
                    onPressed: () {
                      onSearchChanged(searchController.text);
                      searchFocusNode?.unfocus();
                    },
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: Text(isDesktop ? 'Buscar' : ''),
                    style: FilledButton.styleFrom(
                      backgroundColor: activeBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 14 : 10,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
      ],
    );
  }
}
