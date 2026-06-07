import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_image_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class ProductImagePicker extends StatelessWidget {
  final List<ProductImageModel> existingImages;
  final List<Uint8List> nuevasImagenes;
  final VoidCallback onPickImages;
  final Function(int) onRemoveNewImage;
  final Function(ProductImageModel) onDelete;
  final Function(ProductImageModel) onSetMain;

  const ProductImagePicker({
    super.key,
    required this.existingImages,
    required this.nuevasImagenes,
    required this.onPickImages,
    required this.onRemoveNewImage,
    required this.onDelete,
    required this.onSetMain,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // 1. IMÁGENES EXISTENTES EN LA BASE DE DATOS
            ...existingImages.map(
              (img) => Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        img.isMain ? AppColors.primary : Colors.grey.shade300,
                    width: img.isMain ? 2.5 : 1,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Imagen de fondo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        img.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                      ),
                    ),

                    // BOTÓN ESTRELLA (Imagen Principal)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: _CircleIconButton(
                        icon:
                            img.isMain
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                        iconColor:
                            img.isMain ? Colors.amber : Colors.grey.shade700,
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        onPressed: () => onSetMain(img),
                      ),
                    ),

                    // BOTÓN ELIMINAR
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _CircleIconButton(
                        icon: Icons.delete_outline_rounded,
                        iconColor: Colors.red.shade600,
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        onPressed: () => onDelete(img),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. IMÁGENES NUEVAS (Temporales en memoria)
            ...nuevasImagenes.asMap().entries.map(
              (entry) => Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(entry.value, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _CircleIconButton(
                        icon: Icons.close_rounded,
                        iconColor: Colors.red.shade600,
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        onPressed: () => onRemoveNewImage(entry.key),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. BOTÓN AÑADIR NUEVA FOTO
            GestureDetector(
              onTap: onPickImages,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: Colors.grey.shade600,
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Agregar',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Widget interno para estilizar los botones circulares flotantes de las esquinas
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const _CircleIconButton({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}
