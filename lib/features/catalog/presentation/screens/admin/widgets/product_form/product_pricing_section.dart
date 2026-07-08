import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/catalog/presentation/providers/product_form_provider.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';

class ProductPricingSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;

  const ProductPricingSection({super.key, required this.formKey});

  double? _parseDecimal(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String? _validateUnitCost(String? value) {
    final parsed = _parseDecimal(value ?? '');
    if (parsed == null) return 'Ingresa un costo valido';
    if (parsed <= 0) return 'El costo debe ser mayor a 0';
    return null;
  }

  String? _validateSalePrice(String? value, String unitCostText) {
    final salePrice = _parseDecimal(value ?? '');
    if (salePrice == null) return 'Ingresa un precio de venta valido';
    if (salePrice <= 0) return 'El precio de venta debe ser mayor a 0';

    final unitCost = _parseDecimal(unitCostText);
    if (unitCost != null && salePrice < unitCost) {
      return 'El precio de venta no puede ser menor al costo';
    }
    return null;
  }

  String? _validateWholesalePrice(
    String? value,
    String unitCostText,
    String salePriceText,
  ) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final wholesalePrice = _parseDecimal(text);
    if (wholesalePrice == null) return 'Ingresa un precio mayorista valido';
    if (wholesalePrice <= 0) return 'El precio mayorista debe ser mayor a 0';

    final unitCost = _parseDecimal(unitCostText);
    if (unitCost != null && wholesalePrice < unitCost) {
      return 'El precio mayorista no puede ser menor al costo';
    }

    final salePrice = _parseDecimal(salePriceText);
    if (salePrice != null && wholesalePrice > salePrice) {
      return 'El precio mayorista no puede ser mayor al precio de venta';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductFormProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Precios e Inventario',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: provider.costoCtrl,
                  label: 'Costo (S/.)',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  validator: _validateUnitCost,
                  onChanged: (_) => formKey.currentState?.validate(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: provider.precioCtrl,
                  label: 'Precio Venta (S/.)',
                  icon: Icons.sell_outlined,
                  keyboardType: TextInputType.number,
                  validator:
                      (val) => _validateSalePrice(val, provider.costoCtrl.text),
                  onChanged: (_) => formKey.currentState?.validate(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: provider.precioMayorCtrl,
                  label: 'Precio Mayorista',
                  icon: Icons.local_offer_outlined,
                  keyboardType: TextInputType.number,
                  validator:
                      (val) => _validateWholesalePrice(
                        val,
                        provider.costoCtrl.text,
                        provider.precioCtrl.text,
                      ),
                  onChanged: (_) => formKey.currentState?.validate(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: provider.cantidadMayorCtrl,
                  label: 'Cant. Mínima',
                  icon: Icons.numbers,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    final parsed = int.tryParse(text);
                    if (parsed == null) return 'Inválido';
                    if (parsed < 1) return 'Mayor a 0';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
