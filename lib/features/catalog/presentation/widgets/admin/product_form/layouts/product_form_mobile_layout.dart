import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/layouts/product_form_floating_bar.dart';

// Secciones del Formulario
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_draft_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_images_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_basic_info_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_pricing_inventory_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_config_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_details_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_ingredients_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_batch_section.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_status_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_sales_channels_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_changelog_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_seo_section.dart';

/// Layout Móvil (1 Columna Vertical Continua).
class ProductFormMobileLayout extends StatefulWidget {
  final bool isEdit;
  final TextEditingController nombreCtrl;
  final TextEditingController descCtrl;
  final bool? allExpanded;
  final VoidCallback onToggleExpandCollapseAll;
  final VoidCallback onExit;
  final VoidCallback onPreview;
  final VoidCallback onSave;

  const ProductFormMobileLayout({
    super.key,
    required this.isEdit,
    required this.nombreCtrl,
    required this.descCtrl,
    required this.allExpanded,
    required this.onToggleExpandCollapseAll,
    required this.onExit,
    required this.onPreview,
    required this.onSave,
  });

  @override
  State<ProductFormMobileLayout> createState() =>
      _ProductFormMobileLayoutState();
}

class _ProductFormMobileLayoutState extends State<ProductFormMobileLayout> {
  final _variantSearchCtrl = TextEditingController();
  String _variantSearchTerm = '';

