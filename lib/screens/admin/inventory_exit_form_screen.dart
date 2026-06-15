import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/add_exit_product_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Modelo de UI local ───────────────────────────────────────────────────────
class ExitItemUI {
  final ProductModel product;
  final ProductVariantModel variant;
  final Map<String, dynamic>? selectedBatch;
  double quantity;
  final double unitCost; // COSTO REAL EXTRAÍDO PARA VALORIZAR PÉRDIDA

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
class InventoryExitFormScreen extends StatefulWidget {
  const InventoryExitFormScreen({super.key});

  @override
  State<InventoryExitFormScreen> createState() =>
      _InventoryExitFormScreenState();
}

class _InventoryExitFormScreenState extends State<InventoryExitFormScreen> {
  final _supabase = Supabase.instance.client;

  String? _selectedWarehouseId;
  String _selectedReason = 'AJUSTE';
  List<WarehouseModel> _warehouses = [];

  List<ProductModel> _allProducts = [];
  final Map<String, List<ProductVariantModel>> _variantsByProduct = {};

  final List<ExitItemUI> _items = [];
  final _notesCtrl = TextEditingController();

  bool _loadingData = true;
  bool _saving = false;

  static const List<String> _reasons = [
    'AJUSTE',
    'MERMA',
    'DAÑO',
    'VENCIMIENTO',
    'ROBO/PÉRDIDA',
    'CONSUMO INTERNO',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        _supabase.from('warehouses').select('id, name').eq('is_active', true),
        _supabase
            .from('products')
            .select('*, product_images(*)')
            .eq('is_active', true)
            .eq('stock_control', true)
            .neq('product_type', 'service')
            .order('name'),
        // 1. CORRECCIÓN AQUÍ: Actualizamos la consulta para usar atributos relacionales
        _supabase
            .from('product_variants')
            .select('''
              id, product_id, sku, sale_price, unit_cost, is_active,
              product_images(*),
              variant_attribute_values(
                attribute_values(id, value, attributes(id, name))
              )
            ''')
            .eq('is_active', true)
            .order('created_at', ascending: true),
      ]);

      if (!mounted) return;

      final variants =
          (results[2] as List)
              .map(
                (p) =>
                    ProductVariantModel.fromJson(Map<String, dynamic>.from(p)),
              )
              .toList();

