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
    );
    if (result == null) return;
    try {
      await provider.addLocation(result);
      AppSnackbar.showMessenger(
        messenger,
        message: 'Ubicación agregada.',
        type: SnackbarType.success,
      );
    } catch (e) {
      AppSnackbar.showMessenger(
        messenger,
        message: 'Error al guardar: $e',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _editLocation(
    BuildContext context,
    CustomerLocation loc,
  ) async {
    final provider = context.read<CustomerDetailProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await CustomerLocationFormSheet.show(
      context,
      existing: loc,
    );
    if (result == null) return;
    try {
      await provider.updateLocation(loc.id, result);
      AppSnackbar.showMessenger(
        messenger,
        message: 'Ubicación actualizada.',
        type: SnackbarType.success,
      );
    } catch (e) {
      AppSnackbar.showMessenger(
        messenger,
        message: 'Error al actualizar: $e',
        type: SnackbarType.error,
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
            GestureDetector(
              onTap: () => _openAllMap(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 13, color: AppColors.info),
                    SizedBox(width: 4),
                    Text(
                      'Ver mapa',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.info,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _addLocation(context),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 16,
                color: AppColors.teal,
              ),
            ),
          ),
        ],
      ),
      child:
          locations.isEmpty
              ? _EmptyLocations(onAdd: () => _addLocation(context))
              : Column(
                children: locations
                    .map(
                      (loc) => _LocationItem(
                        location: loc,
                        typeColor: _typeColor(loc.locationType),
                        typeIcon: _typeIcon(loc.locationType),
                        onView: () => _openMap(context, loc),
                        onEdit: () => _editLocation(context, loc),
                        onDelete: () => _deleteLocation(context, loc),
                      ),
                    )
                    .toList(),
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: location.isDefault
              ? typeColor.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Ícono tipo
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeIcon, size: 18, color: typeColor),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            location.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (location.isDefault)
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
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CustomerLocation.typeLabel(location.locationType),
                      style: TextStyle(
                        fontSize: 11,
                        color: typeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (location.addressLine != null &&
                        location.addressLine!.isNotEmpty)
                      Text(
                        location.addressLine!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              // Acciones
              Column(
                children: [
                  GestureDetector(
                    onTap: onView,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        size: 14,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 14,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
