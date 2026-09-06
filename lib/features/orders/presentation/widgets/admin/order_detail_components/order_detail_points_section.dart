import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_section_card.dart';

class OrderDetailPointInfo extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const OrderDetailPointInfo({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                  color: AppColors.error,
                  icon: Icons.stars_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OrderDetailPointInfo(
                  title: 'Descuento',
                  value:
                      'S/ ${(_localPointsUsed * widget.pointsToSolesRatio).toStringAsFixed(2)}',
                  color: AppColors.teal,
                  icon: Icons.savings_rounded,
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
