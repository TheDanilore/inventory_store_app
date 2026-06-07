import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/inventory_exit_item_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

// ─── Modelo de UI local ───────────────────────────────────────────────────────
// Agrupa los datos de pantalla que NO pertenecen a InventoryExitItemModel
// (modelo de BD). Usa campos mutables para el stepper in-place.
class _ExitItemUI {
  final ProductModel product;
  final ProductVariantModel variant;
  double quantity;

  _ExitItemUI({
    required this.product,
    required this.variant,
    required this.quantity,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class InventoryExitScreen extends StatefulWidget {
  const InventoryExitScreen({super.key});

  @override
  State<InventoryExitScreen> createState() => _InventoryExitScreenState();
}

class _InventoryExitScreenState extends State<InventoryExitScreen> {
  final _supabase = Supabase.instance.client;

  String? _selectedWarehouseId;
  List<dynamic> _warehouses = [];
  bool _loadingWarehouses = true;

  List<ProductModel> _allProducts = [];
  bool _loadingProducts = true;

  final Map<String, List<ProductVariantModel>> _variantsByProduct = {};

  // Mapa de inventario: [warehouse_id][variant_id] 
  final Map<String, Map<String, int>> _stockData = {};

  // Lista de ítems de UI (no de BD)
  final List<_ExitItemUI> _items = [];
  bool _saving = false;
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final warehousesResp = await _supabase
          .from('warehouses')
          .select('id, name')
          .eq('is_active', true);

      final productsResp = await _supabase
          .from('products')
          .select('*, product_images(*)')
          .eq('is_active', true)
          .order('name');

      final variantsResp = await _supabase
          .from('product_variants')
          .select(
            'id, product_id, sku, attributes, product_images(*), sale_price, is_active',
          )
          .eq('is_active', true)
          .order('created_at', ascending: true);

      // Cargar inventario actual para validar salidas
      // Cargar inventario actual para validar salidas
      // CORRECCIÓN: Apuntamos a warehouse_stock_batches y available_quantity
      final inventoryResp = await _supabase
          .from('warehouse_stock_batches')
          .select('warehouse_id, variant_id, available_quantity');

      if (!mounted) return;

      final variants =
          (variantsResp as List)
              .map(
                (p) =>
                    ProductVariantModel.fromJson(Map<String, dynamic>.from(p)),
              )
              .toList();

      final Map<String, Map<String, int>> newStockData = {};
      for (final row in List<Map<String, dynamic>>.from(inventoryResp)) {
        final wId = row['warehouse_id'] as String;
        final vId = row['variant_id'] as String?;
        // CORRECCIÓN: Leemos available_quantity
        final stock = (row['available_quantity'] as num?)?.toInt() ?? 0;
        
        if (vId != null) {
          // CORRECCIÓN: Sumamos el stock porque una variante puede estar dividida en múltiples lotes
          final currentVariantStock = newStockData[wId]?[vId] ?? 0;
          newStockData.putIfAbsent(wId, () => {})[vId] = currentVariantStock + stock;
        }
      }

      setState(() {
        _stockData.addAll(newStockData);
        _warehouses = warehousesResp as List<dynamic>;
        if (_warehouses.isNotEmpty) {
          _selectedWarehouseId = _warehouses.first['id'] as String;
        }
        _allProducts =
            (productsResp as List)
                .map((p) => ProductModel.fromJson(Map<String, dynamic>.from(p)))
                .toList();
        _variantsByProduct.clear();
        for (final variant in variants) {
          _variantsByProduct
              .putIfAbsent(variant.productId, () => [])
              .add(variant);
        }
        _loadingWarehouses = false;
        _loadingProducts = false;
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error cargando datos: $e',
          type: SnackbarType.error,
        );
        setState(() {
          _loadingWarehouses = false;
          _loadingProducts = false;
        });
      }
    }
  }

  Future<void> _showAddProductSheet() async {
    if (_selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un almacén primero',
        type: SnackbarType.warning,
      );
      return;
    }

    final warehouseStock = _stockData[_selectedWarehouseId!] ?? {};

    final newItem = await showModalBottomSheet<_ExitItemUI>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _AddExitProductSheet(
            allProducts: _allProducts,
            variantsByProduct: _variantsByProduct,
            warehouseStock: warehouseStock,
          ),
    );

