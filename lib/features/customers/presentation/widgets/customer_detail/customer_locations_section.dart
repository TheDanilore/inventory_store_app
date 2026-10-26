import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/services/geocoding_service.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_locations/customer_locations_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_location/customer_location_form_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_location_map_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_detail/customer_section_card.dart';

class CustomerLocationsSection extends StatelessWidget {
  final List<CustomerLocationEntity> locations;
  final String customerId;

  const CustomerLocationsSection({
    super.key,
    required this.locations,
    required this.customerId,
  });

  Color _typeColor(String type) {
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

  IconData _typeIcon(String type) {
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

  Future<void> _addLocation(BuildContext context) async {
    final cubit = context.read<CustomerLocationsCubit>();
    final messenger = ScaffoldMessenger.of(context);

    // 1. Abrir primero el mapa interactivo para seleccionar el punto exacto
    final place = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<PlaceResult?>(
      MaterialPageRoute(
        builder: (_) => const CustomerLocationMapScreen(isPickerMode: true),
      ),
    );

    if (place == null || !context.mounted) return;

    // 2. Abrir el formulario pre-llenado con las coordenadas y dirección seleccionadas
    final result = await CustomerLocationFormSheet.show(
      context,
      place: place,
      isFirstLocation: locations.isEmpty,
      onSave: (loc) async {
        await cubit.addLocation(
          customerId: customerId,
          name: loc.name,
          locationType: loc.locationType,
          latitude: loc.latitude,
          longitude: loc.longitude,
          addressLine: loc.addressLine,
          reference: loc.reference,
          notes: loc.notes,
          isDefault: loc.isDefault,
        );
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

  Future<void> _editLocation(
    BuildContext context,
    CustomerLocationEntity loc,
  ) async {
    final cubit = context.read<CustomerLocationsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await CustomerLocationFormSheet.show(
      context,
      existing: loc,
      onSave: (updatedLoc) async {
        await cubit.updateLocation(customerId, loc.id, updatedLoc);
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
    CustomerLocationEntity loc,
  ) async {
    final cubit = context.read<CustomerLocationsCubit>();
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
      await cubit.deleteLocation(customerId, loc.id);
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

  void _openMap(BuildContext context, CustomerLocationEntity loc) {
    Navigator.of(context, rootNavigator: true).push(
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
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CustomerLocationMapScreen(locations: locations),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 600;

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
                backgroundColor: AppColors.infoLight,
                foregroundColor: AppColors.info,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.map_rounded, size: 15),
              label: const Text(
                'Ver mapa',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () => _addLocation(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.tealLight,
              foregroundColor: AppColors.teal,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 12 : 8,
                vertical: 6,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_location_alt_rounded, size: 16),
            label: Text(
              isDesktop ? 'Nueva' : '+',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
      child:
          locations.isEmpty
              ? _EmptyLocations(onAdd: () => _addLocation(context))
              : LayoutBuilder(
                builder: (context, constraints) {
                  final double width = constraints.maxWidth;
                  int crossAxisCount = 1;
                  if (width > 800) {
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
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: AppColors.tealLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_location_alt_rounded,
                  color: AppColors.teal,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sin ubicaciones registradas',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Agrega chacras, fundos, almacenes o casas\npara entregas y referencias logísticas',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.tealLight,
              foregroundColor: AppColors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
            label: const Text(
              'Agregar primera ubicación',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationItem extends StatelessWidget {
  final CustomerLocationEntity location;
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color:
              location.isDefault
                  ? typeColor.withValues(alpha: 0.5)
                  : AppColors.border,
          width: location.isDefault ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onView,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícono de tipo
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(typeIcon, size: 20, color: typeColor),
                    ),
                    const SizedBox(width: 12),
                    // Título y Tipo
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
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (location.isDefault) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        size: 11,
                                        color: AppColors.success,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        'Principal',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CustomerLocationEntity.typeLabel(
                              location.locationType,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: typeColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Menú de opciones
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
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
                                    Icons.map_rounded,
                                    size: 17,
                                    color: AppColors.info,
                                  ),
                                  SizedBox(width: 10),
                                  Text('Ver en mapa'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 17,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 10),
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
                                    size: 17,
                                    color: AppColors.error,
                                  ),
                                  SizedBox(width: 10),
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

                // Dirección
                if (location.addressLine != null &&
                    location.addressLine!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          location.addressLine!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Referencia
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
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          location.reference!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),

                // Coordenadas & Botón Rápido de Mapa
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: onView,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 13,
                              color: typeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Abrir mapa',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: typeColor,
                              ),
                            ),
                          ],
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
