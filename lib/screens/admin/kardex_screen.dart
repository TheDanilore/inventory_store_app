import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/widgets/date_filter_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/inventory_movement_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/inventory_entry_form_screen.dart';
import 'package:inventory_store_app/screens/admin/inventory_exit_form_screen.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

class KardexMovement {
  final InventoryMovementModel movement;

  final String productName;
  final String warehouseName;
  final ProductVariantModel? variant;

  KardexMovement({
    required this.movement,
    required this.productName,
    required this.warehouseName,
    this.variant,
  });

  bool get isSale => movement.orderId != null;

  bool get isEntry {
    return movement.inventoryEntryId != null ||
        movement.reason.toUpperCase().contains('INGRESO');
  }

  bool get isExit {
    return movement.inventoryExitId != null;
  }

  String get movementType {
    if (isSale) return 'VENTA';
    if (isEntry) return 'INGRESO';
    if (isExit) return 'SALIDA';

    return movement.reason;
  }

  String? get referenceId {
    return movement.orderId ??
        movement.inventoryEntryId ??
        movement.inventoryExitId ??
        movement.physicalInventoryId;
  }
}

class KardexScreen extends StatefulWidget {
  const KardexScreen({super.key});

  @override
  State<KardexScreen> createState() => _KardexScreenState();
}

class _KardexScreenState extends State<KardexScreen> {
  static const int _pageSize = 8;
  final _supabase = Supabase.instance.client;
  List<KardexMovement> _movements = [];
  bool _isLoading = true;
  int _currentPage = 0;

  DateTimeRange? _dateRange;
  String _typeFilter = 'ALL'; // 'ALL', 'ENTRY', 'EXIT', 'SALE'

  @override
  void initState() {
    super.initState();
    _fetchMovements();
  }

