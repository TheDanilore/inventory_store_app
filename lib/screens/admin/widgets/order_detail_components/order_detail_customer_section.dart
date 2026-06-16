import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_components/order_detail_section_card.dart';

class OrderDetailInfoBox extends StatelessWidget {
  final String value;
  const OrderDetailInfoBox({super.key, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(value),
    );
  }
}

class OrderDetailCustomerSection extends StatelessWidget {
  final bool isEditing;
  final bool isCompleted;
  final bool hasManualName;
  final TextEditingController manualNameController;
  final TextEditingController searchController;
  final List<Map<String, dynamic>> filteredProfiles;
  final String selectedCustomerLabel;
  final String? selectedCustomerId;
  final VoidCallback onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSelectCustomer;
  final VoidCallback? onClearCustomer;

  const OrderDetailCustomerSection({
    super.key,
    required this.isEditing,
    required this.isCompleted,
    required this.hasManualName,
    required this.manualNameController,
    required this.searchController,
    required this.filteredProfiles,
    required this.selectedCustomerLabel,
    required this.selectedCustomerId,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSelectCustomer,
    this.onClearCustomer,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return OrderDetailSectionCard(
        title: 'Cliente',
        child: OrderDetailInfoBox(value: selectedCustomerLabel),
      );
    }

    final bool showingManualField = hasManualName && selectedCustomerId == null;

    return OrderDetailSectionCard(
      title: 'Cliente',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showingManualField) ...[
            TextField(
              controller: manualNameController,
              decoration: const InputDecoration(
                hintText: 'Nombre del cliente (opcional)',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
                helperText:
                    'O busca abajo para asociar a un cliente registrado',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Asociar a cliente registrado',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
          ],

          if (selectedCustomerId != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    color: Colors.teal,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedCustomerLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (onClearCustomer != null)
                    IconButton(
                      icon: Icon(
                        Icons.link_off,
                        color: Colors.grey.shade500,
                        size: 18,
                      ),
                      tooltip: 'Desvincular cliente',
                      onPressed: onClearCustomer,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Cambiar cliente',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
          ],

          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, teléfono o documento',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon:
                  searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onClearSearch,
                      )
                      : null,
            ),
            onChanged: (_) => onSearchChanged(),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                filteredProfiles.isEmpty
                    ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'No se encontraron clientes.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                    : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredProfiles.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final profile = filteredProfiles[index];
                        final customerId = profile['id'] as String;
                        final isSelected = customerId == selectedCustomerId;
                        final fullName =
                            (profile['full_name'] as String?)
                                        ?.trim()
                                        .isNotEmpty ==
                                    true
                                ? profile['full_name'] as String
                                : 'Sin nombre';
                        final phone =
                            (profile['phone'] as String?)?.trim().isNotEmpty ==
                                    true
                                ? profile['phone'] as String
                                : null;
                        final document =
                            (profile['document_number'] as String?)
                                        ?.trim()
                                        .isNotEmpty ==
                                    true
                                ? profile['document_number'] as String
                                : null;

                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: Colors.teal.withValues(
                            alpha: 0.08,
                          ),
                          title: Text(fullName),
                          subtitle:
                              phone != null || document != null
                                  ? Text(
                                    [
                                      if (phone != null) 'Tel: $phone',
                                      if (document != null) 'Doc: $document',
                                    ].join('  |  '),
                                  )
                                  : null,
                          trailing:
                              isSelected
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.teal,
                                  )
                                  : null,
                          onTap: () => onSelectCustomer(customerId),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