    if (newItem != null && mounted) {
      final existingIdx = _items.indexWhere(
        (item) =>
            item.product.id == newItem.product.id &&
            item.variant.id == newItem.variant.id,
      );

      final maxStock = warehouseStock[newItem.variant.id] ?? 0;

      setState(() {
        if (existingIdx >= 0) {
          final nuevaCant = _items[existingIdx].quantity + newItem.quantity;
          _items[existingIdx].quantity =
              nuevaCant > maxStock ? maxStock.toDouble() : nuevaCant;
        } else {
          _items.add(newItem);
        }
      });
    }
  }

  Future<void> _mostrarDialogoCantidadItem(
    int index,
    double cantidadActual,
    int maxStock,
  ) async {
    final qtyCtrl = TextEditingController(
      text: cantidadActual.toStringAsFixed(0),
    );
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(
              'Cantidad exacta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                helperText: 'Stock máximo: $maxStock',
                helperStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () {
                  final newQty = double.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty > 0) {
                    setState(() {
                      _items[index].quantity =
                          newQty > maxStock ? maxStock.toDouble() : newQty;
                    });
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
    qtyCtrl.dispose();
  }

  Future<void> _saveExit() async {
    if (_selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione un almacén',
        type: SnackbarType.warning,
      );
      return;
    }
    if (_items.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Agregue al menos un producto a la salida',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final String reason = _reasonCtrl.text.trim();
      String? createdByProfileId;
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        final profile =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', currentUser.id)
                .maybeSingle();
        createdByProfileId = profile?['id'] as String?;
      }

      final exitHeader =
          await _supabase
              .from('inventory_exits')
              .insert({
                'warehouse_id': _selectedWarehouseId,
                'reason': reason.isEmpty ? 'Salida manual' : reason,
                'notes': reason.isEmpty ? null : reason,
                'created_by': createdByProfileId,
              })
              .select('id')
              .single();

      final exitId = exitHeader['id'] as String;

      for (final item in _items) {
        // Construir el modelo de BD y persistirlo
        final exitItem = InventoryExitItemModel(
          id: '', // generado por Supabase
          exitId: exitId,
          productId: item.product.id,
          variantId: item.variant.id,
          quantity: item.quantity,
        );
        await _supabase.from('inventory_exit_items').insert({
          ...exitItem.toJson()..remove('id'),
        });
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Salida registrada correctamente',
          type: SnackbarType.success,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error registrando salida: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingWarehouses || _loadingProducts) {
      return const AdminLayout(
        title: 'Salida de Inventario',
        showBackButton: true,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final int totalUnits = _items.fold(
      0,
      (sum, item) => sum + item.quantity.toInt(),
    );
    final int totalVariants = _items.length;

    return AdminLayout(
      title: 'Salida de Inventario',
      showBackButton: true,
      body:
          _saving
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Datos Generales',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _selectedWarehouseId,
                                  icon: const Icon(Icons.expand_more_rounded),
                                  decoration: InputDecoration(
                                    labelText: 'Almacén de Origen',
                                    labelStyle: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    filled: true,
                                    fillColor: AppColors.background,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  items:
                                      _warehouses
                                          .map(
                                            (s) => DropdownMenuItem<String>(
                                              value: s['id'],
                                              child: Text(
                                                s['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) {
                                    if (v != _selectedWarehouseId) {
                                      setState(() {
                                        _selectedWarehouseId = v;
                                        _items.clear();
                                      });
                                      AppSnackbar.show(
                                        context,
                                        message:
                                            'Lista limpiada por cambio de almacén',
                                        type: SnackbarType.info,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _reasonCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Motivo / Observación',
                                    labelStyle: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    filled: true,
                                    fillColor: AppColors.background,
                                    prefixIcon: const Icon(
                                      Icons.notes_rounded,
                                      color: AppColors.textHint,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.outbox_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Items ($totalVariants)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: _showAddProductSheet,
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Añadir',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  backgroundColor: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_items.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.border,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: AppColors.background,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 32,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Lista vacía',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Añade productos para registrar su salida.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _items.length,
                              separatorBuilder:
                                  (context, index) =>
                                      const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return _buildExitItemCard(item, index);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Resumen de salida',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$totalVariants variantes',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$totalUnits unds.',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _items.isEmpty ? null : _saveExit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                disabledBackgroundColor: AppColors.background,
                                disabledForegroundColor: AppColors.textHint,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.save_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Registrar Salida',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildExitItemCard(_ExitItemUI item, int index) {
    String? imageUrl;
    if (item.variant.images.isNotEmpty) {
      imageUrl = item.variant.images.first.imageUrl;
    } else if (item.product.images.isNotEmpty) {
      imageUrl =
          item.product.images
              .firstWhere(
                (img) => img.isMain,
                orElse: () => item.product.images.first,
              )
              .imageUrl;
    }

    final maxStock = _stockData[_selectedWarehouseId]?[item.variant.id] ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child:
                  imageUrl != null
                      ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => const Icon(
                              Icons.image_not_supported_rounded,
                              color: AppColors.textHint,
                            ),
                      )
                      : const Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.textHint,
                      ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.variant.id.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      item.variant.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Stepper Vertical
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepperButton(
                icon: Icons.add_rounded,
                isDisabled: item.quantity >= maxStock,
                onTap: () {
                  setState(() => _items[index].quantity++);
                },
              ),
              const SizedBox(height: 4),
              Material(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap:
                      () => _mostrarDialogoCantidadItem(
                        index,
                        item.quantity,
                        maxStock,
                      ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    child: Text(
                      item.quantity.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _stepperButton(
                icon: Icons.remove_rounded,
                isDisabled: item.quantity <= 1,
                onTap: () {
                  if (item.quantity > 1) {
                    setState(() => _items[index].quantity--);
                  }
                },
              ),
            ],
          ),

          const SizedBox(width: 6),

          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 24,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _items.removeAt(index);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool isRemove = false,
    bool isDisabled = false,
  }) {
    return Material(
      color:
          isDisabled
              ? const Color(0xFFF1F5F9)
              : isRemove
              ? AppColors.error.withValues(alpha: 0.08)
              : AppColors.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color:
                isDisabled
                    ? AppColors.textMuted
                    : isRemove
                    ? AppColors.error
                    : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Sheet Modal para Añadir Producto (Salida) ──────────────────────

class _AddExitProductSheet extends StatefulWidget {
  final List<ProductModel> allProducts;
  final Map<String, List<ProductVariantModel>> variantsByProduct;
  final Map<String, int> warehouseStock;

  const _AddExitProductSheet({
    required this.allProducts,
    required this.variantsByProduct,
    required this.warehouseStock,
  });

  @override
  State<_AddExitProductSheet> createState() => _AddExitProductSheetState();
}

class _AddExitProductSheetState extends State<_AddExitProductSheet> {
  ProductModel? _selectedProduct;
  ProductVariantModel? _selectedVariant;
  int _quantity = 1;

  void _onProductChanged(ProductModel? val) {
    setState(() {
      _selectedProduct = val;
      _selectedVariant = null;
      _quantity = 1;
    });
  }

  void _onVariantChanged(ProductVariantModel? val) {
    setState(() {
      _selectedVariant = val;
      _quantity = 1;
    });
  }

  int get _maxStock {
    if (_selectedVariant == null) return 0;
    return widget.warehouseStock[_selectedVariant!.id] ?? 0;
  }

  Future<void> _mostrarDialogoCantidadModal() async {
    final qtyCtrl = TextEditingController(text: _quantity.toString());
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(
              'Cantidad exacta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                helperText: 'Stock máximo: $_maxStock',
                helperStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () {
                  final newQty = int.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty > 0) {
                    setState(() {
                      _quantity = newQty > _maxStock ? _maxStock : newQty;
                    });
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
    qtyCtrl.dispose();
  }

  void _submit() {
    final availableVariants =
        _selectedProduct == null
            ? const <ProductVariantModel>[]
            : (widget.variantsByProduct[_selectedProduct!.id] ?? []);

    if (_selectedProduct == null || _quantity <= 0) {
      AppSnackbar.show(
        context,
        message: 'Revisa los datos ingresados',
        type: SnackbarType.error,
      );
      return;
    }

    if (availableVariants.isNotEmpty && _selectedVariant == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona una variante obligatoriamente',
        type: SnackbarType.warning,
      );
      return;
    }

    final variantToUse =
        _selectedVariant ??
        ProductVariantModel(
          id: '',
          productId: _selectedProduct!.id,
          sku: null,
          salePrice: null,
        );

    final max = widget.warehouseStock[variantToUse.id] ?? 0;
    if (_quantity > max) {
      AppSnackbar.show(
        context,
        message: 'No puedes retirar más del stock disponible',
        type: SnackbarType.error,
      );
      return;
    }

    final newItem = _ExitItemUI(
      product: _selectedProduct!,
      variant: variantToUse,
      quantity: _quantity.toDouble(),
    );

    Navigator.pop(context, newItem);
  }

  @override
  Widget build(BuildContext context) {
    final availableVariants =
        _selectedProduct == null
            ? const <ProductVariantModel>[]
            : (widget.variantsByProduct[_selectedProduct!.id] ?? []);

    String? currentImageUrl;
    if (_selectedVariant?.images.isNotEmpty == true) {
      currentImageUrl = _selectedVariant!.images.first.imageUrl;
    } else if (_selectedProduct?.images.isNotEmpty == true) {
      currentImageUrl =
          _selectedProduct!.images
              .firstWhere(
                (img) => img.isMain,
                orElse: () => _selectedProduct!.images.first,
              )
              .imageUrl;
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 14),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Añadir Salida',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<ProductModel>(
              value: _selectedProduct,
              isExpanded: true,
              icon: const Icon(Icons.expand_more_rounded),
              decoration: InputDecoration(
                labelText: 'Selecciona el Producto',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              items:
                  widget.allProducts
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                      .toList(),
              onChanged: _onProductChanged,
            ),
            const SizedBox(height: 16),

            if (availableVariants.isNotEmpty) ...[
              DropdownButtonFormField<ProductVariantModel>(
                value: _selectedVariant,
                isExpanded: true,
                icon: const Icon(Icons.expand_more_rounded),
                decoration: InputDecoration(
                  labelText: 'Selecciona la Variante',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                items:
                    availableVariants
                        .map(
                          (variant) => DropdownMenuItem(
                            value: variant,
                            child: Text(
                              variant.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: _onVariantChanged,
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedProduct != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child:
                          currentImageUrl != null
                              ? Image.network(
                                currentImageUrl,
                                fit: BoxFit.cover,
                              )
                              : const Icon(
                                Icons.image_not_supported_rounded,
                                color: AppColors.textHint,
                              ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock Disponible',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            if (availableVariants.isNotEmpty &&
                                _selectedVariant == null) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.textHint.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.textHint.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Selecciona una variante',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              );
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _maxStock > 0
                                        ? AppColors.success.withValues(
                                          alpha: 0.1,
                                        )
                                        : AppColors.danger.withValues(
                                          alpha: 0.1,
                                        ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      _maxStock > 0
                                          ? AppColors.success.withValues(
                                            alpha: 0.3,
                                          )
                                          : AppColors.danger.withValues(
                                            alpha: 0.3,
                                          ),
                                ),
                              ),
                              child: Text(
                                _maxStock > 0
                                    ? '$_maxStock unidades'
                                    : 'Agotado en este almacén',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      _maxStock > 0
                                          ? AppColors.success
                                          : AppColors.danger,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                'Cantidad a Retirar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      enabled: _quantity > 1,
                      onTap: () => setState(() => _quantity--),
                    ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap:
                              _maxStock > 0
                                  ? _mostrarDialogoCantidadModal
                                  : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '$_quantity',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      enabled: _quantity < _maxStock,
                      onTap: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed:
                    (_selectedProduct != null &&
                            (_selectedVariant != null ||
                                (widget
                                        .variantsByProduct[_selectedProduct!.id]
                                        ?.isEmpty ??
                                    true)) &&
                            _maxStock > 0)
                        ? _submit
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.background,
                  disabledForegroundColor: AppColors.textHint,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Agregar a la lista',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color:
              enabled
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.primary : AppColors.textMuted,
          size: 22,
        ),
      ),
    );
  }
}
