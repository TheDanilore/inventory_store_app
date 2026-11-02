import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/shortcut_utils.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_date_preset_selector.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_search_input.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_type_filter_row.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_view_toggle.dart';

/// Barra superior de comandos y filtros de Kárdex para Desktop / Tablet.
/// Diseñada con aislamiento de rebuilds mediante `BlocSelector`.
class KardexDesktopCommandBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final FocusNode searchFocusNode;
  final bool isDesktop;
  final bool isLedgerView;
  final String activeDatePreset;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback onClearSearch;
  final ValueChanged<bool> onToggleView;
  final ValueChanged<String> onSelectDatePreset;
  final VoidCallback onOpenEntry;
  final VoidCallback onOpenExit;

  const KardexDesktopCommandBar({
    super.key,
    required this.searchCtrl,
    required this.searchFocusNode,
    required this.isDesktop,
    required this.isLedgerView,
    required this.activeDatePreset,
    required this.onSearchChanged,
    this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onToggleView,
    required this.onSelectDatePreset,
    required this.onOpenEntry,
    required this.onOpenExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Buscador compacto estilo Linear
              Expanded(
                flex: 3,
                child: BlocSelector<KardexCubit, KardexState, bool>(
                  selector:
                      (state) => state is KardexLoaded && state.isSearching,
                  builder: (context, isSearching) {
                    return KardexSearchInput(
                      controller: searchCtrl,
                      focusNode: searchFocusNode,
                      hint:
                          'Buscar producto, variante o SKU... (${AppShortcutLabels.modPlus}K)',
                      isLoading: isSearching,
                      onChanged: onSearchChanged,
                      onSubmitted: onSearchSubmitted,
                      onClear: onClearSearch,
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),

              // Presets de Fecha Dropdown / Popover
              KardexDatePresetSelector(
                activePreset: activeDatePreset,
                onSelected: onSelectDatePreset,
              ),
              const SizedBox(width: 8),

              // Toggle de Vista (Cards vs Tabla Ledger)
              KardexViewToggle(
                isLedgerView: isLedgerView,
                onToggleView: onToggleView,
              ),
              const SizedBox(width: 8),

              // Botón Exportar PDF
              BlocSelector<KardexCubit, KardexState, bool>(
                selector: (state) => state is KardexLoaded && state.isExporting,
                builder: (context, isExporting) {
                  return Tooltip(
                    message: 'Exportar Kárdex en PDF (Ctrl+P)',
                    child: OutlinedButton.icon(
                      onPressed:
                          isExporting
                              ? null
                              : () => context.read<KardexCubit>().exportToPdf(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon:
                          isExporting
                              ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                              : const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 16,
                                color: AppColors.primary,
                              ),
                      label: Text(
                        isDesktop ? 'Exportar' : '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // Botón Ingreso
              ElevatedButton.icon(
                onPressed: onOpenEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade50,
                  foregroundColor: Colors.green.shade700,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.green.shade200),
                  ),
                ),
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ingreso',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'E',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Botón Salida
              ElevatedButton.icon(
                onPressed: onOpenExit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                ),
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Salida',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'S',
                          style: TextStyle(
                            fontSize: 10,
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
          const SizedBox(height: 10),

          // Chips de Filtro por Tipo de Operación
          const KardexTypeFilterRow(),
        ],
      ),
    );
  }
}
