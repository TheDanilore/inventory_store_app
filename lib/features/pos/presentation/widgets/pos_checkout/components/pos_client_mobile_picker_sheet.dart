import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/components/pos_client_list_tile.dart';

/// Modal BottomSheet nativo estilo Apple HIG para seleccionar cliente en móviles.
class PosClientMobilePickerSheet {
  const PosClientMobilePickerSheet._();

  static void show({
    required BuildContext context,
    required bool searching,
    required List<Map<String, dynamic>> matches,
    required String? selectedClientId,
    required bool isLoyaltyEnabled,
    required ValueChanged<String> onSearchChanged,
    required VoidCallback onClearClient,
    required ValueChanged<Map<String, dynamic>> onClientTap,
    required VoidCallback onCreateCustomer,
  }) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // iOS Drag Handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Título y botón cerrar
                      Row(
                        children: [
                          const Icon(
                            Icons.person_search_rounded,
                            color: AppColors.teal,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Seleccionar Cliente',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(bottomSheetCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Input buscador
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          autofocus: true,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: const InputDecoration(
                            hintText: 'Buscar por nombre, DNI o teléfono…',
                            prefixIcon: Icon(Icons.search_rounded, size: 18),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (val) {
                            onSearchChanged(val);
                            setModalState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Opción Cliente Varios
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey.shade200,
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                        title: const Text(
                          'Cliente Varios (Venta rápida)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        subtitle: const Text(
                          'Venta genérica sin registrar datos',
                          style: TextStyle(fontSize: 11.5),
                        ),
                        onTap: () {
                          onClearClient();
                          Navigator.pop(bottomSheetCtx);
                        },
                      ),
                      const Divider(height: 1),
                      // Lista de resultados
                      Expanded(
                        child:
                            searching
                                ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.teal,
                                  ),
                                )
                                : matches.isEmpty
                                ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person_off_outlined,
                                          size: 36,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'No se encontraron clientes',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : ListView.separated(
                                  itemCount: matches.length,
                                  separatorBuilder:
                                      (_, _) => const Divider(height: 1),
                                  itemBuilder: (context, idx) {
                                    final c = matches[idx];
                                    return PosClientListTile(
                                      client: c,
                                      isSelected: c['id'] == selectedClientId,
                                      isLoyaltyEnabled: isLoyaltyEnabled,
                                      onTap: () {
                                        onClientTap(c);
                                        Navigator.pop(bottomSheetCtx);
                                      },
                                    );
                                  },
                                ),
                      ),
                      // Botón Nuevo Cliente
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Crear Nuevo Cliente Express',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.pop(bottomSheetCtx);
                              onCreateCustomer();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
