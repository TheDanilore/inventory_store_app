import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/category_model.dart';

class CategoryChips extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: const Text('Todos'),
              selected: selectedCategoryId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(category.name),
                selected: selectedCategoryId == category.id,
                onSelected: (_) => onSelected(category.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
