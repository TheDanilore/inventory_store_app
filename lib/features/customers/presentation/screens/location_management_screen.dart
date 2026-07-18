import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_locations_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_locations_state.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_location/customer_location_form_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_location_map_screen.dart';

class LocationManagementScreen extends StatelessWidget {
  final String customerId;

  const LocationManagementScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CustomerLocationsCubit>()..loadLocations(customerId),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ubicaciones'),
          backgroundColor: AppColors.background,
        ),
        body: const _LocationManagementContent(),
        floatingActionButton: Builder(
          builder:
              (context) => FloatingActionButton(
                onPressed: () => _openForm(context, null),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add_location_alt_rounded),
              ),
        ),
      ),
    );
  }

  void _openForm(BuildContext context, CustomerLocationEntity? loc) async {
    final customerId =
        context.read<CustomerLocationsCubit>().state is CustomerLocationsLoaded
            ? this.customerId
            : this.customerId;
    final res = await CustomerLocationFormSheet.show(
      context,
      existing: loc,
      onSave: (location) async {
        if (loc == null) {
          await context.read<CustomerLocationsCubit>().addLocation(
            customerId: customerId,
            name: location.name,
            locationType: location.locationType,
            latitude: location.latitude,
            longitude: location.longitude,
            addressLine: location.addressLine,
            reference: location.reference,
            notes: location.notes,
            isDefault: location.isDefault,
          );
        } else {
          await context.read<CustomerLocationsCubit>().updateLocation(
            customerId,
            loc.id,
            location,
          );
        }
      },
    );
    if (res == true && context.mounted) {
      context.read<CustomerLocationsCubit>().loadLocations(customerId);
    }
  }
}

class _LocationManagementContent extends StatelessWidget {
  const _LocationManagementContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerLocationsCubit, CustomerLocationsState>(
      builder: (context, state) {
        if (state is CustomerLocationsLoading ||
            state is CustomerLocationsInitial) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is CustomerLocationsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  state.message,
                  style: const TextStyle(color: AppColors.danger),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Needs customerId, but we can't easily get it if we only have error state.
                    // For now, we leave it as is or require customerId in error state.
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        } else if (state is CustomerLocationsLoaded) {
          final locations = state.locations;
          if (locations.isEmpty) {
            return const Center(child: Text('No hay ubicaciones registradas'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: locations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final loc = locations[index];
              return _LocationCard(location: loc);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _LocationCard extends StatelessWidget {
  final CustomerLocationEntity location;

  const _LocationCard({required this.location});

  @override
  Widget build(BuildContext context) {
    IconData typeIcon = Icons.location_on_rounded;
    Color typeColor = AppColors.primary;

    switch (location.locationType.toUpperCase()) {
      case 'HOME':
        typeIcon = Icons.home_rounded;
        typeColor = AppColors.info;
        break;
      case 'WORK':
        typeIcon = Icons.work_rounded;
        typeColor = AppColors.warning;
        break;
      case 'STORE':
        typeIcon = Icons.store_rounded;
        typeColor = AppColors.success;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: location.isDefault ? typeColor : AppColors.border,
          width: location.isDefault ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(typeIcon, color: typeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        CustomerLocationEntity.typeLabel(location.locationType),
                        style: TextStyle(color: typeColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (location.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Principal',
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Lat , Lng ',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (location.addressLine != null &&
                location.addressLine!.isNotEmpty)
              Text(location.addressLine!, style: const TextStyle(fontSize: 14)),
            if (location.reference != null && location.reference!.isNotEmpty)
              Text(
                location.reference!,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => CustomerLocationMapScreen(
                              locations: [location],
                              focusedLocation: location,
                            ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('Ver Mapa'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final res = await CustomerLocationFormSheet.show(
                      context,
                      existing: location,
                      onSave: (loc) async {
                        await context
                            .read<CustomerLocationsCubit>()
                            .updateLocation(
                              location.profileId,
                              location.id,
                              loc,
                            );
                      },
                    );
                    if (res == true && context.mounted) {
                      context.read<CustomerLocationsCubit>().loadLocations(
                        location.profileId,
                      );
                    }
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar'),
                ),
                if (!location.isDefault)
                  TextButton.icon(
                    onPressed: () {
                      context.read<CustomerLocationsCubit>().setAsDefault(
                        location.profileId,
                        location.id,
                      );
                    },
                    icon: const Icon(Icons.star, size: 16),
                    label: const Text('Principal'),
                  ),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (c) => AlertDialog(
                            title: const Text('Eliminar Ubicación'),
                            content: const Text(
                              '¿Está seguro de eliminar esta ubicación?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(c);
                                  context
                                      .read<CustomerLocationsCubit>()
                                      .deleteLocation(
                                        location.profileId,
                                        location.id,
                                      );
                                },
                                child: const Text(
                                  'Eliminar',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                    );
                  },
                  icon: const Icon(
                    Icons.delete,
                    size: 16,
                    color: AppColors.error,
                  ),
                  label: const Text(
                    'Eliminar',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