  @override
  void dispose() {
    _variantSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const ProductImagesSection(),
                  const SizedBox(height: 16),
                  const ProductStatusCard(),
                  const SizedBox(height: 16),
                  const ProductSalesChannelsCard(),
                  const SizedBox(height: 16),
                  ProductBasicInfoSection(
                    nombreCtrl: widget.nombreCtrl,
                    descCtrl: widget.descCtrl,
                  ),
                  const SizedBox(height: 16),
                  const ProductPricingInventorySection(),
                  BlocBuilder<ProductFormCubit, ProductFormState>(
                    buildWhen:
                        (p, c) =>
                            p.hasMultipleVariants != c.hasMultipleVariants,
                    builder: (context, state) {
                      if (!state.hasMultipleVariants) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildVariantsHeader(cubit),
                          const SizedBox(height: 12),
                          _buildVariantsList(cubit),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ProductSeoSection(
                    nombreCtrl: widget.nombreCtrl,
                    descCtrl: widget.descCtrl,
                  ),
                  const SizedBox(height: 16),
                  const ProductConfigSection(),
                  const SizedBox(height: 16),
                  const ProductDetailsSection(),
                  const SizedBox(height: 16),
                  const ProductIngredientsSection(),
                  const SizedBox(height: 16),
                  const ProductBatchSection(),
                  const SizedBox(height: 16),
                  const ProductChangelogCard(),
                ]),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 110)),
          ],
        ),

        // Barra flotante Glassmorphism en Mobile
        ProductFormFloatingBar(
          isDesktop: false,
          isEdit: widget.isEdit,
          nombreCtrl: widget.nombreCtrl,
          onExit: widget.onExit,
          onPreview: widget.onPreview,
          onSave: widget.onSave,
        ),
      ],
    );
  }

  Widget _buildVariantsHeader(ProductFormCubit cubit) {
    return BlocBuilder<ProductFormCubit, ProductFormState>(
      buildWhen:
          (p, c) =>
              p.variantDrafts.length != c.variantDrafts.length ||
              p.variantDrafts.where((d) => d.isActive).length !=
                  c.variantDrafts.where((d) => d.isActive).length,
      builder: (context, state) {
        final count = state.variantDrafts.length;
        final activeCount = state.variantDrafts.where((d) => d.isActive).length;
        final isAllExpanded = widget.allExpanded == true;
        final isMobile = MediaQuery.sizeOf(context).width < 640;

        return Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Variantes',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isMobile
                        ? '$count var.'
                        : '$count ${count == 1 ? 'variante' : 'variantes'}${count > 0 ? ' • $activeCount activas' : ''}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (count > 1) ...[
              Tooltip(
                message: isAllExpanded ? 'Colapsar todo' : 'Expandir todo',
                waitDuration: const Duration(milliseconds: 300),
                child:
                    isMobile
                        ? IconButton(
                          onPressed: widget.onToggleExpandCollapseAll,
                          icon: Icon(
                            isAllExpanded
                                ? Icons.unfold_less_rounded
                                : Icons.unfold_more_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          splashRadius: 16,
                        )
                        : TextButton.icon(
                          onPressed: widget.onToggleExpandCollapseAll,
                          icon: Icon(
                            isAllExpanded
                                ? Icons.unfold_less_rounded
                                : Icons.unfold_more_rounded,
                            size: 16,
                          ),
                          label: Text(
                            isAllExpanded ? 'Colapsar todo' : 'Expandir todo',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                          ),
                        ),
              ),
              SizedBox(width: isMobile ? 4 : 6),
            ],
            FilledButton.icon(
              onPressed: cubit.addVariantDraft,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                isMobile ? 'Agregar' : 'Agregar variante',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radius),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVariantsList(ProductFormCubit cubit) {
    return BlocBuilder<ProductFormCubit, ProductFormState>(
      buildWhen: (p, c) => p.variantDrafts != c.variantDrafts,
      builder: (context, state) {
        if (state.variantDrafts.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppColors.radius),
            ),
            child: const Text(
              'Sin variantes aún. Agrega una si este producto cambia por color, talla, etc.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          );
        }

        final totalCount = state.variantDrafts.length;
        final term = _variantSearchTerm.trim().toLowerCase();

        final List<int> filteredIndices = [];
        for (int i = 0; i < totalCount; i++) {
          if (term.isEmpty) {
            filteredIndices.add(i);
          } else {
            final d = state.variantDrafts[i];
            final matchSku = d.sku.toLowerCase().contains(term);
            final matchNum = (i + 1).toString() == term;
            final matchAttr = d.selectedAttributes.any((a) {
              final an = (a['attribute_name'] ?? '').toString().toLowerCase();
              final vn = (a['value_name'] ?? '').toString().toLowerCase();
              return an.contains(term) || vn.contains(term);
            });
            if (matchSku || matchNum || matchAttr) {
              filteredIndices.add(i);
            }
          }
        }

        return Column(
          children: [
            if (totalCount > 4) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _variantSearchCtrl,
                  onChanged: (val) => setState(() => _variantSearchTerm = val),
                  decoration: InputDecoration(
                    hintText: 'Filtrar variantes por modelo, atributo o SKU...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade400,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon:
                        _variantSearchTerm.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _variantSearchCtrl.clear();
                                setState(() => _variantSearchTerm = '');
                              },
                            )
                            : null,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            ],
            if (filteredIndices.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppColors.radius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'No se encontraron variantes que coincidan con "$_variantSearchTerm"',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ...filteredIndices.map((index) {
                final draft = state.variantDrafts[index];
                return VariantDraftCard(
                  key: ValueKey(draft.id ?? 'variant_draft_$index'),
                  index: index,
                  draft: draft,
                  isExpanded: widget.allExpanded,
                  onRemove: () => cubit.removeVariantDraft(index),
                  onDuplicate: () => cubit.duplicateVariantDraft(index),
                  onActiveChanged: (val) {
                    cubit.updateVariantDraft(
                      index,
                      draft.copyWith(isActive: val),
                      syncState: true,
                    );
                  },
                  onPickImage: () => cubit.pickVariantImage(index),
                  onUpdate:
                      (newDraft, {syncState = false}) =>
                          cubit.updateVariantDraft(
                            index,
                            newDraft,
                            syncState: syncState,
                          ),
                );
              }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: cubit.addVariantDraft,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Agregar otra variante'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radius),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