      setState(() {
        _warehouses =
            (results[0] as List)
                .map(
                  (w) => WarehouseModel.fromJson(Map<String, dynamic>.from(w)),
                )
                .toList();
        if (_warehouses.isNotEmpty) _selectedWarehouseId = _warehouses.first.id;

        _allProducts =
            (results[1] as List).map((p) => ProductModel.fromJson(p)).toList();

        for (final v in variants) {
          _variantsByProduct.putIfAbsent(v.productId, () => []).add(v);
        }
        _loadingData = false;
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error cargando datos: $e',
          type: SnackbarType.error,
        );
        setState(() => _loadingData = false);
      }
    }
  }

  Future<void> _showAddProductSheet() async {
    if (_selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Primero selecciona el almacén de origen.',
        type: SnackbarType.warning,
      );
      return;
    }

    final newItem = await showModalBottomSheet<ExitItemUI>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => AddExitProductSheet(
            allProducts: _allProducts,
            variantsByProduct: _variantsByProduct,
            warehouseId: _selectedWarehouseId!,
          ),
    );

    if (newItem != null && mounted) {
      final existingIdx = _items.indexWhere(
        (item) =>
            item.product.id == newItem.product.id &&
            item.variant.id == newItem.variant.id &&
            item.selectedBatch?['id'] == newItem.selectedBatch?['id'],
      );
      setState(() {
        if (existingIdx >= 0) {
          _items[existingIdx].quantity += newItem.quantity;
        } else {
          _items.add(newItem);
        }
      });
    }
  }

  // ── Modal para modificar cantidad manualmente ──
  Future<void> _mostrarDialogoCantidadItem(
    int index,
    double cantidadActual,
    double maxAvailable,
  ) async {
    final qtyCtrl = TextEditingController(
      text: cantidadActual.toStringAsFixed(0),
    );
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(
              'Cantidad a retirar',
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
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () {
                  final newQty = double.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty > 0) {
                    setState(() {
                      // Asegurar que no se sobrepase el stock disponible
                      _items[index].quantity =
                          newQty > maxAvailable ? maxAvailable : newQty;
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
        message: 'Agregue al menos un producto a retirar',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final notes = _notesCtrl.text.trim();
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

      // 1. ── Cabecera de la Salida ──
      final exitHeader =
          await _supabase
              .from('inventory_exits')
              .insert({
                'warehouse_id': _selectedWarehouseId,
                'reason': _selectedReason,
                'notes': notes.isEmpty ? null : notes,
                'created_by': createdByProfileId,
              })
              .select('id')
              .single();

      final exitId = exitHeader['id'] as String;

      for (final item in _items) {
        final batchData = item.selectedBatch;
        final String batchNumber = batchData?['batch_number'] ?? 'DEFAULT';
        final String batchId = batchData!['id'] as String;

        // RE-VALIDACIÓN DE STOCK EN TIEMPO REAL
        final currentBatch =
            await _supabase
                .from('warehouse_stock_batches')
                .select('available_quantity')
                .eq('id', batchId)
                .single();
        final double previousStock =
            (currentBatch['available_quantity'] as num).toDouble();
        final double newStock = previousStock - item.quantity;

        if (newStock < 0) {
          throw Exception(
            'Stock insuficiente para ${item.product.name} (Lote: $batchNumber). Disponible actual: $previousStock',
          );
        }

        // 2. ── Detalle de salida (inventory_exit_items) ──
        await _supabase.from('inventory_exit_items').insert({
          'exit_id': exitId,
          'product_id': item.product.id,
          'variant_id': item.variant.id,
          'quantity': item.quantity,
          'batch_number': batchNumber,
          'unit_cost': item.unitCost, // <-- COSTO UNITARIO INYECTADO A LA BD
        });

        // 3. ── Actualización de Stock (Kardex Físico) ──
        await _supabase
            .from('warehouse_stock_batches')
            .update({
              'available_quantity': newStock,
              'updated_at': DateTime.now().toIso8601String(),
              'updated_by': createdByProfileId,
            })
            .eq('id', batchId);

        // 4. ── Movimiento Histórico (Kardex Valorizado) ──
        await _supabase.from('inventory_movements').insert({
          'variant_id': item.variant.id,
          'warehouse_id': _selectedWarehouseId,
          'stock_batch_id': batchId,
          'inventory_exit_id': exitId,
          'quantity': -item.quantity, // Negativo porque SALE inventario
          'previous_stock': previousStock,
          'new_stock': newStock,
          'unit_cost': item.unitCost,
          'total_cost': item.totalCost, // PÉRDIDA VALORIZADA
          'reason': 'EXIT',
          'notes': 'Salida por: $_selectedReason',
          'created_by': createdByProfileId,
        });
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Salida de inventario registrada con éxito.',
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return const AdminLayout(
        title: 'Nueva Salida',
        showBackButton: true,
        body: Center(child: CircularProgressIndicator(color: AppColors.danger)),
      );
    }

    final double totalLossCost = _items.fold(
      0,
      (sum, item) => sum + item.totalCost,
    );
    final int totalUnits = _items.fold(
      0,
      (sum, item) => sum + item.quantity.toInt(),
    );

    return AdminLayout(
      title: 'Registrar Salida',
      showBackButton: true,
      body:
          _saving
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.danger),
              )
              : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Datos de la salida ──
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.output_rounded,
                                      size: 16,
                                      color: AppColors.danger,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Información General',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                DropdownButtonFormField<String>(
                                  initialValue: _selectedWarehouseId,
                                  decoration: _dropdownDeco(
                                    'Almacén de Origen',
                                    Icons.warehouse_rounded,
                                  ),
                                  items:
                                      _warehouses
                                          .map(
                                            (w) => DropdownMenuItem(
                                              value: w.id,
                                              child: Text(
                                                w.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) {
                                    if (v != null &&
                                        v != _selectedWarehouseId) {
                                      setState(() {
                                        _selectedWarehouseId = v;
                                        _items
                                            .clear(); // Limpiar la lista si cambian de almacén porque los lotes cambian
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),

                                DropdownButtonFormField<String>(
                                  initialValue: _selectedReason,
                                  decoration: _dropdownDeco(
                                    'Motivo de Salida',
                                    Icons.assignment_late_rounded,
                                  ),
                                  items:
                                      _reasons
                                          .map(
                                            (r) => DropdownMenuItem(
                                              value: r,
                                              child: Text(
                                                r,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _selectedReason = v);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),

                                TextField(
                                  controller: _notesCtrl,
                                  decoration: _dropdownDeco(
                                    'Notas / Justificación (Opcional)',
                                    Icons.notes_rounded,
                                  ).copyWith(
                                    hintText:
                                        'Ej: Botellas rotas durante traslado',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Lista de ítems ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_rounded,
                                      size: 18,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Items (${_items.length})',
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
                                  'Retirar Producto',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  backgroundColor: AppColors.danger.withValues(
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
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.outbox_rounded,
                                    size: 32,
                                    color: AppColors.textHint,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Sin productos a retirar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
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
                                  (_, _) => const SizedBox(height: 10),
                              itemBuilder:
                                  (context, index) =>
                                      _buildItemCard(_items[index], index),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Panel Inferior Fijo ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.danger.withValues(alpha: 0.08),
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
                                    'Pérdida Valorizada',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_items.length} items · $totalUnits unidades retiradas',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'S/ ${totalLossCost.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 24,
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
                              onPressed: _items.isNotEmpty ? _saveExit : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                disabledBackgroundColor: AppColors.background,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Confirmar Salida',
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

  Widget _buildItemCard(ExitItemUI item, int index) {
    // Buscar imagen priorizando la variante
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

    // Extraer atributos relacionales seguros
    final attrValues =
        item.variant.attributeValues.map((v) => v.value).toList();
    final attrsText = attrValues.join(' · ');
    final displayVariantText = attrsText.isNotEmpty ? attrsText : 'Única';

    final batchNumber = item.selectedBatch?['batch_number'] ?? 'DEFAULT';

    // Obtener cantidad máxima permitida por el lote (para el Stepper)
    final double maxAvailable =
        (item.selectedBatch?['available_quantity'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              (item.product.usesBatches &&
                      (batchNumber == 'DEFAULT' || batchNumber.trim().isEmpty))
                  ? AppColors.danger
                  : AppColors.border,
        ),
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
                      ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
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
                if (displayVariantText != 'Única') ...[
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
                      displayVariantText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                // Mostrar lote SOLO si usa lotes y no es DEFAULT
                if (item.product.usesBatches && batchNumber != 'DEFAULT') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.tag_rounded,
                        size: 11,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Lote: $batchNumber',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                // Mensaje de error si usa lotes pero no seleccionó uno
                if (item.product.usesBatches &&
                    (batchNumber == 'DEFAULT' ||
                        batchNumber.trim().isEmpty)) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_rounded,
                        size: 12,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Requiere seleccionar lote',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Costo: S/ ${item.unitCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'S/ ${item.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Stepper ──
          _VerticalStepper(
            value: item.quantity.toInt(),
            onAdd:
                item.quantity < maxAvailable
                    ? () => setState(() => _items[index].quantity++)
                    : null, // Se bloquea si llega al límite
            onRemove:
                item.quantity > 1
                    ? () => setState(() => _items[index].quantity--)
                    : null,
            onTapValue:
                () => _mostrarDialogoCantidadItem(
                  index,
                  item.quantity,
                  maxAvailable,
                ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
              size: 22,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _items.removeAt(index)),
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: Icon(icon, color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ─── Componentes Auxiliares ───────────────────────────────────────────────────

class _VerticalStepper extends StatelessWidget {
  final int value;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final VoidCallback onTapValue;

  const _VerticalStepper({
    required this.value,
    this.onAdd,
    this.onRemove,
    required this.onTapValue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperBtn(Icons.add_rounded, onAdd == null, onAdd ?? () {}),
        const SizedBox(height: 4),
        Material(
          color: AppColors.primary.withValues(
            alpha: 0.06,
          ), // Mantengo Primary igual a la foto
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTapValue,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: Text(
                value.toString(),
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
        _stepperBtn(Icons.remove_rounded, onRemove == null, onRemove ?? () {}),
      ],
    );
  }
}

Widget _stepperBtn(IconData icon, bool disabled, VoidCallback onTap) {
  return Material(
    color: disabled ? const Color(0xFFF1F5F9) : AppColors.primary,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: disabled ? AppColors.textMuted : Colors.white,
        ),
      ),
    ),
  );
}
