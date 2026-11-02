import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/domain/entities/auth_user_entity.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/header/pos_cash_movement_button.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/header/pos_mobile_options_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/header/pos_search_bar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/header/pos_shift_action_chip.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/header/pos_user_profile_chip.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/header/pos_warehouse_selector.dart';

class PosHeader extends StatelessWidget {
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
            PosCashMovementButton(posState: posState),
            const SizedBox(width: 10),

            // ── Indicador / Control de Turno de Caja ──────────────
            PosShiftActionChip(posState: posState, isShiftOpen: isShiftOpen),
            const SizedBox(width: 10),

            // ── Selector / Indicador de Almacén ───────────────────
            PosWarehouseSelector(posState: posState),
            const SizedBox(width: 10),

            // ── Chip Usuario: Avatar - Nombre - Rol ─────────────────
            const PosUserProfileChip(),
          ],
        ),
        const SizedBox(height: 12),
        // ── Barra de Búsqueda ──────────────
        PosSearchBar(
          searchController: searchController,
          searchFocusNode: searchFocusNode,
          onSearchChanged: onSearchChanged,
          searchByIngredient: searchByIngredient,
          onToggleIngredientSearch: onToggleIngredientSearch,
          onScanBarcode: onScanBarcode,
        ),
      ],
    );
  }

  Widget _buildMobileHeader(BuildContext context, PosState posState) {
    return BlocSelector<AuthCubit, AuthState, AuthUserEntity?>(
      selector: (state) => state.currentUser,
      builder: (context, user) {
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
                    onTap: () => PosMobileOptionsSheet.show(context, posState),
                    child: CircleAvatar(
                      radius: 17,
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
                    onPressed:
                        () => PosMobileOptionsSheet.show(context, posState),
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.primary,
                    ),
                    tooltip: 'Opciones de Caja',
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
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
              PosSearchBar(
                searchController: searchController,
                searchFocusNode: searchFocusNode,
                onSearchChanged: onSearchChanged,
                searchByIngredient: searchByIngredient,
                onToggleIngredientSearch: onToggleIngredientSearch,
                onScanBarcode: onScanBarcode,
              ),
            ],
          ),
        );
      },
    );
  }
}
