import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/components/pos_client_list_tile.dart';

/// Popover flotante de alto rendimiento para búsqueda de clientes en Desktop/Tablet.
///
/// Optimizado para evitar desbordes y virtualizar el scroll sin `shrinkWrap`.
class PosClientSearchPopover extends StatelessWidget {
  final double cardWidth;
  final bool hasClient;
  final String? selectedClientId;
  final TextEditingController searchFieldCtrl;
  final FocusNode searchFocusNode;
  final bool searching;
  final List<Map<String, dynamic>> matches;
  final bool isLoyaltyEnabled;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onClose;
  final VoidCallback onClearClient;
  final ValueChanged<Map<String, dynamic>> onClientTap;
  final void Function([String? query]) onCreateCustomer;

  const PosClientSearchPopover({
    super.key,
    required this.cardWidth,
    required this.hasClient,
    required this.selectedClientId,
    required this.searchFieldCtrl,
    required this.searchFocusNode,
    required this.searching,
    required this.matches,
    required this.isLoyaltyEnabled,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onClose,
    required this.onClearClient,
    required this.onClientTap,
    required this.onCreateCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardWidth,
      child: Material(
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de búsqueda con auto-focus y tecla Esc
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        onClose();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: searchFieldCtrl,
                      focusNode: searchFocusNode,
                      onChanged: onSearchChanged,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, DNI o teléfono…',
                        hintStyle: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textMuted,
                          size: 16,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (searchFieldCtrl.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel_rounded,
                                  size: 16,
                                ),
                                color: AppColors.textMuted,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                tooltip: 'Borrar texto',
                                onPressed: onClearSearch,
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                color: AppColors.textMuted,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                tooltip: 'Cerrar (Esc)',
                                onPressed: onClose,
                              ),
                          ],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // Contenido scrolleable acotado con virtualización
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: _buildScrollableResults(),
              ),

              // Pie del popover con atajo y botón nuevo
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(11),
                  ),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Crear cliente rápido',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => onCreateCustomer(),
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text(
                        'Nuevo cliente',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableResults() {
    final query = searchFieldCtrl.text.trim();

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: [
        // Opción: Cliente Varios (Venta rápida sin datos)
        InkWell(
          onTap: () {
            onClearClient();
            onClose();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    Icons.people_outline_rounded,
                    size: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Cliente Varios',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Venta rápida sin comprobante con datos',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!hasClient)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.teal,
                  ),
              ],
            ),
          ),
        ),

        const Divider(height: 1, color: AppColors.divider),

        if (searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.teal,
                ),
              ),
            ),
          )
        else if (matches.isNotEmpty) ...[
          for (int i = 0; i < matches.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.divider),
            PosClientListTile(
              client: matches[i],
              isSelected: matches[i]['id'] == selectedClientId,
              isLoyaltyEnabled: isLoyaltyEnabled,
              onTap: () {
                onClientTap(matches[i]);
                onClose();
              },
            ),
          ],
        ] else if (query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 16,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No se encontró "$query".',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => onCreateCustomer(query),
                  child: const Text('Crear', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
