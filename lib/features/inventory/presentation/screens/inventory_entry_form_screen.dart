import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_state.dart';

import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/entry_item_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_order_items_table.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/utils/app_back_handler.dart';
import 'package:inventory_store_app/core/utils/hardware_barcode_gun_detector.dart';
import 'package:inventory_store_app/features/pos/presentation/services/pos_barcode_scanner_service.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';

class InventoryEntryFormScreen extends StatefulWidget {
  final String? purchaseOrderId;
  final List<InventoryEntryItemEntity>? prefillItems;
  final String? prefillSupplierId;
  final String? prefillSupplierName;
  final String? prefillWarehouseId;

  final String? prefillDocumentType;
  final String? prefillDocumentNumber;
  final DateTime? prefillDocumentDate;

  const InventoryEntryFormScreen({
    super.key,
    this.purchaseOrderId,
    this.prefillItems,
    this.prefillSupplierId,
    this.prefillSupplierName,
    this.prefillWarehouseId,
    this.prefillDocumentType,
    this.prefillDocumentNumber,
    this.prefillDocumentDate,
  });

  @override
  State<InventoryEntryFormScreen> createState() =>
      _InventoryEntryFormScreenState();
}

class _InventoryEntryFormScreenState extends State<InventoryEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _documentNumberCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _gunDetector = HardwareBarcodeGunDetector();

  // valor interno -> etiqueta visible
  static const Map<String, String> _docTypes = {
    'NINGUNO': 'Ninguno',
    'FACTURA': 'Factura',
    'BOLETA': 'Boleta',
    'GUIA_REMISION': 'Guía de remisión',
    'TICKET': 'Ticket',
  };

  @override
  void initState() {
    super.initState();
    if (widget.prefillDocumentNumber != null) {
      _documentNumberCtrl.text = widget.prefillDocumentNumber!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final cubit = context.read<InventoryEntryFormCubit>();
    cubit.init(
      purchaseOrderId: widget.purchaseOrderId,
      prefillItems: widget.prefillItems,
      prefillSupplierId: widget.prefillSupplierId,
      prefillWarehouseId: widget.prefillWarehouseId,
      prefillDocumentType: widget.prefillDocumentType,
      prefillDocumentNumber: widget.prefillDocumentNumber,
      prefillDocumentDate: widget.prefillDocumentDate,
    );
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _documentNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocumentDate(BuildContext context) async {
    final cubit = context.read<InventoryEntryFormCubit>();
    final picked = await showDatePicker(
      context: context,
      initialDate: cubit.state.documentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha del Documento Físico',
    );
    if (picked != null) {
      cubit.setDocumentDate(picked);
    }
  }

  Future<void> _showAddProductSheet(BuildContext context) async {
    final cubit = context.read<InventoryEntryFormCubit>();
    if (cubit.state.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione un almacén destino primero',
        type: SnackbarType.warning,
      );
      return;
    }

    final newItem = await AddEntryProductSheet.show(
      context,
      warehouseId: cubit.state.selectedWarehouseId,
      // Permite cargar varios productos sin cerrar y reabrir el panel.
      onAddAndContinue: (item) => cubit.addItem(item),
    );

    if (newItem != null && mounted) {
      cubit.addItem(newItem);
    }
  }

  Future<void> _scanAndAddProduct(BuildContext context) async {
    final cubit = context.read<InventoryEntryFormCubit>();
    if (cubit.state.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione un almacén destino primero',
        type: SnackbarType.warning,
      );
      return;
    }

    await PosCameraScannerDialog.show(
      context,
      warehouseId: cubit.state.selectedWarehouseId,
      title: 'Escanear Entradas a Almacén',
      continuousMode: true,
      onContinuousScan: (res) async {
        final product = res.product;
        final targetVariant = res.variant ?? product.defaultVariant;

        final existingIndex = cubit.state.items.indexWhere(
          (item) =>
              item.productId == product.id &&
              (targetVariant == null || item.variantId == targetVariant.id),
        );

        if (existingIndex != -1) {
          final currentItem = cubit.state.items[existingIndex];
          cubit.updateItemQuantity(existingIndex, currentItem.quantity + 1);
        } else {
          final entryItem = InventoryEntryItemEntity(
            productId: product.id,
            productName: product.name,
            variantId: targetVariant?.id ?? product.id,
            variantLabel:
                targetVariant?.label ?? targetVariant?.sku ?? 'Estándar',
            usesBatches: product.usesBatches,
            quantity: 1.0,
            unitCost: targetVariant?.unitCost ?? 0.0,
            batchNumber: '',
            expiryDate: null,
            imageUrl: product.primaryImageUrl,
          );
          cubit.addItem(entryItem);
        }
      },
    );
  }

  Future<void> _handleGunBarcode(String rawBarcode) async {
    final cubit = context.read<InventoryEntryFormCubit>();
    if (cubit.state.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Seleccione un almacén destino primero para escanear',
        type: SnackbarType.warning,
      );
      return;
    }

    final res = await PosBarcodeScannerService.resolveCode(
      rawBarcode,
      warehouseId: cubit.state.selectedWarehouseId,
    );
    if (!mounted) return;
    if (res == null) {
      AppSnackbar.show(
        context,
        message: 'Código "$rawBarcode" no encontrado en catálogo',
        type: SnackbarType.error,
      );
      return;
    }

    final product = res.product;
    final targetVariant = res.variant ?? product.defaultVariant;

    final existingIndex = cubit.state.items.indexWhere(
      (item) =>
          item.productId == product.id &&
          (targetVariant == null || item.variantId == targetVariant.id),
    );

    HapticFeedback.mediumImpact();
    if (existingIndex != -1) {
      final currentItem = cubit.state.items[existingIndex];
      cubit.updateItemQuantity(existingIndex, currentItem.quantity + 1);
      AppSnackbar.show(
        context,
        message: '+1 a "${product.name}"',
        type: SnackbarType.info,
      );
    } else {
      final entryItem = InventoryEntryItemEntity(
        productId: product.id,
        productName: product.name,
        variantId: targetVariant?.id ?? product.id,
        variantLabel: targetVariant?.label ?? targetVariant?.sku ?? 'Estándar',
        usesBatches: product.usesBatches,
        quantity: 1.0,
        unitCost: targetVariant?.unitCost ?? 0.0,
        batchNumber: '',
        expiryDate: null,
        imageUrl: product.primaryImageUrl,
      );
      cubit.addItem(entryItem);
      AppSnackbar.show(
        context,
        message: 'Agregado: "${product.name}"',
        type: SnackbarType.success,
      );
    }
  }

  /// Quita el producto al instante y ofrece "Deshacer" (en vez de un diálogo
  /// de confirmación que interrumpe cada vez).
  void _removeItemWithUndo(InventoryEntryFormCubit cubit, int index) {
    final items = cubit.state.items;
    if (index < 0 || index >= items.length) return;
    final removed = items[index];

    HapticFeedback.lightImpact();
    cubit.removeItem(index);

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Quitaste "${removed.productName}"'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        // Deja libre la barra inferior con el botón de confirmar.
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            if (mounted) cubit.addItem(removed);
          },
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final cubit = context.read<InventoryEntryFormCubit>();

    cubit.setDocumentNumber(_documentNumberCtrl.text.trim());

    if (!mounted) return;

    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      AppSnackbar.show(
        context,
        message: 'Por favor complete los campos obligatorios del formulario',
        type: SnackbarType.warning,
      );
      return;
    }

    final activeShiftId = cubit.state.activeShiftId ?? "";

    if (!cubit.validate(activeShiftId)) {
      AppSnackbar.show(
        context,
        message: cubit.state.errorMessage,
        type: SnackbarType.error,
      );
      return;
    }

    await cubit.saveEntry(_notesCtrl.text.trim());
    if (!mounted) return;

    if (cubit.state.isSuccess) {
      AppSnackbar.show(
        context,
        message:
            widget.purchaseOrderId != null
                ? 'Recepción registrada. Kardex y Orden actualizados.'
                : 'Ingreso manual registrado correctamente.',
        type: SnackbarType.success,
      );
      if (!mounted) return;
      if (widget.purchaseOrderId != null) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else {
          context.go('/purchase-orders?selectedId=${widget.purchaseOrderId}');
        }
      } else {
        context.go('/inventory-entries');
      }
    } else if (cubit.state.errorMessage.isNotEmpty) {
      AppSnackbar.show(
        context,
        message: cubit.state.errorMessage,
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _handleClearDraft() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Descartar Borrador'),
            content: const Text(
              '¿Estás seguro de que quieres limpiar los productos ingresados?',
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

    if (confirm == true && mounted) {
      context.read<InventoryEntryFormCubit>().clearDraft();
      _documentNumberCtrl.clear();
      _notesCtrl.clear();
      AppSnackbar.show(
        context,
        message: 'Borrador descartado',
        type: SnackbarType.info,
      );
    }
  }

  Future<void> _handleBackButton() async {
    final cubit = context.read<InventoryEntryFormCubit>();
    if (cubit.state.isSaving) return;

    if (widget.purchaseOrderId != null) {
      _exitForm();
      return;
    }

    if (cubit.state.items.isEmpty) {
      cubit.clearDraft();
      _exitForm();
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
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'cancel'),
                    child: const Text('Seguir editando'),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Guardar borrador'),
                  ),
                ],
              ),
            ],
          ),
    );

    if (!mounted) return;

    if (action == 'discard') {
      cubit.clearDraft();
      _exitForm();
    } else if (action == 'draft') {
      _exitForm();
    }
  }

  // Sale del formulario hacia donde se vino (pop real o historial de AppBackHandler).
  void _exitForm([Object? result]) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    } else {
      AppBackHandler.handleBack(context); // sin onCustomBack → usa el historial
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        final barcode = _gunDetector.onKeyEvent(event);
        if (barcode != null) {
          _handleGunBarcode(barcode);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _handleBackButton();
        },
        child: BlocConsumer<InventoryEntryFormCubit, InventoryEntryFormState>(
          listenWhen:
              (prev, curr) => prev.documentNumber != curr.documentNumber,
          listener: (context, state) {
            if (state.documentNumber != null &&
                _documentNumberCtrl.text != state.documentNumber) {
              _documentNumberCtrl.text = state.documentNumber!;
            }
          },
          buildWhen:
              (prev, curr) =>
                  prev.isLoading != curr.isLoading ||
                  prev.isSaving != curr.isSaving ||
                  prev.errorMessage != curr.errorMessage ||
                  prev.warehouses != curr.warehouses ||
                  prev.suppliers != curr.suppliers ||
                  prev.accounts != curr.accounts ||
                  prev.activeShiftsByAccount != curr.activeShiftsByAccount ||
                  prev.activeShiftId != curr.activeShiftId ||
                  prev.selectedWarehouseId != curr.selectedWarehouseId ||
                  prev.selectedSupplierId != curr.selectedSupplierId ||
                  prev.paymentMode != curr.paymentMode ||
                  prev.documentType != curr.documentType ||
                  prev.documentDate != curr.documentDate ||
                  prev.selectedAccountId != curr.selectedAccountId ||
                  prev.items != curr.items,
          builder: (context, state) {
            final cubit = context.read<InventoryEntryFormCubit>();
            if (cubit.state.isLoading) {
              return AdminLayout(
                title: 'Entrada de Inventario',
                showBackButton: true,
                onBack: _handleBackButton,
                showProfileButton: false,
                showDrawerButton: false,
                body: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }

            if (!cubit.state.isLoading &&
                cubit.state.errorMessage.isNotEmpty &&
                cubit.state.warehouses.isEmpty) {
              return AdminLayout(
                title:
                    widget.purchaseOrderId != null
                        ? 'Recepción de Orden'
                        : 'Nueva Entrada Manual',
                showBackButton: true,
                onBack: _handleBackButton,
                showProfileButton: false,
                showDrawerButton: false,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Error al cargar catálogos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cubit.state.errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadInitialData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return AdminLayout(
              title:
                  widget.purchaseOrderId != null
                      ? 'Recepción de Orden'
                      : 'Nueva Entrada Manual',
              showBackButton: true,
              onBack: _handleBackButton,
              showProfileButton: false,
              showDrawerButton: false,
              body: Stack(
                children: [
                  AbsorbPointer(
                    absorbing: cubit.state.isSaving,
                    child: Form(
                      key: _formKey,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Izquierda: Datos, Finanzas, Documento (40%)
                                Expanded(
                                  flex: 4,
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
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildMainDataSection(
                                            context,
                                            state,
                                            cubit,
                                          ),
                                          const SizedBox(height: 16),
                                          if (widget.purchaseOrderId ==
                                              null) ...[
                                            _buildFinanceSection(
                                              context,
                                              state,
                                              cubit,
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                          _buildDocumentSection(
                                            context,
                                            state,
                                            cubit,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Derecha: Productos y Botón Guardar (60%)
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.all(24.0),
                                          child: _buildProductsSection(
                                            context,
                                            state,
                                            cubit,
                                            isDesktop: true,
                                          ),
                                        ),
                                      ),
                                      _buildStickySaveButton(
                                        context,
                                        state,
                                        cubit,
                                      ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildMainDataSection(
                                        context,
                                        state,
                                        cubit,
                                      ),
                                      const SizedBox(height: 16),
                                      if (widget.purchaseOrderId == null) ...[
                                        _buildFinanceSection(
                                          context,
                                          state,
                                          cubit,
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      _buildDocumentSection(
                                        context,
                                        state,
                                        cubit,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildProductsSection(
                                        context,
                                        state,
                                        cubit,
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              ),
                              _buildStickySaveButton(context, state, cubit),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  if (cubit.state.isSaving)
                    Positioned.fill(
                      child: ColoredBox(
                        color: AppColors.surface.withValues(alpha: 0.7),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SECTIONS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildMainDataSection(
    BuildContext context,
    InventoryEntryFormState state,
    InventoryEntryFormCubit cubit,
  ) {
    final selectedWhIdRaw = cubit.state.selectedWarehouseId;
    final hasWhInList = cubit.state.warehouses.any(
      (w) => w.id == selectedWhIdRaw,
    );

    final warehouseItems = <DropdownMenuItem<String>>[
      if (selectedWhIdRaw != null && !hasWhInList)
        DropdownMenuItem<String>(
          value: selectedWhIdRaw,
          child: Text(
            'Almacén de la Orden${!hasWhInList ? ' (inactivo)' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ...cubit.state.warehouses.map(
        (w) => DropdownMenuItem(
          value: w.id,
          child: Text(
            w.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ];

    final selectedSupId = cubit.state.selectedSupplierId;
    final hasSupInList = cubit.state.suppliers.any(
      (s) => s.id == selectedSupId,
    );

    final supplierItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Ninguno (Ajuste/Directo)'),
      ),
      if (selectedSupId != null && !hasSupInList)
        DropdownMenuItem<String?>(
          value: selectedSupId,
          child: Text(
            widget.prefillSupplierName ?? 'Proveedor de Orden',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ...cubit.state.suppliers.map(
        (s) => DropdownMenuItem<String?>(
          value: s.id,
          child: Text(
            s.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ];

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.storefront_rounded,
            title: 'Datos principales',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(
              'wh_${selectedWhIdRaw}_${cubit.state.warehouses.length}',
            ),
            initialValue: selectedWhIdRaw,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: _dropdownDecoration(
              'Almacén Destino',
              icon: Icons.warehouse_rounded,
            ),
            hint: const Text(
              'Seleccione almacén destino',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            items: warehouseItems,
            onChanged: cubit.setWarehouse,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Debe seleccionar un almacén destino';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            key: ValueKey(
              'sup_${selectedSupId}_${cubit.state.suppliers.length}',
            ),
            initialValue: selectedSupId,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: _dropdownDecoration(
              'Proveedor (Opcional)',
              icon: Icons.local_shipping_rounded,
            ),
            hint: const Text(
              'Seleccione proveedor (opcional)',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            items: supplierItems,
            onChanged: cubit.setSupplier,
            validator: (val) {
              if (cubit.state.paymentMode == 'CRÉDITO' &&
                  (val == null || val.isEmpty)) {
                return 'Debe seleccionar un proveedor para compras al crédito';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceSection(
    BuildContext context,
    InventoryEntryFormState state,
    InventoryEntryFormCubit cubit,
  ) {
    final isCredit = cubit.state.paymentMode == 'CRÉDITO';
    final selectedAcc =
        cubit.state.accounts
            .where((a) => a.id == cubit.state.selectedAccountId)
            .firstOrNull;
    final selectedAccId = selectedAcc?.id;

    final isCaja = selectedAcc?.type.toUpperCase() == 'CAJA';
    final hasOpenShift =
        selectedAccId != null &&
        cubit.state.activeShiftsByAccount.containsKey(selectedAccId);

    final totalAmount = cubit.state.items.fold<double>(
      0.0,
      (sum, item) => sum + (item.quantity * item.unitCost),
    );
    final isInsufficientBalance =
        selectedAcc != null &&
        cubit.state.items.isNotEmpty &&
        selectedAcc.balance < totalAmount;

    return _SectionCard(
      highlightColor: isCredit ? Colors.purple.shade50 : null,
      borderColor: isCredit ? Colors.purple.shade200 : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.payments_rounded,
            title: 'Modo de pago',
            iconColor: isCredit ? Colors.purple.shade600 : AppColors.primary,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'CONTADO', label: Text('Contado')),
                ButtonSegment(value: 'CRÉDITO', label: Text('Crédito')),
                ButtonSegment(value: 'AJUSTE', label: Text('Ajuste')),
              ],
              selected: {cubit.state.paymentMode},
              onSelectionChanged: (selection) {
                HapticFeedback.selectionClick();
                cubit.setPaymentMode(selection.first);
              },
              style: SegmentedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textSecondary,
                selectedBackgroundColor:
                    isCredit ? Colors.purple.shade600 : AppColors.primary,
                selectedForegroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child:
                cubit.state.paymentMode == 'CONTADO'
                    ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'acc_${selectedAccId}_${cubit.state.accounts.length}',
                            ),
                            initialValue: selectedAccId,
                            isExpanded: true,
                            icon: const Icon(Icons.expand_more_rounded),
                            decoration: _dropdownDecoration(
                              'Cuenta a debitar',
                              icon: Icons.account_balance_wallet_rounded,
                            ),
                            hint: const Text(
                              'Seleccione cuenta a debitar',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                            items:
                                cubit.state.accounts.map((acc) {
                                  return DropdownMenuItem(
                                    value: acc.id,
                                    child: Text(
                                      '${acc.name} (Saldo: S/ ${acc.balance.toStringAsFixed(2)})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                }).toList(),
                            onChanged: cubit.setAccount,
                            validator: (val) {
                              if (cubit.state.paymentMode == 'CONTADO') {
                                if (val == null || val.isEmpty) {
                                  return 'Seleccione la cuenta a debitar';
                                }
                                final acc =
                                    cubit.state.accounts
                                        .where((a) => a.id == val)
                                        .firstOrNull;
                                if (acc != null &&
                                    acc.type.toUpperCase() == 'CAJA' &&
                                    !cubit.state.activeShiftsByAccount
                                        .containsKey(acc.id)) {
                                  return 'La caja seleccionada no tiene un turno abierto';
                                }
                              }
                              return null;
                            },
                          ),
                          if (selectedAcc != null &&
                              isCaja &&
                              !hasOpenShift) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.warning,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Caja sin turno abierto ("${selectedAcc.name}")',
                                          style: const TextStyle(
                                            color: AppColors.warning,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Debes abrir un turno de caja para registrar pagos al contado.',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Refrescar estado de turnos',
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                      color: AppColors.warning,
                                    ),
                                    onPressed: () => cubit.refreshCashShifts(),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (selectedAcc != null &&
                              isCaja &&
                              hasOpenShift) ...[
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Turno de caja abierto y disponible',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (isInsufficientBalance) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: AppColors.danger,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Saldo insuficiente en "${selectedAcc.name}". Disponible: S/ ${selectedAcc.balance.toStringAsFixed(2)} · Requerido: S/ ${totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection(
    BuildContext context,
    InventoryEntryFormState state,
    InventoryEntryFormCubit cubit,
  ) {
    // Sin documento no hay número ni fecha que capturar.
    final hasDocument = cubit.state.documentType != 'NINGUNO';

    final typeField = DropdownButtonFormField<String>(
      key: ValueKey('doctype_${cubit.state.documentType}'),
      initialValue: cubit.state.documentType,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded),
      decoration: _dropdownDecoration(
        'Tipo de documento',
        icon: Icons.description_outlined,
      ),
      items:
          _docTypes.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
              .toList(),
      onChanged: (v) {
        if (v == null) return;
        cubit.setDocumentType(v);
        if (v == 'NINGUNO') {
          _documentNumberCtrl.clear();
          cubit.setDocumentNumber('');
          cubit.setDocumentDate(null);
        }
      },
    );

    final numberField = TextFormField(
      controller: _documentNumberCtrl,
      maxLength: 50,
      textCapitalization: TextCapitalization.characters,
      decoration: _dropdownDecoration(
        'Número / serie',
      ).copyWith(hintText: 'Ej: F001-000123', counterText: ''),
    );

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.receipt_long_rounded,
            title: 'Documento y notas',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (!hasDocument) return typeField;
              if (constraints.maxWidth >= 440) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: typeField),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: numberField),
                  ],
                );
              }
              return Column(
                children: [typeField, const SizedBox(height: 16), numberField],
              );
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child:
                hasDocument
                    ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _DatePickerField(
                        label: 'Fecha de emisión',
                        value: cubit.state.documentDate,
                        onPick: () => _pickDocumentDate(context),
                        onClear: () => cubit.setDocumentDate(null),
                        icon: Icons.edit_calendar_rounded,
                      ),
                    )
                    : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            maxLength: 300,
            decoration: _dropdownDecoration(
              'Notas adicionales (opcional)',
            ).copyWith(counterText: '', alignLabelWithHint: true),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(
    BuildContext context,
    InventoryEntryFormState state,
    InventoryEntryFormCubit cubit, {
    bool isDesktop = false,
  }) {
    if (isDesktop) {
      return BlocSelector<
        InventoryEntryFormCubit,
        InventoryEntryFormState,
        List<InventoryEntryItemEntity>
      >(
        selector: (state) => state.items,
        builder: (context, items) {
          return PurchaseOrderItemsTable(
            items: items,
            title: 'Productos a ingresar',
            emptyTitle: 'Aún no hay productos',
            emptyMessage:
                'Agrega los productos que vas a ingresar a tu almacén.',
            // El total vive en la barra inferior fija.
            showFooter: false,
            onRemoveItem: (index) => _removeItemWithUndo(cubit, index),
            onUpdateQuantity:
                (index, qty) => cubit.updateItemQuantity(index, qty),
            onUpdateCost: (index, cost) => cubit.updateItemCost(index, cost),
            onAddNewRow: () => _showAddProductSheet(context),
            onScanBarcode: () => _scanAndAddProduct(context),
            onEditBatch: (index) {
              if (index < items.length) {
                _showEditBatchDialog(context, index, items[index], cubit);
              }
            },
          );
        },
      );
    }

    return _SectionCard(
      child: BlocSelector<
        InventoryEntryFormCubit,
        InventoryEntryFormState,
        List<InventoryEntryItemEntity>
      >(
        selector: (state) => state.items,
        builder: (context, items) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SectionTitle(
                      icon: Icons.inventory_2_rounded,
                      title:
                          items.isEmpty
                              ? 'Productos'
                              : 'Productos (${items.length})',
                    ),
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Escanear código',
                      icon: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      onPressed: () => _scanAndAddProduct(context),
                    ),
                    const SizedBox(width: 4),
                    FilledButton.tonalIcon(
                      onPressed: () => _showAddProductSheet(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Agregar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (widget.purchaseOrderId == null)
                      PopupMenuButton<String>(
                        tooltip: 'Más opciones',
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onSelected: (value) {
                          if (value == 'clear') _handleClearDraft();
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
                ],
              ),
              const SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child:
                    items.isEmpty
                        ? _buildEmptyProducts(context)
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: List.generate(items.length, (index) {
                            final item = items[index];
                            return EntryItemCard(
                              key: ValueKey(
                                'entry_item_${item.productId}_${item.variantId}_${item.batchNumber}_$index',
                              ),
                              item: item,
                              onUpdateQuantity:
                                  (qty) => cubit.updateItemQuantity(index, qty),
                              onUpdateCost:
                                  (cost) => cubit.updateItemCost(index, cost),
                              onEditBatch:
                                  item.usesBatches
                                      ? () => _showEditBatchDialog(
                                        context,
                                        index,
                                        item,
                                        cubit,
                                      )
                                      : null,
                              onRemove: () => _removeItemWithUndo(cubit, index),
                            );
                          }),
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyProducts(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.move_to_inbox_rounded,
              size: 26,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Aún no hay productos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Agrega los productos que vas a ingresar a tu almacén.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _scanAndAddProduct(context),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Escanear código'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showAddProductSheet(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar producto'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // FIXED BOTTOM BUTTON
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildStickySaveButton(
    BuildContext context,
    InventoryEntryFormState state,
    InventoryEntryFormCubit cubit,
  ) {
    return BlocBuilder<InventoryEntryFormCubit, InventoryEntryFormState>(
      buildWhen:
          (prev, curr) =>
              prev.items != curr.items || prev.isSaving != curr.isSaving,
      builder: (context, s) {
        final items = s.items;
        final hasItems = items.isNotEmpty;
        final isSaving = s.isSaving;
        final total = items.fold<double>(
          0.0,
          (sum, i) => sum + i.quantity * i.unitCost,
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
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
                // Total siempre a la vista, sin tener que bajar hasta el final.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Total estimado',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'S/ ${total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            color:
                                hasItems
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: (!hasItems || isSaving) ? null : _handleSave,
                  icon:
                      isSaving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textMuted,
                            ),
                          )
                          : const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 20,
                          ),
                  label: Text(isSaving ? 'Guardando...' : 'Confirmar ingreso'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.textMuted,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  Future<void> _showEditBatchDialog(
    BuildContext context,
    int index,
    InventoryEntryItemEntity item,
    InventoryEntryFormCubit cubit,
  ) async {
    final initialBatch = item.batchNumber == 'DEFAULT' ? '' : item.batchNumber;
    final batchCtrl = TextEditingController(text: initialBatch);
    DateTime? selectedExpiry = item.expiryDate;
    String? localError;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.qr_code_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Asignar Lote',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (item.variantLabel.isNotEmpty &&
                        item.variantLabel != 'Variante Única') ...[
                      const SizedBox(height: 2),
                      Text(
                        item.variantLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: batchCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Nº de Lote *',
                        hintText: 'Ej: LOTE-2024-001',
                        errorText: localError,
                        prefixIcon: const Icon(
                          Icons.tag,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (val) {
                        if (localError != null) {
                          setDialogState(() => localError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fecha de Vencimiento (Opcional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              selectedExpiry ??
                              DateTime.now().add(const Duration(days: 90)),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 30),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 10),
                          ),
                          helpText: 'Fecha de Vencimiento',
                        );
                        if (picked != null) {
                          setDialogState(() => selectedExpiry = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedExpiry != null
                                    ? '${selectedExpiry!.day.toString().padLeft(2, '0')}/${selectedExpiry!.month.toString().padLeft(2, '0')}/${selectedExpiry!.year}'
                                    : 'Sin fecha de vencimiento',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      selectedExpiry != null
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                  fontWeight:
                                      selectedExpiry != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (selectedExpiry != null)
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setDialogState(() => selectedExpiry = null);
                                },
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final text = batchCtrl.text.trim();
                    if (text.isEmpty) {
                      setDialogState(
                        () => localError = 'El número de lote es obligatorio',
                      );
                      return;
                    }
                    cubit.updateItemBatch(index, text, selectedExpiry);
                    Navigator.pop(dialogCtx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Guardar Lote'),
                ),
              ],
            );
          },
        );
      },
    );
    batchCtrl.dispose();
  }
}

// ── WIDGETS AUXILIARES ──
class _SectionCard extends StatelessWidget {
  final Widget child;
  final Color? highlightColor;
  final Color? borderColor;

  const _SectionCard({
    required this.child,
    this.highlightColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: highlightColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? Colors.grey.shade200),
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

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final IconData icon;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value == null
                      ? label
                      : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}',
                  style: TextStyle(
                    color:
                        value == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                    fontWeight:
                        value == null ? FontWeight.normal : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (value != null)
                Tooltip(
                  message: 'Limpiar fecha',
                  child: GestureDetector(
                    onTap: onClear,
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
