import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/order_item_model.dart';

class OrderDetailHeaderRow extends StatelessWidget {
  final bool isCompleted;
  final bool isEditing;
  final VoidCallback onToggleEditing;
  final VoidCallback onPrint; // <-- NUEVO PARÁMETRO

  const OrderDetailHeaderRow({
    super.key,
    required this.isCompleted,
    required this.isEditing,
    required this.onToggleEditing,
    required this.onPrint, // <-- NUEVO PARÁMETRO
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Detalle del Pedido',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            // Botón de imprimir siempre visible (o puedes ocultarlo si es PENDING)
            IconButton(
              icon: const Icon(Icons.print_rounded, color: Colors.blueGrey),
              onPressed: onPrint,
              tooltip: 'Imprimir Ticket',
            ),
            if (!isCompleted)
              IconButton(
                icon: Icon(isEditing ? Icons.close : Icons.edit),
                onPressed: onToggleEditing,
                tooltip: isEditing ? 'Cancelar edición' : 'Editar pedido',
              ),
          ],
        ),
      ],
    );
  }
}

class OrderDetailSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const OrderDetailSectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

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
  final TextEditingController searchController;
  final List<Map<String, dynamic>> filteredProfiles;
  final String selectedCustomerLabel;
  final String? selectedCustomerId;
  final VoidCallback onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSelectCustomer;

  const OrderDetailCustomerSection({
    super.key,
    required this.isEditing,
    required this.searchController,
    required this.filteredProfiles,
    required this.selectedCustomerLabel,
    required this.selectedCustomerId,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSelectCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionCard(
      title: 'Cliente',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isEditing)
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar cliente por nombre, teléfono o documento',
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
            )
          else
            OrderDetailInfoBox(value: selectedCustomerLabel),
          if (isEditing) ...[
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
                        separatorBuilder: (_, __) => const Divider(height: 1),
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
        ],
      ),
    );
  }
}

class OrderDetailStatusSection extends StatelessWidget {
  final String currentStatus;
  final bool isEditing;
  final ValueChanged<String?> onChanged;

