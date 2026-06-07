import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_product_card.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';

class CatalogGrid extends StatelessWidget {
  final List<ProductModel> products;
  final int pageSize;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final void Function(ProductModel) onSale;
  final void Function(ProductModel) onToggleActive;
  final void Function(ProductModel) onEdit; 

  const CatalogGrid({
    super.key,
    required this.products,
    required this.pageSize,
    required this.currentPage,
    required this.onPageChanged,
    required this.onSale,
    required this.onToggleActive,
    required this.onEdit, 
  });

  @override
  Widget build(BuildContext context) {
    final total = products.length;
    final totalPages = total == 0 ? 1 : (total / pageSize).ceil();
    final safeCurrentPage = currentPage >= totalPages ? totalPages - 1 : currentPage;
    final start = safeCurrentPage * pageSize;
    final end = (start + pageSize) > total ? total : (start + pageSize);
    final pageItems = products.sublist(start, end);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                'Mostrando ${start + 1}-$end de $total',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                'Página ${safeCurrentPage + 1} / $totalPages',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: pageItems.length,
            itemBuilder: (context, index) {
              final product = pageItems[index];
              return AdminProductCard(
                product: product,
                onSale: () => onSale(product),
                onToggleActive: () => onToggleActive(product),
                onEdit: () => onEdit(product), 
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: AdminPageBlocks(
            currentPage: safeCurrentPage,
            totalPages: totalPages,
            onPageChanged: onPageChanged,
          ),
        ),
      ],
    );
  }
}