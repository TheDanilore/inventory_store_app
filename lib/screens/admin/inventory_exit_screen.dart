import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/kardex_screen.dart';
import 'package:inventory_store_app/screens/admin/widgets/add_exit_product_sheet_state.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/inventory_exit_item_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

// ─── Modelo de UI local ───────────────────────────────────────────────────────
class ExitItemUI {
  final ProductModel product;
  final ProductVariantModel variant;
  final Map<String, dynamic>? selectedBatch; // Lote específico seleccionado
  double quantity;
  final double unitCost; // Para valorizar la pérdida en el Kardex

  ExitItemUI({
    required this.product,
    required this.variant,
    this.selectedBatch,
    required this.quantity,
    required this.unitCost,
  });

  double get totalCost => quantity * unitCost;
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

  // Mapa de inventario: [warehouse_id][variant_id] -> Lista de Lotes
  final Map<String, Map<String, List<Map<String, dynamic>>>> _stockData = {};

  // Lista de ítems de UI (no de BD)
  final List<ExitItemUI> _items = [];
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
            'id, product_id, sku, attributes, product_images(*), sale_price, unit_cost, is_active',
          )
          .eq('is_active', true)
          .order('created_at', ascending: true);

      // Cargar inventario detallado para validar salidas y elegir lotes
      final inventoryResp = await _supabase
          .from('warehouse_stock_batches')
          .select(
            'id, warehouse_id, variant_id, batch_number, expiry_date, available_quantity',
          )
          .gt('available_quantity', 0)
          .order('expiry_date', ascending: true, nullsFirst: false);

      if (!mounted) return;

      final variants =
          (variantsResp as List)
              .map(
                (p) =>
                    ProductVariantModel.fromJson(Map<String, dynamic>.from(p)),
              )
              .toList();

      final Map<String, Map<String, List<Map<String, dynamic>>>> newStockData =
          {};

      for (final row in List<Map<String, dynamic>>.from(inventoryResp)) {
        final wId = row['warehouse_id'] as String;
        // Si no tiene variante, usamos un string vacío como llave por defecto
        final vId = row['variant_id'] as String? ?? '';
        newStockData
            .putIfAbsent(wId, () => {})
            .putIfAbsent(vId, () => [])
            .add(row);
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

    final newItem = await showModalBottomSheet<ExitItemUI>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => AddExitProductSheet(
            allProducts: _allProducts,
            variantsByProduct: _variantsByProduct,
            warehouseStock: warehouseStock,
          ),
    );

    if (newItem != null && mounted) {
      final existingIdx = _items.indexWhere(
        (item) =>
            item.product.id == newItem.product.id &&
            item.variant.id == newItem.variant.id &&
            item.selectedBatch?['id'] ==
                newItem.selectedBatch?['id'], // Validar lote específico
      );

      // Calculamos el stock máximo disponible para la selección actual
      double maxStock = 0;
      final batches = warehouseStock[newItem.variant.id] ?? [];
      if (newItem.selectedBatch != null) {
        maxStock =
            (newItem.selectedBatch!['available_quantity'] as num?)
                ?.toDouble() ??
            0.0;
      } else {
        maxStock = batches.fold(
          0.0,
          (sum, b) =>
              sum + ((b['available_quantity'] as num?)?.toDouble() ?? 0.0),
        );
      }

      setState(() {
        if (existingIdx >= 0) {
          final nuevaCant = _items[existingIdx].quantity + newItem.quantity;
          _items[existingIdx].quantity =
              nuevaCant > maxStock ? maxStock : nuevaCant;
        } else {
          _items.add(newItem);
        }
      });
    }
  }

  Future<void> _mostrarDialogoCantidadItem(
    int index,
    double cantidadActual,
    double maxStock,
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                          newQty > maxStock ? maxStock : newQty;
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

      // 1. Guardar la cabecera
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

      // 2. Procesar cada ítem: descontar stock FEFO o específico, y registrar historial (kardex)
      for (final item in _items) {
        final String? variantId =
            item.variant.id.isEmpty ? null : item.variant.id;

        final exitItemModel = InventoryExitItemModel(
          id: '',
          exitId: exitId,
          productId: item.product.id,
          // SOLUCIÓN ERROR 2: Agregamos "?? ''" para asegurar que no sea nulo si el modelo exige String puro.
          variantId: variantId ?? '',
          quantity: item.quantity,
        );

        await _supabase.from('inventory_exit_items').insert({
          ...exitItemModel.toJson()..remove('id'),
        });

        if (item.selectedBatch != null) {
          // Descuento desde LOTE ESPECÍFICO
          final batchId = item.selectedBatch!['id'];

          final batchDb =
              await _supabase
                  .from('warehouse_stock_batches')
                  .select('available_quantity')
                  .eq('id', batchId)
                  .single();

          final available = (batchDb['available_quantity'] as num).toDouble();
          final newStock = available - item.quantity;

          await _supabase
              .from('warehouse_stock_batches')
              .update({
                'available_quantity': newStock,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', batchId);

          await _supabase.from('inventory_movements').insert({
            'variant_id': variantId,
            'warehouse_id': _selectedWarehouseId,
            'stock_batch_id': batchId,
            'inventory_exit_id': exitId,
            'quantity': -item.quantity,
            'previous_stock': available,
            'new_stock': newStock,
            'unit_cost': item.unitCost,
            'total_cost': item.quantity * item.unitCost,
            'reason': 'EXIT',
            'notes': reason.isEmpty ? 'Salida manual' : reason,
            'created_by': createdByProfileId,
          });
        } else {
          // Descuento automático FEFO (First Expired First Out)

          // SOLUCIÓN ERROR 1: Construimos la consulta base SIN el .order() todavía
          var query = _supabase
              .from('warehouse_stock_batches')
              .select('id, available_quantity')
              .eq('warehouse_id', _selectedWarehouseId!)
              .eq('product_id', item.product.id)
              .gt('available_quantity', 0);

          if (variantId != null) {
            query = query.eq('variant_id', variantId);
          }

          // Aplicamos el .order() al final, justo antes de ejecutar la consulta
          final batchesList = await query.order(
            'expiry_date',
            ascending: true,
            nullsFirst: false,
          );

          double remaining = item.quantity;

          for (final batch in (batchesList as List)) {
            if (remaining <= 0) break;
            final double available =
                (batch['available_quantity'] as num).toDouble();
            final double take = (remaining > available) ? available : remaining;
            final double newStock = available - take;

            await _supabase
                .from('warehouse_stock_batches')
                .update({
                  'available_quantity': newStock,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', batch['id']);

            await _supabase.from('inventory_movements').insert({
              'variant_id': variantId,
              'warehouse_id': _selectedWarehouseId,
              'stock_batch_id': batch['id'],
              'inventory_exit_id': exitId,
              'quantity': -take,
              'previous_stock': available,
              'new_stock': newStock,
              'unit_cost': item.unitCost,
              'total_cost': take * item.unitCost,
              'reason': 'EXIT',
              'notes': reason.isEmpty ? 'Salida manual' : reason,
              'created_by': createdByProfileId,
            });

            remaining -= take;
          }

          if (remaining > 0) {
            throw Exception(
              'Stock insuficiente durante el procesamiento para ${item.product.name}',
            );
          }
        }
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Salida registrada correctamente en el Kardex',
          type: SnackbarType.success,
        );
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const KardexScreen()),
        );
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
      if (mounted) setState(() => _saving = false);
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

    final double totalCost = _items.fold(
      0.0,
      (sum, item) => sum + item.totalCost,
    );
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
                                    labelText:
                                        'Motivo / Observación (Vencimiento, Pérdida...)',
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

                  // ─── FOOTER CON TOTALES (Valorización de pérdida) ───
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
                                    'Pérdida valorizada estimada',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$totalVariants items · $totalUnits unds.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'S/ ${totalCost.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.danger,
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
                                'Registrar Salida de Inventario',
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

  Widget _buildExitItemCard(ExitItemUI item, int index) {
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

    // Calcula stock máximo dinámicamente si es lote o genérico
    final batches = _stockData[_selectedWarehouseId]?[item.variant.id] ?? [];
    double maxStock = 0;
    if (item.selectedBatch != null) {
      final b = batches.firstWhere(
        (b) => b['id'] == item.selectedBatch!['id'],
        orElse: () => {},
      );
      maxStock = (b['available_quantity'] as num?)?.toDouble() ?? 0.0;
    } else {
      maxStock = batches.fold(
        0.0,
        (sum, b) =>
            sum + ((b['available_quantity'] as num?)?.toDouble() ?? 0.0),
      );
    }

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
                // Info Lote Seleccionado
                if (item.selectedBatch != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blueLight.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.blueLight),
                    ),
                    child: Text(
                      'Lote: ${item.selectedBatch!['batch_number'] ?? 'DEFAULT'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Total Cost y Precio Un.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'S/ ${item.totalCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'C. Unit: S/ ${item.unitCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              // Stepper Horizontal Pequeño
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stepperButton(
                    icon: Icons.remove_rounded,
                    isRemove: true,
                    isDisabled: item.quantity <= 1,
                    onTap: () {
                      if (item.quantity > 1) {
                        setState(() => _items[index].quantity--);
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap:
                          () => _mostrarDialogoCantidadItem(
                            index,
                            item.quantity,
                            maxStock,
                          ),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 32,
                        height: 28,
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
                  const SizedBox(width: 6),
                  _stepperButton(
                    icon: Icons.add_rounded,
                    isDisabled: item.quantity >= maxStock,
                    onTap: () => setState(() => _items[index].quantity++),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(width: 10),

          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 24,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _items.removeAt(index)),
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
              : AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color:
                isDisabled
                    ? AppColors.textMuted
                    : isRemove
                    ? AppColors.error
                    : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
