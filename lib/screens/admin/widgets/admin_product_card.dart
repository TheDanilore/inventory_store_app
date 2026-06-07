import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/screens/shared/product_detail_screen.dart';

class AdminProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onSale;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;

  const AdminProductCard({
    super.key,
    required this.product,
    required this.onSale,
    required this.onToggleActive,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isAgotado = product.totalStock <= 0;
    final isDesactivado = !product.isActive; // VALIDACIÓN NUEVA

    return Card(
      elevation: isDesactivado ? 1 : 3, // Menos sombra si está desactivado
      // COLOR DE FONDO DINÁMICO: Prioriza gris oscuro si está inactivo
      color:
          isDesactivado
              ? Colors.grey[200]
              : (isAgotado ? Colors.grey[100] : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => ProductDetailScreen(product: product, isAdmin: true),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Imagen base opaca si está descontinuado
                  Opacity(
                    opacity: isDesactivado ? 0.5 : 1.0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child:
                          product.images.isNotEmpty
                              ? Image.network(
                                product.images
                                    .firstWhere(
                                      (img) => img.isMain,
                                      orElse: () => product.images.first,
                                    )
                                    .imageUrl,
                                fit: BoxFit.cover,
                              )
                              : Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                    ),
                  ),

                  // CAPA SUPERPUESTA (BANNER TEXTO)
                  if (isDesactivado)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.7),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'INACTIVO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    )
                  else if (isAgotado)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'AGOTADO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      // Texto tachado si está inactivo (opcional, da un buen toque)
                      color: isDesactivado ? Colors.grey[600] : Colors.black,
                      decoration:
                          isDesactivado ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'S/ ${product.salePrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isDesactivado ? Colors.grey : Colors.teal,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock: ${product.totalStock}',
                    style: TextStyle(
                      color:
                          isDesactivado ? Colors.grey[500] : Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: IconButton(
                          tooltip: 'Vender',
                          // Deshabilitado si está agotado O desactivado
                          onPressed:
                              (isAgotado || isDesactivado) ? null : onSale,
                          icon: const Icon(Icons.point_of_sale),
                        ),
                      ),
                      Expanded(
                        child: IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: onEdit,
                        ),
                      ),
                      Expanded(
                        child: IconButton(
                          tooltip: isDesactivado ? 'Activar' : 'Desactivar',
                          onPressed: onToggleActive,
                          icon: Icon(
                            isDesactivado
                                ? Icons.check_circle_outline
                                : Icons.delete_outline,
                            color: isDesactivado ? Colors.green : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
