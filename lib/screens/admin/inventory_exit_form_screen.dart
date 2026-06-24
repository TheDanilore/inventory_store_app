import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/providers/admin/inventory_exit_form_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/inventory_exits/add_exit_product_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:provider/provider.dart';

class InventoryExitFormScreen extends StatefulWidget {
  const InventoryExitFormScreen({super.key});

  @override
  State<InventoryExitFormScreen> createState() =>
      _InventoryExitFormScreenState();
}

class _InventoryExitFormScreenState extends State<InventoryExitFormScreen> {
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryExitFormProvider>().loadInitialData();
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddProductSheet() async {
    final provider = context.read<InventoryExitFormProvider>();
    if (provider.selectedWarehouseId == null) {
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
            allProducts: provider.allProducts,
            variantsByProduct: provider.variantsByProduct,
            warehouseId: provider.selectedWarehouseId!,
          ),
    );

    if (newItem != null && mounted) {
      provider.addItem(newItem);
    }
  }

  Future<void> _showQuantityDialog(
    int index,
    double cantidadActual,
    double maxAvailable,
  ) async {
    final provider = context.read<InventoryExitFormProvider>();
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
                    final qty = newQty > maxAvailable ? maxAvailable : newQty;
                    provider.updateQuantity(index, qty);
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
    final provider = context.read<InventoryExitFormProvider>();

    if (provider.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione un almacén',
        type: SnackbarType.warning,
      );
      return;
    }
    if (provider.items.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Agregue al menos un producto a retirar',
        type: SnackbarType.warning,
      );
      return;
    }

    // Modal de Confirmación Estricta (CONFIRMAR)
    final confirmCtrl = TextEditingController();
    bool isConfirmed = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_rounded, color: AppColors.danger, size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Confirmar Salida Múltiple',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estás a punto de confirmar una pérdida valorizada de S/ ${provider.totalLossCost.toStringAsFixed(2)}. Esto impactará directamente el inventario físico.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Para autorizar, escribe la palabra CONFIRMAR (en mayúsculas):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmCtrl,
                  decoration: InputDecoration(
                    hintText: 'CONFIRMAR',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
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
                  if (confirmCtrl.text.trim() == 'CONFIRMAR') {
                    isConfirmed = true;
                    Navigator.pop(ctx);
                  } else {
                    AppSnackbar.show(
                      ctx,
                      message: 'Debes escribir CONFIRMAR correctamente',
                      type: SnackbarType.error,
                    );
                  }
                },
                child: const Text(
                  'Autorizar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );

    confirmCtrl.dispose();

    if (!isConfirmed) return;

    final success = await provider.saveExit(_notesCtrl.text.trim());
    if (!mounted) return;

    if (success) {
      AppSnackbar.show(
        context,
        message: 'Salida de inventario registrada con éxito.',
        type: SnackbarType.success,
      );
      Navigator.pop(context, true);
    } else if (provider.errorMessage != null) {
      AppSnackbar.show(
        context,
        message: provider.errorMessage!,
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final provider = context.read<InventoryExitFormProvider>();

        if (provider.items.isEmpty || provider.isSaving) {
          if (provider.items.isEmpty) provider.clearDraft();
          Navigator.pop(context, result);
          return;
        }

        final action = await showDialog<String>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Cambios sin guardar'),
                content: const Text(
                  'Tienes un registro en curso. ¿Qué deseas hacer al salir?',
                ),
                actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, 'cancel'),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, 'discard'),
                        child: const Text(
                          'Descartar',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, 'draft'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Borrador'),
                      ),
                    ],
                  ),
                ],
              ),
        );

        if (!context.mounted) return;

        if (action == 'discard') {
          provider.clearDraft();
          Navigator.pop(context, result);
        } else if (action == 'draft') {
          Navigator.pop(context, result);
        }
      },
      child: Consumer<InventoryExitFormProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const AdminLayout(
              title: 'Nueva Salida',
              showBackButton: true,
              showProfileButton: false,
              showDrawerButton: false,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.danger),
              ),
            );
          }

          return AdminLayout(
            title: 'Registrar Salida',
            showBackButton: true,
            showProfileButton: false,
            showDrawerButton: false,
            body:
                provider.isSaving
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        initialValue:
                                            provider.selectedWarehouseId,
                                        decoration: _dropdownDeco(
                                          'Almacén de Origen',
                                          Icons.warehouse_rounded,
                                        ),
                                        items:
                                            provider.warehouses
                                                .map(
                                                  (w) => DropdownMenuItem(
                                                    value: w.id,
                                                    child: Text(
                                                      w.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: provider.selectWarehouse,
                                      ),
                                      const SizedBox(height: 12),

                                      DropdownButtonFormField<String>(
                                        initialValue: provider.selectedReason,
                                        decoration: _dropdownDeco(
                                          'Motivo de Salida',
                                          Icons.assignment_late_rounded,
                                        ),
                                        items:
                                            [
                                                  'AJUSTE',
                                                  'MERMA',
                                                  'DAÑO',
                                                  'VENCIMIENTO',
                                                  'ROBO/PÉRDIDA',
                                                  'CONSUMO INTERNO',
                                                ]
                                                .map(
                                                  (r) => DropdownMenuItem(
                                                    value: r,
                                                    child: Text(
                                                      r,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            provider.selectReason(v);
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.inventory_2_rounded,
                                            size: 18,
                                            color: AppColors.danger,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Items (${provider.items.length})',
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.danger,
                                        backgroundColor: AppColors.danger
                                            .withValues(alpha: 0.1),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                if (provider.items.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 40,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
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
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: provider.items.length,
                                    separatorBuilder:
                                        (_, _) => const SizedBox(height: 10),
                                    itemBuilder:
                                        (context, index) => _buildItemCard(
                                          provider,
                                          provider.items[index],
                                          index,
                                        ),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          '${provider.items.length} items · ${provider.totalUnits} unidades retiradas',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'S/ ${provider.totalLossCost.toStringAsFixed(2)}',
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
                                    onPressed:
                                        provider.items.isNotEmpty
                                            ? _saveExit
                                            : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.danger,
                                      disabledBackgroundColor:
                                          AppColors.background,
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
        },
      ),
    );
  }

  Widget _buildItemCard(
    InventoryExitFormProvider provider,
    ExitItemUI item,
    int index,
  ) {
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

    final attrValues =
        item.variant.attributeValues.map((v) => v.value).toList();
    final attrsText = attrValues.join(' · ');
    final displayVariantText = attrsText.isNotEmpty ? attrsText : 'Única';
    final batchNumber = item.selectedBatch?['batch_number'] ?? 'DEFAULT';
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
                        placeholder:
                            (context, url) => const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => const Icon(
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
                if (item.product.usesBatches &&
                    (batchNumber == 'DEFAULT' ||
                        batchNumber.trim().isEmpty)) ...[
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        size: 12,
                        color: AppColors.danger,
                      ),
                      SizedBox(width: 4),
                      Text(
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
                    ? () => provider.updateQuantity(index, item.quantity + 1)
                    : null,
            onRemove:
                item.quantity > 1
                    ? () => provider.updateQuantity(index, item.quantity - 1)
                    : null,
            onTapValue:
                () => _showQuantityDialog(
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
            onPressed: () => provider.removeItem(index),
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
          color: AppColors.primary.withValues(alpha: 0.06),
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
}