  const OrderDetailStatusSection({
    super.key,
    required this.currentStatus,
    required this.isEditing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionCard(
      title: 'Estado',
      child: DropdownButtonFormField<String>(
        value: currentStatus,
        decoration: const InputDecoration(
          labelText: 'Estado',
          border: OutlineInputBorder(),
        ),
        items:
            [
              'PENDING',
              'COMPLETED',
              'CANCELLED',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: isEditing ? onChanged : null,
      ),
    );
  }
}

// --- NUEVA SECCIÓN PARA EL MÉTODO DE PAGO ---
class OrderDetailPaymentSection extends StatelessWidget {
  final String currentPaymentMethod;
  final bool isEditing;
  final ValueChanged<String?> onChanged;

  const OrderDetailPaymentSection({
    super.key,
    required this.currentPaymentMethod,
    required this.isEditing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionCard(
      title: 'Método de Pago',
      child:
          isEditing
              ? DropdownButtonFormField<String>(
                value:
                    currentPaymentMethod.isNotEmpty
                        ? currentPaymentMethod
                        : 'EFECTIVO',
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items:
                    [
                          'EFECTIVO',
                          'YAPE',
                          'PLIN',
                          'TARJETA',
                          'TRANSFERENCIA',
                          'POR ACORDAR',
                        ]
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                onChanged: onChanged,
              )
              : OrderDetailInfoBox(
                value:
                    currentPaymentMethod.isNotEmpty
                        ? currentPaymentMethod
                        : 'No registrado',
              ),
    );
  }
}

class OrderDetailPointInfo extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const OrderDetailPointInfo({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class OrderDetailPointsSection extends StatelessWidget {
  final int pointsUsed;
  final int pointsEarned;
  final bool isEditing;
  final TextEditingController pointsUsedController;
  final ValueChanged<String> onPointsUsedChanged;

  const OrderDetailPointsSection({
    super.key,
    required this.pointsUsed,
    required this.pointsEarned,
    required this.isEditing,
    required this.pointsUsedController,
    required this.onPointsUsedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionCard(
      title: 'Monedas',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OrderDetailPointInfo(
                  title: 'Monedas usadas',
                  value: pointsUsed.toString(),
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OrderDetailPointInfo(
                  title: 'Monedas ganadas',
                  value: pointsEarned.toString(),
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: 12),
            TextField(
              controller: pointsUsedController,
              decoration: const InputDecoration(
                labelText: 'Monedas a aplicar al completar',
                helperText:
                    'Solo se descuentan cuando la orden pase a COMPLETED.',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: onPointsUsedChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class OrderDetailTotalSummarySection extends StatelessWidget {
  final double subtotal;
  final int pointsUsed;
  final int pointsEarned;
  final double pointsToSolesRatio;

  const OrderDetailTotalSummarySection({
    super.key,
    required this.subtotal,
    required this.pointsUsed,
    required this.pointsEarned,
    required this.pointsToSolesRatio,
  });

  double get _discountValue => pointsUsed * pointsToSolesRatio;

  double get _totalFinal {
    final total = subtotal - _discountValue;
    return total < 0 ? 0 : total;
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isEmphasized = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isEmphasized ? 15 : 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionCard(
      title: 'Resumen total',
      child: Column(
        children: [
          _buildRow('Subtotal', 'S/ ${subtotal.toStringAsFixed(2)}'),
          _buildRow('Monedas usadas', '$pointsUsed monedas'),
          _buildRow(
            'Descuento por monedas',
            '- S/ ${_discountValue.toStringAsFixed(2)}',
            valueColor: Colors.green.shade800,
          ),
          _buildRow(
            'Total final',
            'S/ ${_totalFinal.toStringAsFixed(2)}',
            isEmphasized: true,
            valueColor: Colors.teal,
          ),
          const SizedBox(height: 6),
          _buildRow('Monedas ganadas', '$pointsEarned monedas'),
        ],
      ),
    );
  }
}

class OrderDetailItemCard extends StatelessWidget {
  final OrderItemModel item;
  final bool isEditing;
  final TextEditingController quantityController;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<String> onQuantityChanged;

  const OrderDetailItemCard({
    super.key,
    required this.item,
    required this.isEditing,
    required this.quantityController,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = item.subtotal;
    final imageUrl = item.displayImageUrl;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child:
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                        imageUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              width: 52,
                              height: 52,
                              color: Colors.teal.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.teal,
                              ),
                            ),
                      )
                      : Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.teal,
                        ),
                      ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName ?? 'Producto sin nombre',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.variantLabel,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SKU: ${item.sku ?? 'N/A'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isEditing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: onDecrease,
                      ),
                      SizedBox(
                        width: 48,
                        child: TextFormField(
                          controller: quantityController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          enabled: isEditing,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                          ),
                          onChanged: onQuantityChanged,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: onIncrease,
                      ),
                    ],
                  )
                else
                  Text(
                    'x${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 6),
                Text(
                  'S/ ${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OrderDetailItemsSection extends StatelessWidget {
  final List<OrderItemModel> items;
  final bool isLoading;
  final bool isEditing;
  final List<TextEditingController> quantityControllers;
  final void Function(int index) onDecrease;
  final void Function(int index) onIncrease;
  final void Function(int index, String value) onQuantityChanged;

  const OrderDetailItemsSection({
    super.key,
    required this.items,
    required this.isLoading,
    required this.isEditing,
    required this.quantityControllers,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionCard(
      title: 'Items',
      child:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return OrderDetailItemCard(
                    item: items[index],
                    isEditing: isEditing,
                    quantityController: quantityControllers[index],
                    onDecrease: () => onDecrease(index),
                    onIncrease: () => onIncrease(index),
                    onQuantityChanged:
                        (value) => onQuantityChanged(index, value),
                  );
                },
              ),
    );
  }
}
