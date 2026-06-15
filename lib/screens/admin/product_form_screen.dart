import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/providers/admin/product_form_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_primary_button.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

// Secciones modulares
import 'package:inventory_store_app/screens/admin/widgets/product_form/variant_draft_card.dart';
import 'package:inventory_store_app/screens/admin/widgets/product_form/product_images_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/product_form/product_basic_info_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/product_form/product_config_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/product_form/product_details_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/product_form/product_pricing_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/product_form/product_ingredients_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/product_form/product_batch_section.dart';

class ProductFormScreen extends StatelessWidget {
  final ProductModel? productToEdit;
  
  const ProductFormScreen({super.key, this.productToEdit});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProductFormProvider()..initData(productToEdit),
      child: _ProductFormScreenContent(),
    );
  }
}

class _ProductFormScreenContent extends StatefulWidget {
  @override
  State<_ProductFormScreenContent> createState() => _ProductFormScreenContentState();
}

class _ProductFormScreenContentState extends State<_ProductFormScreenContent> {
  final _formKey = GlobalKey<FormState>();

  Future<bool> _onWillPop(BuildContext context) async {
    final provider = context.read<ProductFormProvider>();
    if (provider.isSaving || provider.isInitializingData) return false;

    // Si deseas hacer la comprobación de campos sucios (dirty check),
    // podrías implementarlo en el provider. Por ahora, asumimos que siempre
    // mostramos el diálogo si el usuario intenta salir.
    
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Si sales ahora, los cambios no guardados se perderán. ¿Deseas salir de todas formas?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  void _guardar(BuildContext context) async {
    final provider = context.read<ProductFormProvider>();
    if (provider.isSaving) return;
    
    final success = await provider.saveProduct(context, _formKey);
    if (success && context.mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductFormProvider>();
    final isEdit = provider.productToEdit != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
         if (didPop) return;
         final shouldPop = await _onWillPop(context);
         if (shouldPop && context.mounted) {
            Navigator.pop(context);
         }
      },
      child: AdminLayout(
        title: isEdit ? 'Editar Producto' : 'Nuevo Producto',
        showBackButton: true,
        showProfileButton: false,
        body: provider.isInitializingData
            ? const _ProductFormSkeleton()
            : Stack(
                children: [
                  Form(
                    key: _formKey,
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(16.0),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: provider.isSaving ? null : () => _guardar(context),
                                  icon: const Icon(Icons.save_rounded, size: 20),
                                  label: Text(
                                    isEdit ? 'Actualizar' : 'Guardar',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const ProductImagesSection(),
                              const SizedBox(height: 16),
                              const ProductBasicInfoSection(),
                              const SizedBox(height: 16),
                              const ProductConfigSection(),
                              const SizedBox(height: 16),
                              const ProductDetailsSection(),
                              const SizedBox(height: 16),
                              ProductPricingSection(formKey: _formKey),
                              const SizedBox(height: 16),
                              const ProductIngredientsSection(),
                              const SizedBox(height: 16),
                              const ProductBatchSection(),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Variantes',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: provider.addVariantDraft,
                                    icon: const Icon(Icons.add_circle_outline),
                                    label: const Text('Agregar'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (provider.variantDrafts.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Sin variantes aún. Agrega una si este producto cambia por color, talla, etc.',
                                  ),
                                ),
                            ]),
                          ),
                        ),

                        if (provider.variantDrafts.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  return VariantDraftCard(
                                    index: index,
                                    draft: provider.variantDrafts[index],
                                    onRemove: () => provider.removeVariantDraft(context, index),
                                    onActiveChanged: (val) {
                                        provider.variantDrafts[index].isActive = val;
                                        // Esto idealmente debería notificar al provider, pero VariantDraftCard usa su estado local también.
                                    },
                                    onPickImage: () => provider.pickVariantImage(context, index),
                                  );
                                },
                                childCount: provider.variantDrafts.length,
                              ),
                            ),
                          ),

                        if (provider.variantDrafts.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: provider.addVariantDraft,
                                      icon: const Icon(Icons.add_circle_outline),
                                      label: const Text('Agregar otra variante'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: BorderSide(
                                          color: AppColors.primary.withValues(alpha: 0.3),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        SliverPadding(
                          padding: const EdgeInsets.all(16.0),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: AppPrimaryButton(
                                    label: isEdit ? 'Actualizar Producto' : 'Guardar Producto',
                                    onPressed: provider.isSaving ? null : () => _guardar(context),
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (provider.isSaving)
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ProductFormSkeleton extends StatelessWidget {
  const _ProductFormSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
             AppShimmer(width: 120, height: 40, borderRadius: 12),
          ],
        ),
        const SizedBox(height: 16),
        const AppShimmer(width: double.infinity, height: 180, borderRadius: 16),
        const SizedBox(height: 16),
        const AppShimmer(width: double.infinity, height: 300, borderRadius: 16),
        const SizedBox(height: 16),
        const AppShimmer(width: double.infinity, height: 120, borderRadius: 16),
        const SizedBox(height: 16),
        const AppShimmer(width: double.infinity, height: 250, borderRadius: 16),
      ],
    );
  }
}
