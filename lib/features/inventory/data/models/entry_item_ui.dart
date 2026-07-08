import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';

// ─── Modelo de UI local para Formularios de Entrada ───────────────────────
class EntryItemUI {
  final ProductModel product;
  final ProductVariantModel variant;
  double quantity;
  double unitCost;
  final String batchNumber;
  final DateTime? expiryDate;

  EntryItemUI({
    required this.product,
    required this.variant,
    required this.quantity,
    required this.unitCost,
    this.batchNumber = 'DEFAULT',
    this.expiryDate,
  });

  double get subtotal => quantity * unitCost;
}
