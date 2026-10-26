import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/layouts/product_form_page_header.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/layouts/product_form_floating_bar.dart';

// Secciones del Formulario
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
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_variants_table_view.dart';

/// Layout Desktop (Split ERP 2 Columnas: 65% Principal / 35% Lateral).
class ProductFormDesktopLayout extends StatelessWidget {
  final bool isEdit;
  final TextEditingController nombreCtrl;
  final TextEditingController descCtrl;
  final VoidCallback onExit;
  final VoidCallback onPreview;
  final VoidCallback onSave;

  const ProductFormDesktopLayout({
    super.key,
    required this.isEdit,
    required this.nombreCtrl,
    required this.descCtrl,
    required this.onExit,
    required this.onPreview,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductFormPageHeader(
                      isEdit: isEdit,
                      onExit: onExit,
                      onPreview: onPreview,
                      onSave: onSave,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna Principal Izquierda (65% ancho: flex 13)
                        Expanded(
                          flex: 13,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProductBasicInfoSection(
                                nombreCtrl: nombreCtrl,
                                descCtrl: descCtrl,
                              ),
                              const SizedBox(height: 20),
                              const ProductPricingInventorySection(),
                              BlocBuilder<ProductFormCubit, ProductFormState>(
                                buildWhen:
                                    (p, c) =>
                                        p.hasMultipleVariants !=
                                        c.hasMultipleVariants,
                                builder: (context, state) {
                                  if (!state.hasMultipleVariants) {
                                    return const SizedBox.shrink();
                                  }
                                  return const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 20),
                                      ProductVariantsTableView(),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              ProductSeoSection(
                                nombreCtrl: nombreCtrl,
                                descCtrl: descCtrl,
                              ),
                              const SizedBox(height: 20),
                              const ProductDetailsSection(),
                              const SizedBox(height: 20),
                              const ProductIngredientsSection(),
                              const SizedBox(height: 20),
                              const ProductBatchSection(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Columna Lateral Derecha (35% ancho: flex 7)
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const ProductImagesSection(),
                              const SizedBox(height: 20),
                              const ProductStatusCard(),
                              const SizedBox(height: 20),
                              const ProductSalesChannelsCard(),
                              const SizedBox(height: 20),
                              const ProductConfigSection(),
                              const SizedBox(height: 20),
                              const ProductChangelogCard(),
                              const SizedBox(height: 20),
                              _buildDesktopJumpNav(isEdit),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Barra flotante Glassmorphism de guardado
        ProductFormFloatingBar(
          isDesktop: true,
          isEdit: isEdit,
          nombreCtrl: nombreCtrl,
          onExit: onExit,
          onPreview: onPreview,
          onSave: onSave,
        ),
      ],
    );
  }

  // ── Jump-Nav lateral: navega a secciones del formulario ─────────────────────
  Widget _buildDesktopJumpNav(bool isEdit) {
    const sections = [
      (Icons.info_outline_rounded, 'Info básica'),
      (Icons.attach_money_rounded, 'Precios e Inventario'),
      (Icons.tune_rounded, 'Variantes'),
      (Icons.settings_outlined, 'Configuración'),
      (Icons.list_alt_rounded, 'Detalles Técnicos'),
      (Icons.science_outlined, 'Ingredientes'),
      (Icons.inventory_outlined, 'Lotes'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.format_list_bulleted_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Secciones del Formulario',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: 12),
          ...sections.asMap().entries.map((entry) {
            final idx = entry.key;
            final (icon, label) = entry.value;
            if (idx == 2) {
              return BlocSelector<ProductFormCubit, ProductFormState, bool>(
                selector: (s) => s.hasMultipleVariants,
                builder: (context, hasMultiple) {
                  if (!hasMultiple) return const SizedBox.shrink();
                  return _buildJumpNavItem(icon, label);
                },
              );
            }
            return _buildJumpNavItem(icon, label);
          }),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: 14),
          BlocSelector<ProductFormCubit, ProductFormState, bool>(
            selector: (s) => s.isDirty,
            builder: (context, isDirty) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isDirty ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color:
                        isDirty
                            ? Colors.orange.shade200
                            : Colors.green.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color:
                            isDirty
                                ? Colors.orange.shade600
                                : Colors.green.shade600,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isDirty ? 'Cambios sin guardar' : 'Todo guardado',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color:
                              isDirty
                                  ? Colors.orange.shade800
                                  : Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.keyboard_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: isEdit ? 'Ctrl+S' : 'Alt+G',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const TextSpan(text: ' para guardar · '),
                        const TextSpan(
                          text: 'Esc',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const TextSpan(text: ' para salir'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJumpNavItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: [
              Icon(icon, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.keyboard_arrow_right_rounded,
                size: 15,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
