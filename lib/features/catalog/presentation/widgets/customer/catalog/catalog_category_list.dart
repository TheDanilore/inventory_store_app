import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibration/vibration.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/customer_catalog/customer_catalog_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class CatalogCategoryList extends StatelessWidget {
  const CatalogCategoryList({super.key});

  static const Map<String, IconData> _categoryIcons = {
    'Bebidas': Icons.local_drink_outlined,
    'Snacks': Icons.cookie_outlined,
    'Lácteos': Icons.egg_outlined,
    'Carnes': Icons.set_meal_outlined,
    'Frutas': Icons.spa_outlined,
    'Limpieza': Icons.cleaning_services_outlined,
    'Panadería': Icons.bakery_dining_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CustomerCatalogCubit>();
    final state = context.watch<CustomerCatalogCubit>().state;
    final categories = state.categories;
    final selectedId = state.selectedCategoryId;

    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = selectedId == null;
            return _CategoryChip(
              label: 'Todos',
              icon: Icons.dashboard_outlined,
              isSelected: isSelected,
              onTap: () {
                if (!kIsWeb) Vibration.vibrate(duration: 30, amplitude: 64);
                cubit.selectCategory(null);
              },
            );
          }
          final category = categories[index - 1];
          final String? catId = category.id;
          final String catName = category.name;
          final isSelected = catId == selectedId;
          final icon = _categoryIcons[catName] ?? Icons.category_outlined;

          return _CategoryChip(
            label: catName,
            icon: icon,
            isSelected: isSelected,
            onTap: () {
              if (!kIsWeb) Vibration.vibrate(duration: 30, amplitude: 64);
              cubit.selectCategory(catId);
            },
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primary
                    : (_isHovered ? Colors.grey.shade100 : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isSelected
                      ? AppColors.primary
                      : (_isHovered
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : Colors.grey.shade300),
              width: 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : (_isHovered
                        ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : null),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