  Future<void> _fetchMovements() async {
    setState(() => _isLoading = true);
    try {
      // 1. Construimos la consulta base
      var query = _supabase.from('inventory_movements').select('''
      *,
      warehouses(name),
      product_variants(
        id,
        product_id,
        sku,
        attributes,
        sale_price,
        is_active,
        product_images(*),
        products(name)
      )
    ''');

      if (_dateRange != null) {
        final startStr = _dateRange!.start.toIso8601String();
        final endStr =
            _dateRange!.end
                .add(const Duration(hours: 23, minutes: 59, seconds: 59))
                .toIso8601String();

        query = query.gte('created_at', startStr).lte('created_at', endStr);
      }

      if (_typeFilter == 'ENTRY') {
        query = query.not('inventory_entry_id', 'is', null);
      }

      if (_typeFilter == 'EXIT') {
        query = query.not('inventory_exit_id', 'is', null);
      }

      if (_typeFilter == 'SALE') {
        query = query.not('order_id', 'is', null);
      }

      final movementsResponse = await query.order(
        'created_at',
        ascending: false,
      );

      final kardexItems =
          (movementsResponse as List).map((row) {
            final movement = InventoryMovementModel.fromJson(row);

            final variantJson = row['product_variants'];

            final warehouseJson = row['warehouses'];

            final variant =
                variantJson != null
                    ? ProductVariantModel.fromJson(
                      Map<String, dynamic>.from(variantJson),
                    )
                    : null;

            final productName =
                variantJson?['products']?['name']?.toString() ?? 'Producto';

            return KardexMovement(
              movement: movement,
              productName: productName,
              warehouseName:
                  warehouseJson?['name']?.toString() ?? 'Sin almacén',
              variant: variant,
            );
          }).toList();

      if (mounted) {
        setState(() {
          _movements = kardexItems;
          _currentPage = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: 'Error cargando movimientos: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openExitScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InventoryExitFormScreen()),
    );
    if (result == true) {
      _fetchMovements();
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'Fecha desconocida';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year  $hour:$minute';
    } catch (_) {
      return isoString;
    }
  }

  Widget _buildMovementBadge(String type) {
    final upperType = type.toUpperCase();
    bool isEntry = upperType.contains('IN') || upperType.contains('ENTRADA');
    bool isSale =
        upperType.contains('SALE') ||
        upperType.contains('VENTA') ||
        upperType.contains('ORDER');

    Color bgColor = isEntry ? Colors.green.shade50 : Colors.red.shade50;
    Color textColor = isEntry ? Colors.green.shade700 : Colors.red.shade700;
    String label = isEntry ? 'INGRESO' : 'SALIDA';

    if (isSale) {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
      label = 'VENTA';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _movements.length;
    final totalPages = total == 0 ? 1 : (total / _pageSize).ceil();
    final currentPage =
        _currentPage >= totalPages ? totalPages - 1 : _currentPage;
    final start = currentPage * _pageSize;
    final end =
        total == 0
            ? 0
            : ((start + _pageSize) > total ? total : (start + _pageSize));
    final pageItems =
        total == 0 ? <KardexMovement>[] : _movements.sublist(start, end);

    return AdminLayout(
      title: 'Kardex (Movimientos)',
      showBackButton: true,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                // Dropdown de tipo
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _typeFilter,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Todos')),
                          DropdownMenuItem(
                            value: 'ENTRY',
                            child: Text('Ingresos'),
                          ),
                          DropdownMenuItem(
                            value: 'EXIT',
                            child: Text('Salidas'),
                          ),
                          DropdownMenuItem(
                            value: 'SALE',
                            child: Text('Ventas'),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _typeFilter = val!);
                          _fetchMovements();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DateFilterButton(
                    dateRange: _dateRange,
                    onDateRangeSelected: (picked) {
                      setState(() => _dateRange = picked);
                      _fetchMovements();
                    },
                    onClear: () {
                      setState(() => _dateRange = null);
                      _fetchMovements();
                    },
                  ),
                ),
                if (_dateRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () {
                      setState(() => _dateRange = null);
                      _fetchMovements();
                    },
                  ),
                ],
              ],
            ),
          ),

          // --- LISTADO DE MOVIMIENTOS ---
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _movements.isEmpty
                    ? const AppEmptyState(
                      icon: Icons.history,
                      title: 'No hay movimientos',
                      message:
                          'Aún no se han registrado ingresos o salidas de inventario en estas fechas.',
                    )
                    : RefreshIndicator(
                      onRefresh: _fetchMovements,
                      color: AppColors.primary,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Row(
                              children: [
                                Text(
                                  'Mostrando ${total == 0 ? 0 : start + 1}-$end de $total',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Página ${currentPage + 1} / $totalPages',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // LISTA DE TARJETAS
                          Expanded(
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: pageItems.length,
                              itemBuilder: (context, index) {
                                final item = pageItems[index];
                                final move = item.movement;
                                final movementType = item.movementType;
                                final variant = item.variant;

                                final iconColor =
                                    item.isEntry
                                        ? Colors.green
                                        : (item.isSale
                                            ? Colors.blue
                                            : Colors.red);
                                final iconData =
                                    item.isEntry
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatDate(
                                                move.createdAt
                                                    ?.toIso8601String(),
                                              ),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            _buildMovementBadge(movementType),
                                          ],
                                        ),
                                        const Divider(height: 24),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: iconColor
                                                  .withValues(alpha: 0.1),
                                              child: Icon(
                                                iconData,
                                                color: iconColor,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.productName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  if (variant != null) ...[
                                                    const SizedBox(height: 4),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade100,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'Var: ${variant.label}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.warehouse,
                                                        size: 14,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade500,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          item.warehouseName,
                                                          style: TextStyle(
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade600,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                const Text(
                                                  'Cant.',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                Text(
                                                  '${item.isEntry ? '+' : ''}${move.quantity}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 20,
                                                    color: iconColor,
                                                  ),
                                                ),
                                                Text(
                                                  'Stock: ${move.previousStock} → ${move.newStock}',
                                                ),
                                                if (move.unitCost != null)
                                                  Text(
                                                    'Costo: S/ ${move.unitCost}',
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if ((item.referenceId != null) ||
                                            (move.notes != null &&
                                                move.notes!
                                                    .toString()
                                                    .isNotEmpty)) ...[
                                          const SizedBox(height: 16),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.grey.shade200,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (item.referenceId != null)
                                                  Text(
                                                    'ID Ref: ${item.referenceId}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontFamily: 'monospace',
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                if (move.notes != null &&
                                                    move.notes!
                                                        .toString()
                                                        .isNotEmpty) ...[
                                                  if (item.referenceId != null)
                                                    const SizedBox(height: 4),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Icon(
                                                        Icons.notes,
                                                        size: 14,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade500,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          move.notes ?? '',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade700,
                                                            fontStyle:
                                                                FontStyle
                                                                    .italic,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // CONTROLES DE PÁGINA
                          if (totalPages > 1)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                              child: AdminPageBlocks(
                                currentPage: _currentPage,
                                totalPages: totalPages,
                                onPageChanged:
                                    (page) =>
                                        setState(() => _currentPage = page),
                              ),
                            ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_in',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InventoryEntryFormScreen()),
              );
              _fetchMovements();
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text(
              'Ingreso',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'fab_out',
            onPressed: _openExitScreen,
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text(
              'Salida',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
