import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/shortcut_utils.dart';

class PosSearchBar extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode? searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final bool searchByIngredient;
  final ValueChanged<bool> onToggleIngredientSearch;
  final VoidCallback? onScanBarcode;

  const PosSearchBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.searchByIngredient,
    required this.onToggleIngredientSearch,
    this.searchFocusNode,
    this.onScanBarcode,
  });

  @override
  Widget build(BuildContext context) {
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
