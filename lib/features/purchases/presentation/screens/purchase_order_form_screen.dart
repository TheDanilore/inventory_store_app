import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/hardware_barcode_gun_detector.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/pos/presentation/services/pos_barcode_scanner_service.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_order_form/purchase_order_form_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_order_form/purchase_order_form_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/form_components/po_form_document_section.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/form_components/po_form_header_section.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/form_components/po_form_payment_section.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/form_components/po_form_products_section.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/form_components/po_form_sticky_save_bar.dart';

import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';

class PurchaseOrderFormScreen extends StatefulWidget {
  final String? editOrderId;

  const PurchaseOrderFormScreen({super.key, this.editOrderId});

  @override
  State<PurchaseOrderFormScreen> createState() =>
      _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends State<PurchaseOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _documentNumberCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _gunDetector = HardwareBarcodeGunDetector();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseOrderFormCubit>().initForm(
        editOrderId: widget.editOrderId,
      );
    });
  }

  @override
  void dispose() {
    _documentNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate(
    BuildContext context,
    DateTime? currentDueDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          currentDueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Fecha de Entrega o Vencimiento',
    );
    if (picked != null && context.mounted) {
      context.read<PurchaseOrderFormCubit>().updateField(dueDate: picked);
    }
  }

  Future<void> _pickDocumentDate(
    BuildContext context,
    DateTime? currentDocDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDocDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Fecha del Documento Físico',
    );
    if (picked != null && context.mounted) {
      context.read<PurchaseOrderFormCubit>().updateField(documentDate: picked);
    }
  }

  Future<void> _showAddProductSheet(
    BuildContext context,
    PurchaseOrderFormLoaded state,
  ) async {
    if (state.selectedSupplierId == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un proveedor antes de agregar productos.',
        type: SnackbarType.warning,
      );
      return;
    }

    if (state.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un almacén de destino antes de agregar productos.',
        type: SnackbarType.warning,
      );
      return;
    }

    final cubit = context.read<PurchaseOrderFormCubit>();
    final newItem = await AddEntryProductSheet.show(
      context,
      warehouseId: state.selectedWarehouseId,
      isBatchRequired: false,
      onAddAndContinue: (item) => cubit.addItem(item),
    );

    if (newItem != null && context.mounted) {
      cubit.addItem(newItem);
    }
  }

  Future<void> _scanAndAddProduct(
    BuildContext context,
    PurchaseOrderFormLoaded state,
  ) async {
    if (state.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message:
            'Selecciona un almacén de destino antes de escanear productos.',
        type: SnackbarType.warning,
      );
      return;
    }

    await PosCameraScannerDialog.show(
      context,
      warehouseId: state.selectedWarehouseId,
      title: 'Escanear Productos para Orden',
      continuousMode: true,
      onContinuousScan: (res) async {
        if (!mounted) return;
        _processProductScan(res.product, res.variant);
      },
    );
  }

  void _handleGunBarcode(String rawBarcode) {
    final state = context.read<PurchaseOrderFormCubit>().state;
    if (state is PurchaseOrderFormLoaded) {
      _processBarcode(rawBarcode, state);
    }
  }

  Future<void> _processBarcode(
    String rawBarcode,
    PurchaseOrderFormLoaded state,
  ) async {
    if (state.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message:
            'Selecciona un almacén de destino antes de escanear productos.',
        type: SnackbarType.warning,
      );
      return;
    }

    final res = await PosBarcodeScannerService.resolveCode(
      rawBarcode,
      warehouseId: state.selectedWarehouseId,
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

    _processProductScan(res.product, res.variant);
  }

  void _processProductScan(
    ProductEntity product,
    ProductVariantEntity? targetVariant,
  ) {
    final state = context.read<PurchaseOrderFormCubit>().state;
    if (state is! PurchaseOrderFormLoaded) return;

    final resolvedVariant = targetVariant ?? product.defaultVariant;
    final existingIndex = state.items.indexWhere(
      (item) =>
          item.productId == product.id &&
          (resolvedVariant == null || item.variantId == resolvedVariant.id),
    );

    final cubit = context.read<PurchaseOrderFormCubit>();
    AppFeedbackService.mediumImpact();

    if (existingIndex != -1) {
      final currentItem = state.items[existingIndex];
      cubit.updateItemQuantity(
        currentItem.productId,
        currentItem.variantId,
        currentItem.quantity + 1,
      );
      AppSnackbar.show(
        context,
        message: '+1 a "${product.name}"',
        type: SnackbarType.info,
      );
    } else {
      final entryItem = InventoryEntryItemEntity(
        productId: product.id,
        productName: product.name,
        variantId: resolvedVariant?.id ?? product.id,
        variantLabel:
            resolvedVariant?.label ?? resolvedVariant?.sku ?? 'Estándar',
        usesBatches: product.usesBatches,
        quantity: 1.0,
        unitCost: resolvedVariant?.unitCost ?? 0.0,
        batchNumber: '',
        expiryDate: null,
        imageUrl: product.primaryImageUrl,
      );
      cubit.addItem(entryItem);
      AppSnackbar.show(
        context,
        message: 'Agregado a la orden: "${product.name}"',
        type: SnackbarType.success,
      );
    }
  }

  Future<void> _handleSave(PurchaseOrderFormLoaded state) async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      AppSnackbar.show(
        context,
        message:
            'Por favor, corrige los campos del formulario antes de continuar.',
        type: SnackbarType.warning,
      );
      return;
    }

    if (state.creditWarningMessage != null) {
      AppSnackbar.show(
        context,
        message: state.creditWarningMessage!,
        type: SnackbarType.error,
      );
      return;
    }

    final cubit = context.read<PurchaseOrderFormCubit>();
    cubit.updateField(
      documentNumber: _documentNumberCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
    );
    await cubit.submitOrder();

    if (!mounted) return;
    final newState = cubit.state;
    if (newState is PurchaseOrderFormSuccess) {
      AppSnackbar.show(
        context,
        message:
            state.isEditing
                ? 'Orden de compra actualizada con éxito'
                : 'Orden generada con éxito',
        type: SnackbarType.success,
      );
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/purchase-orders');
      }
    } else if (newState is PurchaseOrderFormLoaded &&
        newState.errorMessage != null &&
        newState.errorMessage!.isNotEmpty) {
      AppSnackbar.show(
        context,
        message: newState.errorMessage!,
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
              '¿Estás seguro de que quieres limpiar la orden actual? Perderás todos los ítems agregados.',
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
      context.read<PurchaseOrderFormCubit>().clearDraft();
      _documentNumberCtrl.clear();
      _notesCtrl.clear();
      AppSnackbar.show(
        context,
        message: 'Borrador descartado',
        type: SnackbarType.info,
      );
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
      child: BlocConsumer<PurchaseOrderFormCubit, PurchaseOrderFormState>(
        listener: (context, state) {
          if (state is PurchaseOrderFormLoaded && state.isEditing) {
            if (_documentNumberCtrl.text.isEmpty &&
                state.documentNumber.isNotEmpty) {
              _documentNumberCtrl.text = state.documentNumber;
            }
            if (_notesCtrl.text.isEmpty && state.notes.isNotEmpty) {
              _notesCtrl.text = state.notes;
            }
          }
        },
        builder: (context, state) {
          final cubit = context.read<PurchaseOrderFormCubit>();

          // Cold start absoluto (cuando no hay ningún dato ni en caché ni en estado)
          if (state is PurchaseOrderFormLoading ||
              state is PurchaseOrderFormInitial) {
            return AdminLayout(
              title:
                  widget.editOrderId != null ? 'Editar Orden' : 'Nueva Orden',
              showBackButton: true,
              showProfileButton: false,
              showDrawerButton: false,
              body: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          if (state is! PurchaseOrderFormLoaded) {
            return const SizedBox.shrink();
          }

          final formLoaded = state;

          // Error fatal sin catálogos
          if (formLoaded.errorMessage != null &&
              formLoaded.errorMessage!.isNotEmpty &&
              formLoaded.suppliers.isEmpty) {
            return AdminLayout(
              title: formLoaded.isEditing ? 'Editar Orden' : 'Nueva Orden',
              showBackButton: true,
              showProfileButton: false,
              showDrawerButton: false,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 64,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        formLoaded.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed:
                            () => cubit.initForm(
                              forceReload: true,
                              editOrderId: widget.editOrderId,
                            ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Sin configuración de proveedores o almacenes
          if (!formLoaded.isBackgroundLoading &&
              (formLoaded.suppliers.isEmpty || formLoaded.warehouses.isEmpty)) {
            return AdminLayout(
              title: formLoaded.isEditing ? 'Editar Orden' : 'Nueva Orden',
              showBackButton: true,
              showProfileButton: false,
              showDrawerButton: false,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 64,
                        color: AppColors.warning,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No se puede crear una orden de compra sin almacenes activos ni proveedores configurados.\nPor favor regístralos primero en las secciones correspondientes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/purchase-orders');
                          }
                        },
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Volver al listado'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;

              if (formLoaded.isEditing) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text('Salir de la edición'),
                        content: const Text(
                          '¿Deseas salir sin guardar los cambios de la orden de compra?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Continuar editando'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Salir sin guardar'),
                          ),
                        ],
                      ),
                );
                if (confirm == true && context.mounted) {
                  if (context.canPop()) {
                    context.pop(result);
                  } else {
                    context.go('/purchase-orders');
                  }
                }
                return;
              }

              if (formLoaded.items.isEmpty) {
                cubit.clearDraft();
                if (context.canPop()) {
                  context.pop(result);
                } else {
                  context.go('/purchase-orders');
                }
                return;
              }

              final action = await showDialog<String>(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('Órden en progreso'),
                      content: const Text(
                        'Tienes productos en la órden actual. ¿Qué deseas hacer al salir?',
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
                  context.go('/purchase-orders');
                }
              } else if (action == 'draft') {
                if (context.canPop()) {
                  context.pop(result);
                } else {
                  context.go('/purchase-orders');
                }
              }
            },
            child: AdminLayout(
              title:
                  formLoaded.isEditing
                      ? 'Editar Orden de Compra'
                      : 'Nueva Orden de Compra',
              showBackButton: true,
              showProfileButton: false,
              showDrawerButton: false,
              body: Column(
                children: [
                  // SWR: Indicador lineal sutil si hay sincronización en segundo plano sin bloquear UI
                  if (formLoaded.isBackgroundLoading)
                    const LinearProgressIndicator(
                      minHeight: 2.5,
                      color: AppColors.primary,
                      backgroundColor: Colors.transparent,
                    ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 900;

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Izquierda: Datos, Pago, Documento (40%)
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
                                        children: [
                                          POFormHeaderSection(
                                            suppliers: formLoaded.suppliers,
                                            warehouses: formLoaded.warehouses,
                                            selectedSupplierId:
                                                formLoaded.selectedSupplierId,
                                            selectedWarehouseId:
                                                formLoaded.selectedWarehouseId,
                                            dueDate: formLoaded.dueDate,
                                            onSupplierChanged:
                                                (v) => cubit.updateField(
                                                  supplierId: v,
                                                ),
                                            onWarehouseChanged:
                                                (v) => cubit.updateField(
                                                  warehouseId: v,
                                                ),
                                            onPickDueDate:
                                                () => _pickDueDate(
                                                  context,
                                                  formLoaded.dueDate,
                                                ),
                                            onClearDueDate:
                                                () => cubit.clearDueDate(),
                                          ),
                                          const SizedBox(height: 24),
                                          POFormPaymentSection(
                                            isEditing: formLoaded.isEditing,
                                            paymentMode: formLoaded.paymentMode,
                                            paymentStatus:
                                                formLoaded.paymentStatus,
                                            selectedAccountId:
                                                formLoaded.selectedAccountId,
                                            accounts: formLoaded.accounts,
                                            activeShiftsByAccount:
                                                formLoaded
                                                    .activeShiftsByAccount,
                                            totalAmount: formLoaded.totalAmount,
                                            currencyCode:
                                                formLoaded.currencyCode,
                                            exchangeRate:
                                                formLoaded.exchangeRate,
                                            creditWarningMessage:
                                                formLoaded.creditWarningMessage,
                                            onCurrencyChanged:
                                                (code, rate) => cubit
                                                    .setCurrency(code, rate),
                                            onPaymentModeChanged: (v) {
                                              cubit.updateField(paymentMode: v);
                                              if (v == 'CRÉDITO') {
                                                cubit.updateField(
                                                  paymentStatus: 'PENDING',
                                                  accountId: null,
                                                );
                                              }
                                            },
                                            onPaymentStatusChanged:
                                                (v) => cubit.updateField(
                                                  paymentStatus: v,
                                                ),
                                            onAccountChanged:
                                                (v) => cubit.updateField(
                                                  accountId: v,
                                                ),
                                          ),
                                          const SizedBox(height: 24),
                                          POFormDocumentSection(
                                            documentType:
                                                formLoaded.documentType,
                                            documentNumberCtrl:
                                                _documentNumberCtrl,
                                            documentDate:
                                                formLoaded.documentDate,
                                            notesCtrl: _notesCtrl,
                                            onDocumentTypeChanged:
                                                (v) => cubit.updateField(
                                                  documentType: v,
                                                ),
                                            onPickDocumentDate:
                                                () => _pickDocumentDate(
                                                  context,
                                                  formLoaded.documentDate,
                                                ),
                                            onClearDocumentDate:
                                                () => cubit.clearDocumentDate(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Derecha: Tabla de Productos y Barra de Guardar (60%)
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.all(24.0),
                                          child: POFormProductsSection(
                                            items: formLoaded.items,
                                            isDesktop: true,
                                            isEditing: formLoaded.isEditing,
                                            currencyCode:
                                                formLoaded.currencyCode,
                                            exchangeRate:
                                                formLoaded.exchangeRate,
                                            onRemoveItem: (index) {
                                              final item =
                                                  formLoaded.items[index];
                                              cubit.removeItem(
                                                item.productId,
                                                item.variantId,
                                              );
                                            },
                                            onUpdateQuantity: (
                                              index,
                                              quantity,
                                            ) {
                                              final item =
                                                  formLoaded.items[index];
                                              cubit.updateItemQuantity(
                                                item.productId,
                                                item.variantId,
                                                quantity,
                                              );
                                            },
                                            onUpdateCost: (index, cost) {
                                              final item =
                                                  formLoaded.items[index];
                                              cubit.updateItemCost(
                                                item.productId,
                                                item.variantId,
                                                cost,
                                              );
                                            },
                                            onAddNewRow:
                                                () => _showAddProductSheet(
                                                  context,
                                                  formLoaded,
                                                ),
                                            onScanBarcode:
                                                () => _scanAndAddProduct(
                                                  context,
                                                  formLoaded,
                                                ),
                                            onClearDraft: _handleClearDraft,
                                          ),
                                        ),
                                      ),
                                      POFormStickySaveBar(
                                        isEditing: formLoaded.isEditing,
                                        isSaving: formLoaded.isSaving,
                                        isValid: formLoaded.isValid,
                                        onSave: () => _handleSave(formLoaded),
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
                                      POFormHeaderSection(
                                        suppliers: formLoaded.suppliers,
                                        warehouses: formLoaded.warehouses,
                                        selectedSupplierId:
                                            formLoaded.selectedSupplierId,
                                        selectedWarehouseId:
                                            formLoaded.selectedWarehouseId,
                                        dueDate: formLoaded.dueDate,
                                        onSupplierChanged:
                                            (v) => cubit.updateField(
                                              supplierId: v,
                                            ),
                                        onWarehouseChanged:
                                            (v) => cubit.updateField(
                                              warehouseId: v,
                                            ),
                                        onPickDueDate:
                                            () => _pickDueDate(
                                              context,
                                              formLoaded.dueDate,
                                            ),
                                        onClearDueDate:
                                            () => cubit.clearDueDate(),
                                      ),
                                      const SizedBox(height: 16),
                                      POFormProductsSection(
                                        items: formLoaded.items,
                                        isDesktop: false,
                                        isEditing: formLoaded.isEditing,
                                        currencyCode: formLoaded.currencyCode,
                                        exchangeRate: formLoaded.exchangeRate,
                                        onRemoveItem: (index) {
                                          final item = formLoaded.items[index];
                                          cubit.removeItem(
                                            item.productId,
                                            item.variantId,
                                          );
                                        },
                                        onUpdateQuantity: (index, quantity) {
                                          final item = formLoaded.items[index];
                                          cubit.updateItemQuantity(
                                            item.productId,
                                            item.variantId,
                                            quantity,
                                          );
                                        },
                                        onUpdateCost: (index, cost) {
                                          final item = formLoaded.items[index];
                                          cubit.updateItemCost(
                                            item.productId,
                                            item.variantId,
                                            cost,
                                          );
                                        },
                                        onAddNewRow:
                                            () => _showAddProductSheet(
                                              context,
                                              formLoaded,
                                            ),
                                        onScanBarcode:
                                            () => _scanAndAddProduct(
                                              context,
                                              formLoaded,
                                            ),
                                        onClearDraft: _handleClearDraft,
                                      ),
                                      const SizedBox(height: 16),
                                      POFormPaymentSection(
                                        isEditing: formLoaded.isEditing,
                                        paymentMode: formLoaded.paymentMode,
                                        paymentStatus: formLoaded.paymentStatus,
                                        selectedAccountId:
                                            formLoaded.selectedAccountId,
                                        accounts: formLoaded.accounts,
                                        activeShiftsByAccount:
                                            formLoaded.activeShiftsByAccount,
                                        totalAmount: formLoaded.totalAmount,
                                        currencyCode: formLoaded.currencyCode,
                                        exchangeRate: formLoaded.exchangeRate,
                                        creditWarningMessage:
                                            formLoaded.creditWarningMessage,
                                        onCurrencyChanged:
                                            (code, rate) =>
                                                cubit.setCurrency(code, rate),
                                        onPaymentModeChanged: (v) {
                                          cubit.updateField(paymentMode: v);
                                          if (v == 'CRÉDITO') {
                                            cubit.updateField(
                                              paymentStatus: 'PENDING',
                                              accountId: null,
                                            );
                                          }
                                        },
                                        onPaymentStatusChanged:
                                            (v) => cubit.updateField(
                                              paymentStatus: v,
                                            ),
                                        onAccountChanged:
                                            (v) =>
                                                cubit.updateField(accountId: v),
                                      ),
                                      const SizedBox(height: 16),
                                      POFormDocumentSection(
                                        documentType: formLoaded.documentType,
                                        documentNumberCtrl: _documentNumberCtrl,
                                        documentDate: formLoaded.documentDate,
                                        notesCtrl: _notesCtrl,
                                        onDocumentTypeChanged:
                                            (v) => cubit.updateField(
                                              documentType: v,
                                            ),
                                        onPickDocumentDate:
                                            () => _pickDocumentDate(
                                              context,
                                              formLoaded.documentDate,
                                            ),
                                        onClearDocumentDate:
                                            () => cubit.clearDocumentDate(),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              ),
                              POFormStickySaveBar(
                                isEditing: formLoaded.isEditing,
                                isSaving: formLoaded.isSaving,
                                isValid: formLoaded.isValid,
                                onSave: () => _handleSave(formLoaded),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
