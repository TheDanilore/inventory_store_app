import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product_sheet.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_state.dart';

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
      context.read<InventoryExitFormCubit>().loadInitialData();
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddProductSheet(BuildContext context) async {
    final cubit = context.read<InventoryExitFormCubit>();
    if (cubit.state.selectedWarehouseId == null) {
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
          (_) => AddExitProductSheet(
            allProducts: cubit.state.allProducts,
            variantsByProduct: cubit.state.variantsByProduct,
            warehouseId: cubit.state.selectedWarehouseId!,
          ),
    );

    if (!context.mounted) return;

    if (newItem != null) {
      cubit.addItem(newItem);
    }
  }

  Future<void> _showQuantityDialog(
    int index,
    double cantidadActual,
    double maxAvailable,
  ) async {
    final cubit = context.read<InventoryExitFormCubit>();
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Máximo disponible: ${maxAvailable.toInt()}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
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
                    cubit.updateQuantity(index, qty);
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

  Future<void> _handleClearDraft(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Descartar Borrador'),
            content: const Text(
              '¿Estás seguro de que quieres limpiar la salida actual? Perderás todos los ítems agregados.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Descartar',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
    );

    if (!context.mounted) return;

    if (confirm == true) {
      context.read<InventoryExitFormCubit>().clearDraft();
      _notesCtrl.clear();
      AppSnackbar.show(
        context,
        message: 'Borrador descartado',
        type: SnackbarType.info,
      );
    }
  }

  Future<void> _saveExit(BuildContext context) async {
    final cubit = context.read<InventoryExitFormCubit>();

    if (cubit.state.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione un almacén',
        type: SnackbarType.warning,
      );
      return;
    }
    if (cubit.state.items.isEmpty) {
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
    final formKey = GlobalKey<FormState>();

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
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estás a punto de confirmar una pérdida valorizada de S/ ${cubit.state.totalLossCost.toStringAsFixed(2)}. Esto impactará directamente el inventario físico.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Para autorizar, escribe la palabra CONFIRMAR:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: confirmCtrl,
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim() != 'CONFIRMAR') {
                        return 'Debes escribir CONFIRMAR correctamente';
                      }
                      return null;
                    },
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
                  if (formKey.currentState?.validate() ?? false) {
                    isConfirmed = true;
                    Navigator.pop(ctx);
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

    if (!context.mounted) return;
    if (!isConfirmed) return;

    await cubit.saveExit(_notesCtrl.text.trim());

    if (!context.mounted) return;

    if (cubit.state.isSuccess) {
      AppSnackbar.show(
        context,
        message: 'Salida de inventario registrada con éxito.',
        type: SnackbarType.success,
      );
      if (!context.mounted) return;
      context.go('/admin/inventory-exits');
    } else {
      AppSnackbar.show(
        context,
        message: cubit.state.errorMessage,
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryExitFormCubit, InventoryExitFormState>(
      builder: (context, state) {
        final cubit = context.read<InventoryExitFormCubit>();

        if (state.isLoading) {
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

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            if (state.items.isEmpty) {
              cubit.clearDraft();
              if (context.canPop()) {
                context.pop(result);
              } else {
                context.go('/admin/kardex');
              }
              return;
            }

            final action = await showDialog<String>(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text('Salida en progreso'),
                    content: const Text(
                      'Tienes productos en la salida actual. ¿Qué deseas hacer al salir?',
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
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
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
              cubit.clearDraft();
              if (context.canPop()) {
                context.pop(result);
              } else {
                context.go('/admin/kardex');
              }
            } else if (action == 'draft') {
              if (context.canPop()) {
                context.pop(result);
              } else {
                context.go('/admin/kardex');
              }
            }
          },
          child: AdminLayout(
            title: 'Registrar Salida',
            showBackButton: true,
            showProfileButton: false,
            showDrawerButton: false,
            body:
                state.isSaving
                    ? const Center(
                      child: CircularProgressIndicator(color: AppColors.danger),
                    )
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 900;

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Izquierda: Datos de Origen y Justificación
                              Expanded(
                                flex: 5,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                  ),
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(24.0),
                                    child: _buildGeneralInfoSection(
                                      context,
                                      state,
                                    ),
                                  ),
                                ),
                              ),
                              // Derecha: Productos y Botón Guardar
                              Expanded(
                                flex: 4,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(24.0),
                                        child: _buildProductsSection(
                                          context,
                                          state,
                                        ),
                                      ),
                                    ),
                                    _buildStickySaveButton(context, state),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        // Móvil
                        return Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildGeneralInfoSection(context, state),
                                    const SizedBox(height: 16),
                                    _buildProductsSection(context, state),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ),
                            _buildStickySaveButton(context, state),
                          ],
                        );
                      },
                    ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SECCIONES
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildGeneralInfoSection(
    BuildContext context,
    InventoryExitFormState state,
  ) {
    final cubit = context.read<InventoryExitFormCubit>();
    final validWarehouseId =
        state.warehouses.any((w) => w.id == state.selectedWarehouseId)
            ? state.selectedWarehouseId
            : null;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.output_rounded,
            title: 'Información General',
            iconColor: AppColors.danger,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('warehouse_$validWarehouseId'),
            initialValue: validWarehouseId,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: _dropdownDecoration(
              'Almacén de Origen (Obligatorio)',
              icon: Icons.warehouse_rounded,
            ),
            items:
                state.warehouses
                    .map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(
                          w.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: cubit.selectWarehouse,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: state.selectedReason,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: _dropdownDecoration(
              'Motivo de Salida (Obligatorio)',
              icon: Icons.assignment_late_rounded,
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
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (v) {
              if (v != null) cubit.selectReason(v);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notas / Justificación (Opcional)',
              hintText: 'Ej: Botellas rotas durante traslado',
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(
    BuildContext context,
    InventoryExitFormState state,
  ) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: _SectionTitle(
                  icon: Icons.inventory_2_rounded,
                  title: 'Productos a Retirar',
                  iconColor: AppColors.danger,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _showAddProductSheet(context),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Agregar'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  if (state.items.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: 'Más opciones',
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onSelected: (value) {
                        if (value == 'clear') _handleClearDraft(context);
                      },
                      itemBuilder:
                          (_) => [
                            const PopupMenuItem(
                              value: 'clear',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_sweep_rounded,
                                    color: AppColors.danger,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Descartar todo',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ],
                              ),
                            ),
                          ],
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.outbox_rounded,
                    size: 52,
                    color: AppColors.danger.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Sin productos a retirar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Agrega los productos que vas a dar de baja de tu inventario',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => _showAddProductSheet(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar primer producto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                return _buildItemCard(context, state, index);
              },
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            child:
                state.items.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _ExitFormSummaryCard(state: state),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    InventoryExitFormState state,
    int index,
  ) {
    final item = state.items[index];
    final cubit = context.read<InventoryExitFormCubit>();

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

    final bool isBatchMissing =
        item.product.usesBatches &&
        (batchNumber == 'DEFAULT' || batchNumber.trim().isEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBatchMissing ? AppColors.danger : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen
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
                              size: 20,
                              color: AppColors.textMuted,
                            ),
                      )
                      : const Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.textMuted,
                      ),
            ),
          ),
          const SizedBox(width: 16),
          // Detalles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Variante: $displayVariantText',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (item.product.usesBatches)
                  Text(
                    isBatchMissing ? '⚠ Lote Requerido' : 'Lote: $batchNumber',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isBatchMissing ? FontWeight.bold : FontWeight.normal,
                      color:
                          isBatchMissing
                              ? AppColors.danger
                              : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Controles + Acciones
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _HorizontalStepper(
                value: item.quantity.toInt(),
                onAdd:
                    item.quantity < maxAvailable
                        ? () {
                          cubit.updateQuantity(index, item.quantity + 1);
                        }
                        : null,
                onRemove:
                    item.quantity > 1
                        ? () {
                          cubit.updateQuantity(index, item.quantity - 1);
                        }
                        : null,
                onTapValue:
                    () =>
                        _showQuantityDialog(index, item.quantity, maxAvailable),
              ),
              const SizedBox(height: 8),
              Text(
                'S/ ${item.totalCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
                onPressed: () {
                  cubit.removeItem(index);
                },
                tooltip: 'Eliminar ítem',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STICKY BOTTOM BUTTON (Guardar)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildStickySaveButton(
    BuildContext context,
    InventoryExitFormState state,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    state.items.isEmpty ? null : () => _saveExit(context),
                icon: const Icon(Icons.output_rounded),
                label: const Text(
                  'Confirmar Salida',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── WIDGETS AUXILIARES ──

InputDecoration _dropdownDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    filled: true,
    fillColor: AppColors.background,
    prefixIcon:
        icon != null ? Icon(icon, color: AppColors.textMuted, size: 20) : null,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _HorizontalStepper extends StatelessWidget {
  final int value;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onTapValue;

  const _HorizontalStepper({
    required this.value,
    this.onAdd,
    this.onRemove,
    this.onTapValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.remove_rounded,
              size: 16,
              color:
                  onRemove != null ? AppColors.textPrimary : AppColors.border,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onRemove,
          ),
          GestureDetector(
            onTap: onTapValue,
            child: Container(
              constraints: const BoxConstraints(minWidth: 32),
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.add_rounded,
              size: 16,
              color: onAdd != null ? AppColors.textPrimary : AppColors.border,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ExitFormSummaryCard extends StatelessWidget {
  final InventoryExitFormState state;

  const _ExitFormSummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de Salida (Pérdida)',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            'S/ ${state.totalLossCost.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white24, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Productos/Variantes',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    '${state.items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unidades Totales',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    '${state.totalUnits}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
