import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/order_detail_components/order_detail_section_card.dart';

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
  final List<Map<String, dynamic>> profiles;
  final String selectedCustomerLabel;
  final String? selectedCustomerId;
  final ValueChanged<String> onSelectCustomer;
  final VoidCallback? onClearCustomer;

  const OrderDetailCustomerSection({
    super.key,
    required this.isEditing,
    required this.isCompleted,
    required this.hasManualName,
    required this.manualNameController,
    required this.profiles,
    required this.selectedCustomerLabel,
    required this.selectedCustomerId,
    required this.onSelectCustomer,
    this.onClearCustomer,
  });

  void _showCustomerSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _CustomerSearchSheet(
            profiles: profiles,
            selectedCustomerId: selectedCustomerId,
            onSelectCustomer: (id) {
              onSelectCustomer(id);
              Navigator.pop(ctx);
            },
          ),
    );
  }

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
                helperText: 'O asigna a un cliente registrado',
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCustomerSearchSheet(context),
              icon: const Icon(Icons.search_rounded),
              label: Text(
                selectedCustomerId != null
                    ? 'Cambiar cliente'
                    : 'Buscar y asignar cliente',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                foregroundColor: Colors.teal.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> profiles;
  final String? selectedCustomerId;
  final ValueChanged<String> onSelectCustomer;

  const _CustomerSearchSheet({
    required this.profiles,
    required this.selectedCustomerId,
    required this.onSelectCustomer,
  });

  @override
  State<_CustomerSearchSheet> createState() => _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends State<_CustomerSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filteredProfiles = [];

  @override
  void initState() {
    super.initState();
    _filteredProfiles = widget.profiles;
    _searchCtrl.addListener(_filterProfiles);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterProfiles() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredProfiles = widget.profiles);
      return;
    }
    setState(() {
      _filteredProfiles =
          widget.profiles.where((p) {
            final name = (p['full_name'] as String? ?? '').toLowerCase();
            final doc = (p['document_number'] as String? ?? '').toLowerCase();
            final phone = (p['phone'] as String? ?? '').toLowerCase();
            return name.contains(q) || doc.contains(q) || phone.contains(q);
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Asignar Cliente',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, teléfono o documento...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon:
                      _searchCtrl.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchCtrl.clear(),
                          )
                          : null,
                ),
              ),
            ),
            Expanded(
              child:
                  _filteredProfiles.isEmpty
                      ? Center(
                        child: Text(
                          'No se encontraron clientes.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _filteredProfiles.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final profile = _filteredProfiles[index];
                          final customerId = profile['id'] as String;
                          final isSelected =
                              customerId == widget.selectedCustomerId;
                          final fullName =
                              (profile['full_name'] as String?)
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? profile['full_name'] as String
                                  : 'Sin nombre';
                          final phone =
                              (profile['phone'] as String?)
                                          ?.trim()
                                          .isNotEmpty ==
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
                            onTap: () => widget.onSelectCustomer(customerId),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
