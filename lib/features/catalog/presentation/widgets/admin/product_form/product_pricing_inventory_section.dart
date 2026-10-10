import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';

class ProductPricingInventorySection extends StatefulWidget {
  const ProductPricingInventorySection({super.key});

  @override
  State<ProductPricingInventorySection> createState() =>
      _ProductPricingInventorySectionState();
}

class _ProductPricingInventorySectionState
    extends State<ProductPricingInventorySection> {
  late final TextEditingController _skuCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _reorderCtrl;
  late final TextEditingController _unitCostCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _wholesalePriceCtrl;
  late final TextEditingController _wholesaleMinCtrl;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _skuCtrl = TextEditingController();
    _barcodeCtrl = TextEditingController();
    _reorderCtrl = TextEditingController(text: '3');
    _unitCostCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _wholesalePriceCtrl = TextEditingController();
    _wholesaleMinCtrl = TextEditingController();

    _skuCtrl.addListener(_onFieldChanged);
    _barcodeCtrl.addListener(_onFieldChanged);
    _reorderCtrl.addListener(_onFieldChanged);
    _unitCostCtrl.addListener(_onFieldChanged);
    _priceCtrl.addListener(_onFieldChanged);
    _wholesalePriceCtrl.addListener(_onFieldChanged);
    _wholesaleMinCtrl.addListener(_onFieldChanged);
  }

  void _syncControllersFromState(ProductFormState state) {
    if (_isInitialized) return;
    if (state.variantDrafts.isNotEmpty) {
      final defaultDraft = state.variantDrafts.first;
      _skuCtrl.text = defaultDraft.sku;
      _barcodeCtrl.text = defaultDraft.barcode;
      _reorderCtrl.text =
          defaultDraft.reorderPoint.isNotEmpty
              ? defaultDraft.reorderPoint
              : '3';
      _unitCostCtrl.text = defaultDraft.unitCost;
      _priceCtrl.text = defaultDraft.price;
      _wholesalePriceCtrl.text = defaultDraft.wholesalePrice;
      _wholesaleMinCtrl.text = defaultDraft.wholesaleMinQuantity;
      _isInitialized = true;
    }
  }

  void _onFieldChanged() {
    if (!mounted) return;
    final cubit = context.read<ProductFormCubit>();
    cubit.updateDefaultVariant(
      sku: _skuCtrl.text.trim(),
      barcode: _barcodeCtrl.text.trim(),
      reorderPoint: _reorderCtrl.text.trim(),
      unitCost: _unitCostCtrl.text.trim(),
      price: _priceCtrl.text.trim(),
      wholesalePrice: _wholesalePriceCtrl.text.trim(),
      wholesaleMinQuantity: _wholesaleMinCtrl.text.trim(),
      syncState: false,
    );
    setState(() {}); // Recalcular badge de margen dinámico
  }

  @override
  void dispose() {
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _reorderCtrl.dispose();
    _unitCostCtrl.dispose();
    _priceCtrl.dispose();
    _wholesalePriceCtrl.dispose();
    _wholesaleMinCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleToggleVariants(
    BuildContext context,
    ProductFormCubit cubit,
    ProductFormState state,
    bool enableVariants,
  ) async {
    if (enableVariants) {
      cubit.setHasMultipleVariants(true);
      return;
    }

    // Si ya tiene más de una variante, pedir confirmación para no perder variantes adicionales
    if (state.variantDrafts.length > 1) {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radius),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text('¿Volver a producto único?'),
                ],
              ),
              content: Text(
                'Actualmente tienes ${state.variantDrafts.length} variantes configuradas. Al volver a producto único, se conservará la información de la primera variante y se eliminarán las variantes secundarias.\n\n¿Deseas continuar?',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Sí, conservar solo una'),
                ),
              ],
            ),
      );

      if (confirm == true && mounted) {
        cubit.revertToSingleVariant();
        // Sincronizar controladores con la variante restante
        final remaining = cubit.state.variantDrafts.first;
        _skuCtrl.text = remaining.sku;
        _barcodeCtrl.text = remaining.barcode;
        _reorderCtrl.text = remaining.reorderPoint;
        _unitCostCtrl.text = remaining.unitCost;
        _priceCtrl.text = remaining.price;
        _wholesalePriceCtrl.text = remaining.wholesalePrice;
        _wholesaleMinCtrl.text = remaining.wholesaleMinQuantity;
      }
    } else {
      cubit.setHasMultipleVariants(false);
    }
  }

  Widget _buildMarginBadge() {
    final priceStr = _priceCtrl.text.trim().replaceAll(',', '.');
    final costStr = _unitCostCtrl.text.trim().replaceAll(',', '.');

    final price = double.tryParse(priceStr);
    final cost = double.tryParse(costStr);

    if (price == null || price <= 0 || cost == null || cost < 0) {
      return const SizedBox.shrink();
    }

    final profit = price - cost;
    final marginPercent = (profit / price) * 100;

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String prefix;

    if (marginPercent >= 30) {
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFFA7F3D0);
      textColor = const Color(0xFF065F46);
      icon = Icons.trending_up_rounded;
      prefix = 'Margen saludable';
    } else if (marginPercent >= 10) {
      bgColor = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFFDE68A);
      textColor = const Color(0xFF92400E);
      icon = Icons.trending_flat_rounded;
      prefix = 'Margen estándar';
    } else if (marginPercent >= 0) {
      bgColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFFED7AA);
      textColor = const Color(0xFF9A3412);
      icon = Icons.warning_amber_rounded;
      prefix = 'Margen bajo';
    } else {
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFECACA);
      textColor = const Color(0xFF991B1B);
      icon = Icons.trending_down_rounded;
      prefix = 'Pérdida';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            '$prefix: ${marginPercent.toStringAsFixed(1)}% (Ganancia: S/ ${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(2)})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();

    return BlocConsumer<ProductFormCubit, ProductFormState>(
      listenWhen:
          (prev, curr) =>
              !_isInitialized &&
              curr.variantDrafts.isNotEmpty &&
              !curr.isInitializingData,
      listener: (context, state) {
        _syncControllersFromState(state);
      },
      builder: (context, state) {
        _syncControllersFromState(state);
        final hasVariants = state.hasMultipleVariants;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera de la sección
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.payments_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Precios e Inventario',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Valores comerciales y control de reposición',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasVariants)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.layers_outlined,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Modo Variantes',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Contenido condicional: Producto Simple vs Producto con Variantes
              if (hasVariants) ...[
                // Banner informativo en modo multi-variante
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Los precios, códigos SKU y stock se gestionan de forma independiente para cada variante en la sección de "Variantes" a continuación.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Formulario de Producto Simple (Campos directos)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 540;

                    if (isWide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fila 1: SKU y Punto de Reorden
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: AppTextField(
                                  controller: _skuCtrl,
                                  label: 'SKU (Código Interno)',
                                  icon: Icons.qr_code_2_rounded,
                                  hintText: 'Ej. ABON-NIT-001',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: AppTextField(
                                  controller: _reorderCtrl,
                                  label: 'Punto de Reorden',
                                  icon: Icons.warning_amber_rounded,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  hintText: '3',
                                  helperText: 'Alerta de stock bajo',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Fila 2: Código de barras opcional
                          AppTextField(
                            controller: _barcodeCtrl,
                            label: 'Código de Barras (Opcional)',
                            icon: Icons.barcode_reader,
                            hintText: 'Ej. 7751234567890',
                          ),
                          const SizedBox(height: 16),

                          // Fila 3: Costo unitario y Precio de venta
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _unitCostCtrl,
                                  label: 'Costo unitario',
                                  icon: Icons.payments_outlined,
                                  prefixText: 'S/ ',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*[\.,]?\d{0,2}'),
                                    ),
                                  ],
                                  hintText: '0.00',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AppTextField(
                                  controller: _priceCtrl,
                                  label: 'Precio de venta *',
                                  icon: Icons.sell_outlined,
                                  prefixText: 'S/ ',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*[\.,]?\d{0,2}'),
                                    ),
                                  ],
                                  hintText: '0.00',
                                  validator: (v) {
                                    if (hasVariants) return null;
                                    final val = double.tryParse(
                                      (v ?? '').replaceAll(',', '.'),
                                    );
                                    if (val == null || val <= 0) {
                                      return 'Ingresa un precio de venta mayor a 0';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          _buildMarginBadge(),
                          const SizedBox(height: 16),

                          // Fila 4: Precios mayoristas
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: AppTextField(
                                  controller: _wholesalePriceCtrl,
                                  label: 'Precio mayorista (Opcional)',
                                  icon: Icons.local_offer_outlined,
                                  prefixText: 'S/ ',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*[\.,]?\d{0,2}'),
                                    ),
                                  ],
                                  hintText: '0.00',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: AppTextField(
                                  controller: _wholesaleMinCtrl,
                                  label: 'Mín. unidades',
                                  icon: Icons.tag_rounded,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  hintText: '3',
                                  helperText: 'Aplica precio mayorista',
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    // Layout Móvil (Una columna vertical continua)
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _skuCtrl,
                          label: 'SKU (Código Interno)',
                          icon: Icons.qr_code_2_rounded,
                          hintText: 'Ej. ABON-NIT-001',
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _reorderCtrl,
                          label: 'Punto de Reorden',
                          icon: Icons.warning_amber_rounded,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          hintText: '3',
                          helperText: 'Alerta de stock bajo',
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _barcodeCtrl,
                          label: 'Código de Barras (Opcional)',
                          icon: Icons.barcode_reader,
                          hintText: 'Ej. 7751234567890',
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _unitCostCtrl,
                          label: 'Costo unitario',
                          icon: Icons.payments_outlined,
                          prefixText: 'S/ ',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*[\.,]?\d{0,2}'),
                            ),
                          ],
                          hintText: '0.00',
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _priceCtrl,
                          label: 'Precio de venta *',
                          icon: Icons.sell_outlined,
                          prefixText: 'S/ ',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*[\.,]?\d{0,2}'),
                            ),
                          ],
                          hintText: '0.00',
                          validator: (v) {
                            if (hasVariants) return null;
                            final val = double.tryParse(
                              (v ?? '').replaceAll(',', '.'),
                            );
                            if (val == null || val <= 0) {
                              return 'Ingresa un precio mayor a 0';
                            }
                            return null;
                          },
                        ),
                        _buildMarginBadge(),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _wholesalePriceCtrl,
                          label: 'Precio mayorista (Opcional)',
                          icon: Icons.local_offer_outlined,
                          prefixText: 'S/ ',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*[\.,]?\d{0,2}'),
                            ),
                          ],
                          hintText: '0.00',
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _wholesaleMinCtrl,
                          label: 'Mínimo para mayoreo',
                          icon: Icons.tag_rounded,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          hintText: '3',
                          helperText: 'Aplica precio mayorista',
                        ),
                      ],
                    );
                  },
                ),
              ],

              const SizedBox(height: 20),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),

              // Switch Progresivo de Variantes
              Container(
                decoration: BoxDecoration(
                  color:
                      hasVariants
                          ? AppColors.primary.withValues(alpha: 0.04)
                          : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        hasVariants
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.border,
                  ),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  activeThumbColor: AppColors.primary,
                  title: const Text(
                    '¿Tiene múltiples presentaciones o variantes?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    hasVariants
                        ? 'Activado: Se desplegará la matriz para definir presentaciones, tallas, colores o pesos.'
                        : 'Desactivado: Producto simple con precio y código únicos.',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          hasVariants
                              ? AppColors.primary
                              : AppColors.textSecondary,
                    ),
                  ),
                  value: hasVariants,
                  onChanged:
                      (val) => _handleToggleVariants(
                        context,
                        cubit,
                        state,
                        val,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
