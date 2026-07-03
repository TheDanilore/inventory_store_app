import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/models/customer_location.dart';
import 'package:inventory_store_app/providers/admin/customer_detail_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/screens/shared/customer_location_form_sheet.dart';
import 'package:inventory_store_app/screens/shared/customer_location_map_screen.dart';
import 'customer_section_card.dart';

class CustomerLocationsSection extends StatelessWidget {
  final List<CustomerLocation> locations;

  const CustomerLocationsSection({super.key, required this.locations});

  Color _typeColor(String type) {
    switch (type) {
      case 'casa':
        return AppColors.info;
      case 'chacra':
        return AppColors.teal;
      case 'fundo':
        return AppColors.warning;
      case 'local':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'casa':
        return Icons.home_rounded;
      case 'chacra':
        return Icons.grass_rounded;
      case 'fundo':
        return Icons.agriculture_rounded;
      case 'local':
        return Icons.store_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  Future<void> _addLocation(BuildContext context) async {
    final provider = context.read<CustomerDetailProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await CustomerLocationFormSheet.show(
      context,
      isFirstLocation: locations.isEmpty,
      onSave: (loc) async {
        await provider.addLocation(loc);
      },
    );

    if (result == true) {
      AppSnackbar.showMessenger(
        messenger,
        message: 'Ubicación agregada.',
        type: SnackbarType.success,
      );
    }
  }

  Future<void> _editLocation(BuildContext context, CustomerLocation loc) async {
    final provider = context.read<CustomerDetailProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await CustomerLocationFormSheet.show(
      context,
      existing: loc,
      onSave: (updatedLoc) async {
        await provider.updateLocation(loc.id, updatedLoc);
      },
    );

    if (result == true) {
      AppSnackbar.showMessenger(
        messenger,
        message: 'Ubicación actualizada.',
        type: SnackbarType.success,
      );
    }
  }

  Future<void> _deleteLocation(
    BuildContext context,
    CustomerLocation loc,
  ) async {
    final provider = context.read<CustomerDetailProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Eliminar ubicación',
      message: '¿Eliminar "${loc.name}"?',
      confirmText: 'Eliminar',
      confirmColor: AppColors.error,
    );
    if (confirmed != true) return;
    try {
      await provider.deleteLocation(loc.id);
      AppSnackbar.showMessenger(
        messenger,
        message: 'Ubicación eliminada.',
        type: SnackbarType.success,
      );
    } catch (e) {
      AppSnackbar.showMessenger(
        messenger,
        message: 'Error: $e',
        type: SnackbarType.error,
      );
    }
  }

  void _openMap(BuildContext context, CustomerLocation loc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => CustomerLocationMapScreen(
              locations: locations,
              focusedLocation: loc,
            ),
      ),
    );
  }

  void _openAllMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerLocationMapScreen(locations: locations),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomerSectionCard(
      title: 'Ubicaciones',
      icon: Icons.map_rounded,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (locations.isNotEmpty)
            FilledButton.tonalIcon(
              onPressed: () => _openAllMap(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.info.withValues(alpha: 0.1),
                foregroundColor: AppColors.info,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                visualDensity: VisualDensity.compact,
                elevation: 0,
              ),
              icon: const Icon(Icons.map_outlined, size: 16),
              label: const Text(
                'Ver mapa',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () => _addLocation(context),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.tealLight,
              foregroundColor: AppColors.teal,
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            tooltip: 'Añadir ubicación',
          ),
        ],
      ),
      child:
          locations.isEmpty
              ? _EmptyLocations(onAdd: () => _addLocation(context))
              : LayoutBuilder(
                builder: (context, constraints) {
                  // Adaptive layout: Wrap para comportarse como Bento Grid
                  // En móvil ocupará el 100%, en PC ocupará el 50% (2 columnas) o 33% (3 columnas)
                  final double width = constraints.maxWidth;
                  int crossAxisCount = 1;
                  if (width > 800) {
                    crossAxisCount = 3;
                  } else if (width > 500) {
                    crossAxisCount = 2;
                  }

                  final double itemWidth =
                      (width - (12 * (crossAxisCount - 1))) / crossAxisCount;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children:
                        locations.map((loc) {
                          return SizedBox(
                            width: itemWidth,
                            child: _LocationItem(
                              location: loc,
                              typeColor: _typeColor(loc.locationType),
                              typeIcon: _typeIcon(loc.locationType),
                              onView: () => _openMap(context, loc),
                              onEdit: () => _editLocation(context, loc),
                              onDelete: () => _deleteLocation(context, loc),
                            ),
                          );
                        }).toList(),
                  );
                },
              ),
    );
  }
}

class _EmptyLocations extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyLocations({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_location_alt_rounded,
                  color: AppColors.teal,
                  size: 28,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sin ubicaciones registradas',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Agrega chacras, fundos, casas\ny otros puntos de entrega',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.teal,
              side: BorderSide(color: AppColors.teal.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.add_location_alt_rounded, size: 16),
            label: const Text(
              'Agregar primera ubicación',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationItem extends StatelessWidget {
  final CustomerLocation location;
  final Color typeColor;
  final IconData typeIcon;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LocationItem({
    required this.location,
    required this.typeColor,
    required this.typeIcon,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color:
              location.isDefault
                  ? typeColor.withValues(alpha: 0.4)
                  : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onView,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ícono tipo
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, size: 20, color: typeColor),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              location.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (location.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Principal',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: typeColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CustomerLocation.typeLabel(location.locationType),
                        style: TextStyle(
                          fontSize: 12,
                          color: typeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (location.addressLine != null &&
                          location.addressLine!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            location.addressLine!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Acciones (Menu Kebab)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  position: PopupMenuPosition.under,
                  onSelected: (val) {
                    if (val == 'map') onView();
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'map',
                          child: Row(
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 18,
                                color: AppColors.info,
                              ),
                              SizedBox(width: 12),
                              Text('Ver mapa'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 12),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppColors.error,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Eliminar',
                                style: TextStyle(color: AppColors.error),
                              ),
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
    );
  }
}
