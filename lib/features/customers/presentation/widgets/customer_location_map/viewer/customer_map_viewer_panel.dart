import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';

/// Helper para colores e íconos por tipo de ubicación.
class CustomerLocationTypeHelper {
  static Color getColor(String type) {
    switch (type.toLowerCase()) {
      case 'casa':
      case 'home':
        return AppColors.info;
      case 'chacra':
        return AppColors.teal;
      case 'fundo':
      case 'work':
        return AppColors.warning;
      case 'local':
      case 'store':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  static IconData getIcon(String type) {
    switch (type.toLowerCase()) {
      case 'casa':
      case 'home':
        return Icons.home_rounded;
      case 'chacra':
        return Icons.grass_rounded;
      case 'fundo':
      case 'work':
        return Icons.agriculture_rounded;
      case 'local':
      case 'store':
        return Icons.store_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }
}

/// Panel inferior en modo visor: selector horizontal de sedes, ficha de detalles y botones de acción (Google Maps y Copiar Coords).
class CustomerMapViewerPanel extends StatelessWidget {
  final List<CustomerLocationEntity> locations;
  final CustomerLocationEntity selectedLocation;
  final ValueChanged<CustomerLocationEntity> onSelectLocation;
  final void Function(double lat, double lng) onCopyCoordinates;
  final void Function(double lat, double lng, String label) onOpenExternalMaps;

  const CustomerMapViewerPanel({
    super.key,
    required this.locations,
    required this.selectedLocation,
    required this.onSelectLocation,
    required this.onCopyCoordinates,
    required this.onOpenExternalMaps,
  });

  @override
  Widget build(BuildContext context) {
    final color = CustomerLocationTypeHelper.getColor(
      selectedLocation.locationType,
    );
    final icon = CustomerLocationTypeHelper.getIcon(
      selectedLocation.locationType,
    );

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector horizontal de ubicaciones (si hay más de una)
                if (locations.length > 1) ...[
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: locations.length,
                      separatorBuilder:
                          (context, i) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final item = locations[idx];
                        final isSelected = item.id == selectedLocation.id;
                        final itemColor = CustomerLocationTypeHelper.getColor(
                          item.locationType,
                        );

                        return InkWell(
                          onTap: () => onSelectLocation(item),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? itemColor : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    isSelected ? itemColor : AppColors.border,
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow:
                                  isSelected
                                      ? [
                                        BoxShadow(
                                          color: itemColor.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                      : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CustomerLocationTypeHelper.getIcon(
                                    item.locationType,
                                  ),
                                  size: 13,
                                  color: isSelected ? Colors.white : itemColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 12),
                ],

                // Datos de la ubicación seleccionada
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  selectedLocation.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (selectedLocation.isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Principal',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            CustomerLocationEntity.typeLabel(
                              selectedLocation.locationType,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          if (selectedLocation.addressLine != null &&
                              selectedLocation.addressLine!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              selectedLocation.addressLine!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (selectedLocation.reference != null &&
                              selectedLocation.reference!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Ref: ${selectedLocation.reference!}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Acciones (Abrir en Google Maps / Copiar Coordenadas)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            () => onCopyCoordinates(
                              selectedLocation.latitude,
                              selectedLocation.longitude,
                            ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          backgroundColor: AppColors.background,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text(
                          'Copiar Coords',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            () => onOpenExternalMaps(
                              selectedLocation.latitude,
                              selectedLocation.longitude,
                              selectedLocation.name,
                            ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.directions_rounded, size: 17),
                        label: const Text(
                          'Google Maps',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
