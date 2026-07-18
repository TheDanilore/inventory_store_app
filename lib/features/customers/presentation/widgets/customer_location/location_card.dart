import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class LocationCard extends StatelessWidget {
  final CustomerLocationEntity location;
  final bool isProcessing;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const LocationCard({
    super.key,
    required this.location,
    required this.isProcessing,
    required this.onView,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'casa':
      case 'home':
        return AppColors.info;
      case 'chacra':
        return AppColors.teal;
      case 'work':
      case 'fundo':
        return AppColors.warning;
      case 'store':
      case 'local':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'casa':
      case 'home':
        return Icons.home_rounded;
      case 'chacra':
        return Icons.grass_rounded;
      case 'work':
      case 'fundo':
        return Icons.agriculture_rounded;
      case 'store':
      case 'local':
        return Icons.store_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(location.locationType);
    final typeIcon = _typeIcon(location.locationType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              location.isDefault
                  ? typeColor.withValues(alpha: 0.4)
                  : AppColors.border,
          width: location.isDefault ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Stack(
        children: [
          if (isProcessing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.teal,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(typeIcon, size: 22, color: typeColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            CustomerLocationEntity.typeLabel(
                              location.locationType,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: typeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (location.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Principal',
                          style: TextStyle(
                            fontSize: 11,
                            color: typeColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Coordenadas
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        size: 13,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Lat ${location.latitude.toStringAsFixed(5)}, Lng ${location.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                if (location.addressLine != null &&
                    location.addressLine!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    location.addressLine!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (location.reference != null &&
                    location.reference!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.signpost_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location.reference!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                // Acciones
                Row(
                  children: [
                    _ActionBtn(
                      icon: Icons.map_rounded,
                      label: 'Ver mapa',
                      color: AppColors.info,
                      onTap: onView,
                    ),
                    const SizedBox(width: 8),
                    _ActionBtn(
                      icon: Icons.edit_rounded,
                      label: 'Editar',
                      color: AppColors.primary,
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 8),
                    if (!location.isDefault)
                      _ActionBtn(
                        icon: Icons.star_rounded,
                        label: 'Principal',
                        color: typeColor,
                        onTap: onSetDefault,
                      ),
                    if (!location.isDefault) const SizedBox(width: 8),
                    const Spacer(),
                    _ActionBtn(
                      icon: Icons.delete_outline_rounded,
                      label: 'Eliminar',
                      color: AppColors.error,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
