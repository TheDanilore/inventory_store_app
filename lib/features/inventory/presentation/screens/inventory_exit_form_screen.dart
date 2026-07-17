import 'package:flutter/material.dart';
import 'dart:ui' as dart_ui;
import 'package:cached_network_image/cached_network_image.dart';

import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product_sheet.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form_state.dart';

class InventoryExitFormScreen extends StatefulWidget {
  const InventoryExitFormScreen({super.key});

  @override
  State<InventoryExitFormScreen> createState() =>
      _InventoryExitFormScreenState();
}

class _InventoryExitFormScreenState extends State<InventoryExitFormScreen> {
  InventoryExitFormCubit get cubit => context.read<InventoryExitFormCubit>();
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

  Future<void> _showAddProductSheet() async {
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
          (context) => AddExitProductSheet(
            allProducts: cubit.state.allProducts,
            variantsByProduct: cubit.state.variantsByProduct,
            warehouseId: cubit.state.selectedWarehouseId!,
          ),
    );

    if (newItem != null && mounted) {
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

  Future<void> _saveExit() async {
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
                TextField(
                  controller: confirmCtrl,
                  textCapitalization: TextCapitalization.characters,
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

    await cubit.saveExit(_notesCtrl.text.trim());
    if (!mounted) return;

    if (cubit.state.isSuccess) {
      AppSnackbar.show(
        context,
        message: 'Salida de inventario registrada con éxito.',
        type: SnackbarType.success,
      );
      Navigator.pop(context, true);
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (cubit.state.items.isEmpty || cubit.state.isSaving) {
          if (cubit.state.items.isEmpty) cubit.clearDraft();
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
          cubit.clearDraft();
          Navigator.pop(context, result);
        } else if (action == 'draft') {
          Navigator.pop(context, result);
        }
      },
      child: BlocBuilder<InventoryExitFormCubit, InventoryExitFormState>(
        builder: (context, state) {
          final cubit = context.read<InventoryExitFormCubit>();
          if (cubit.state.isLoading) {
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
                cubit.state.isSaving
                    ? const Center(
                      child: CircularProgressIndicator(color: AppColors.danger),
                    )
                    : Stack(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isTablet = constraints.maxWidth >= 800;
                            return isTablet
                                ? _buildTabletLayout(context, state)
                                : _buildMobileLayout(context, state);
                          },
                        ),
                        _buildBottomActionButton(cubit),
                      ],
                    ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // LAYOUTS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout(
    BuildContext context,
    InventoryExitFormState state,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGeneralInfoSection(cubit),
          const SizedBox(height: 16),
          _buildProductsSection(cubit),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(
    BuildContext context,
    InventoryExitFormState state,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Settings)
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 12, 100),
            child: _buildGeneralInfoSection(cubit),
          ),
        ),
        // Right Column (Products)
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 24, 24, 100),
            child: _buildProductsSection(cubit),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SECTIONS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildGeneralInfoSection(InventoryExitFormCubit cubit) {
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
            initialValue: cubit.state.selectedWarehouseId,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: _dropdownDecoration(
              'Almacén de Origen',
              icon: Icons.warehouse_rounded,
            ),
            items:
                cubit.state.warehouses
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
            initialValue: cubit.state.selectedReason,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: _dropdownDecoration(
              'Motivo de Salida',
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
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(InventoryExitFormCubit cubit) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Expanded(
                      child: _SectionTitle(
                        icon: Icons.inventory_2_rounded,
                        title: 'Productos a Retirar',
                        iconColor: AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${cubit.state.items.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _showAddProductSheet,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text(
                  'Retirar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                  foregroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child:
                cubit.state.items.isEmpty
                    ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.border,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.outbox_rounded,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Sin productos a retirar',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cubit.state.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder:
                          (context, index) => _buildItemCard(
                            cubit,
                            cubit.state.items[index],
                            index,
                          ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    InventoryExitFormCubit cubit,
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

    final bool isBatchMissing =
        item.product.usesBatches &&
        (batchNumber == 'DEFAULT' || batchNumber.trim().isEmpty);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBatchMissing ? AppColors.danger : AppColors.border,
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
          const SizedBox(width: 12),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
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
                ),
                if (item.product.usesBatches)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isBatchMissing
                                ? AppColors.danger.withValues(alpha: 0.1)
                                : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isBatchMissing
                            ? '⚠ Lote Requerido'
                            : 'Lote: $batchNumber',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color:
                              isBatchMissing
                                  ? AppColors.danger
                                  : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _VerticalStepper(
            value: item.quantity.toInt(),
            onAdd:
                item.quantity < maxAvailable
                    ? () => cubit.updateQuantity(index, item.quantity + 1)
                    : null,
            onRemove:
                item.quantity > 1
                    ? () => cubit.updateQuantity(index, item.quantity - 1)
                    : null,
            onTapValue:
                () => _showQuantityDialog(index, item.quantity, maxAvailable),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
            ),
            onPressed: () => cubit.removeItem(index),
            tooltip: 'Eliminar ítem',
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // FIXED BOTTOM BUTTON
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildBottomActionButton(InventoryExitFormCubit cubit) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.8),
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
            ),
            child: SafeArea(
              top: false,
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
                            '${cubit.state.items.length} items · ${cubit.state.totalUnits} unidades retiradas',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'S/ ${cubit.state.totalLossCost.toStringAsFixed(2)}',
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
                          cubit.state.items.isNotEmpty ? _saveExit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        disabledBackgroundColor: AppColors.border,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
                          fontSize: 16,
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
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // UTILS
  // ════════════════════════════════════════════════════════════════════════════

  InputDecoration _dropdownDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      filled: true,
      fillColor: AppColors.surface,
      prefixIcon:
          icon != null ? Icon(icon, color: AppColors.primary, size: 20) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}

// ── WIDGETS AUXILIARES ──
class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
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
            borderRadius: BorderRadius.circular(10),
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

class _VerticalStepper extends StatelessWidget {
  final int value;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onTapValue;

  const _VerticalStepper({
    required this.value,
    this.onAdd,
    this.onRemove,
    this.onTapValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAdd,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 20,
                  color:
                      onAdd != null ? AppColors.textPrimary : AppColors.border,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onTapValue,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Text(
                '$value',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onRemove,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color:
                      onRemove != null
                          ? AppColors.textPrimary
                          : AppColors.border,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
