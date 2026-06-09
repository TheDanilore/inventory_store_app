import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:inventory_store_app/shared/widgets/app_primary_button.dart';

class AdminSaleStockSection extends StatelessWidget {
  final int currentStock;

  const AdminSaleStockSection({super.key, required this.currentStock});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Stock disponible: $currentStock unidades',
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }
}

class AdminSaleVariantSection extends StatelessWidget {
  final List<ProductVariantModel> variants;
  final ProductVariantModel? selectedVariant;
  final ProductModel product;
  final ValueChanged<ProductVariantModel?> onChanged;

  const AdminSaleVariantSection({
    super.key,
    required this.variants,
    required this.selectedVariant,
    required this.product,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (variants.length <= 1) return const SizedBox.shrink();

    return Column(
      children: [
        DropdownButtonFormField<ProductVariantModel>(
          value: selectedVariant,
          decoration: const InputDecoration(
            labelText: 'Variante',
            border: OutlineInputBorder(),
          ),
          items:
              variants.map((variant) {
                final normalPrice = variant.salePrice ?? product.salePrice;
                final wholesalePrice =
                    variant.wholesalePrice ?? product.wholesalePrice;
                final minQty =
                    variant.wholesaleMinQuantity ??
                    product.wholesaleMinQuantity;

                return DropdownMenuItem(
                  value: variant,
                  child: Text(
                    '${variant.label}: S/ $normalPrice ${wholesalePrice != null ? ' | May: S/ $wholesalePrice ($minQty)' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class AdminSaleQuantitySection extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool isQuantityOverStock;
  final int currentStock;

  const AdminSaleQuantitySection({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.isQuantityOverStock,
    required this.currentStock,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(
            labelText: 'Cantidad a vender',
            border: OutlineInputBorder(),
          ),
        ),
        if (isQuantityOverStock)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'La cantidad supera el stock disponible ($currentStock).',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class AdminSaleWholesaleHint extends StatelessWidget {
  final TextEditingController quantityController;
  final ProductVariantModel? selectedVariant;
  final ProductModel product;
  final bool useWholesalePrice;
  final bool canUseWholesalePrice;

  const AdminSaleWholesaleHint({
    super.key,
    required this.quantityController,
    required this.selectedVariant,
    required this.product,
    required this.useWholesalePrice,
    required this.canUseWholesalePrice,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final quantity = int.tryParse(quantityController.text) ?? 0;
        final wholesalePrice =
            selectedVariant?.wholesalePrice ?? product.wholesalePrice;
        final minQty =
            selectedVariant?.wholesaleMinQuantity ??
            product.wholesaleMinQuantity;
        final hasWholesalePrice = wholesalePrice != null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: useWholesalePrice
                ? Colors.green.shade50
                : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            !hasWholesalePrice
              ? 'No hay precio por mayor configurado en esta variante ni en el producto'
              : !canUseWholesalePrice
                ? 'Sí hay precio por mayor, pero necesitas $minQty unidades para aplicarlo'
                : useWholesalePrice
                    ? (quantity >= minQty
                        ? ' Precio por mayor habilitado (Min: $minQty)'
                        : 'Precio por mayor habilitado, pero necesitas $minQty unidades')
                    : 'Precio base activo. Activa el switch para precio por mayor',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: useWholesalePrice
                  ? Colors.green.shade800
                  : Colors.blue.shade800,
            ),
          ),
        );
      },
    );
  }
}

class AdminSalePointsSection extends StatelessWidget {
  final bool show;
  final int saldoActualCliente;
  final int maxPuntosAplicables;
  final double pointsToSolesRatio;
  final TextEditingController pointsController;
  final ValueChanged<int> onPointsChanged;

  const AdminSalePointsSection({
    super.key,
    required this.show,
    required this.saldoActualCliente,
    required this.maxPuntosAplicables,
    required this.pointsToSolesRatio,
    required this.pointsController,
    required this.onPointsChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo disponible: $saldoActualCliente monedas (S/ ${(saldoActualCliente * pointsToSolesRatio).toStringAsFixed(2)})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Máximo aplicable en esta venta: $maxPuntosAplicables monedas (S/ ${(maxPuntosAplicables * pointsToSolesRatio).toStringAsFixed(2)})',
            style: TextStyle(
              fontSize: 12,
              color: Colors.brown.shade700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: pointsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Monedas a canjear al descuento',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.stars),
            ),
            onChanged: (val) {
              onPointsChanged(int.tryParse(val) ?? 0);
            },
          ),
        ],
      ),
    );
  }
}

class AdminSaleStoreSection extends StatelessWidget {
  final List<WarehouseModel> warehouses;
  final String? selectedWarehouseId;
  final ValueChanged<String?> onChanged;

  const AdminSaleStoreSection({
    super.key,
    required this.warehouses,
    required this.selectedWarehouseId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedWarehouseId,
      decoration: const InputDecoration(
        labelText: 'Almacén / Tienda de Origen',
      ),
      items:
          warehouses
              .map(
                (warehouse) => DropdownMenuItem<String>(
                  value: warehouse.id,
                  child: Text(warehouse.name),
                ),
              )
              .toList(),
      onChanged: onChanged,
    );
  }
}

class AdminSaleTotalSummarySection extends StatelessWidget {
  final double subtotalAntesDePuntos;
  final int puntosAplicables;
  final double descuentoPuntos;
  final double totalFinal;
  final double pointsToSolesRatio;
  final double earningRate;

  const AdminSaleTotalSummarySection({
    super.key,
    required this.subtotalAntesDePuntos,
    required this.puntosAplicables,
    required this.descuentoPuntos,
    required this.totalFinal,
    required this.pointsToSolesRatio,
    required this.earningRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total a pagar:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'S/ ${totalFinal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          if (puntosAplicables > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                children: [
                  _buildPriceRow(
                    'Subtotal antes de monedas',
                    'S/ ${subtotalAntesDePuntos.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 6),
                  _buildPriceRow('Monedas a usar', '$puntosAplicables monedas'),
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Descuento por monedas',
                    '- S/ ${descuentoPuntos.toStringAsFixed(2)}',
                    color: Colors.green.shade800,
                    isBold: true,
                  ),
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Valor de 1 punto',
                    'S/ ${pointsToSolesRatio.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Tasa de acumulación',
                    '${(earningRate * 100).toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class AdminSaleConfirmButton extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final VoidCallback? onPressed;

  const AdminSaleConfirmButton({
    super.key,
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppPrimaryButton(
      loading: loading,
      label: 'Confirmar venta',
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.check, color: Colors.white),
      backgroundColor: Colors.green,
    );
  }
}
