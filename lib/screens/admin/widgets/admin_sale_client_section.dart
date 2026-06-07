import 'package:flutter/material.dart';

typedef ClientTapCallback = void Function(Map<String, dynamic> client);

class AdminSaleClientSection extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSearchChanged;
  final bool searching;
  final List<Map<String, dynamic>> matches;
  final String? selectedClientId;
  final ClientTapCallback onClientTap;
  final int saldoActualCliente;

  const AdminSaleClientSection({
    super.key,
    required this.controller,
    required this.onSearchChanged,
    required this.searching,
    required this.matches,
    required this.selectedClientId,
    required this.onClientTap,
    required this.saldoActualCliente,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cliente', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre, telefono o documento',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          if (searching)
            const LinearProgressIndicator(minHeight: 2)
          else if (selectedClientId != null)
            // NUEVO: Mostramos un mensaje claro de éxito
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Cliente seleccionado correctamente.',
                  style: TextStyle(
                    fontSize: 13, 
                    color: Colors.green.shade700, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            )
          else if (controller.text.trim().isEmpty)
            const Text(
              'Escribe para buscar clientes existentes.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )
          else if (matches.isEmpty)
            const Text(
              'No se encontraron coincidencias.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: matches.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final client = matches[index];
                  final clientName = client['full_name'] as String? ?? 'Cliente';
                  final docNumber = client['document_number'] as String?;
                  final phone = client['phone'] as String?;
                  final isSelected = selectedClientId == client['id'];

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    selected: isSelected,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.teal.withValues(alpha: 0.12),
                      child: const Icon(Icons.person, size: 16),
                    ),
                    title: Text(
                      clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (docNumber != null && docNumber.isNotEmpty) 'Doc: $docNumber',
                        if (phone != null && phone.isNotEmpty) 'Tel: $phone',
                      ].join(' | '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.chevron_right),
                    onTap: () => onClientTap(client),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
