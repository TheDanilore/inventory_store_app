import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_section_card.dart';

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

class OrderDetailPointsSection extends StatefulWidget {
  final int pointsUsed;
  final bool isEditing;
  final TextEditingController pointsUsedCtrl;
  final int maxPointsAvailable;
  final double pointsToSolesRatio;
  final ValueChanged<String> onPointsChanged;

  const OrderDetailPointsSection({
    super.key,
    required this.pointsUsed,
    required this.isEditing,
    required this.pointsUsedCtrl,
    required this.maxPointsAvailable,
    required this.pointsToSolesRatio,
    required this.onPointsChanged,
  });

  @override
  State<OrderDetailPointsSection> createState() =>
      _OrderDetailPointsSectionState();
}

class _OrderDetailPointsSectionState extends State<OrderDetailPointsSection> {
  final _formKey = GlobalKey<FormState>();
  late int _localPointsUsed;

  @override
  void initState() {
    super.initState();
    _localPointsUsed = widget.pointsUsed;
  }

  @override
  void didUpdateWidget(covariant OrderDetailPointsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pointsUsed != oldWidget.pointsUsed) {
      _localPointsUsed = widget.pointsUsed;
    }
  }

  void _handleChanged(String val) {
    final pts = int.tryParse(val) ?? 0;
    setState(() {
      _localPointsUsed = pts;
    });

    if (_formKey.currentState?.validate() ?? false) {
      widget.onPointsChanged(val);
    }
  }

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
                  value: _localPointsUsed.toString(),
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OrderDetailPointInfo(
                  title: 'Descuento',
                  value:
                      'S/ ${(_localPointsUsed * widget.pointsToSolesRatio).toStringAsFixed(2)}',
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          if (widget.isEditing) ...[
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: widget.pointsUsedCtrl,
                decoration: InputDecoration(
                  labelText:
                      'Monedas a aplicar (Max: ${widget.maxPointsAvailable})',
                  helperText:
                      'Solo se descuentan cuando la orden pase a COMPLETED.',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _handleChanged,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Requerido';
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null) return 'Valor inválido';
                  if (parsed < 0) return 'No puede ser negativo';
                  if (parsed > widget.maxPointsAvailable) {
                    return 'Supera el máximo permitido (${widget.maxPointsAvailable})';
                  }
                  return null;
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
