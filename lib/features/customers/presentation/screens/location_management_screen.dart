import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_locations_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_locations_state.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_location/customer_location_form_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_location_map_screen.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/customer_layout.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_location/location_card.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/services/geocoding_service.dart';

class LocationManagementScreen extends StatelessWidget {
  final String customerId;

  const LocationManagementScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CustomerLocationsCubit>()..loadLocations(customerId),
      child: _LocationManagementView(customerId: customerId),
    );
  }
}

class _LocationManagementView extends StatelessWidget {
  final String customerId;

  const _LocationManagementView({required this.customerId});

  Future<void> _addLocation(
    BuildContext context,
    CustomerLocationsState state,
  ) async {
    final cubit = context.read<CustomerLocationsCubit>();
    final isFirst =
        state is CustomerLocationsLoaded ? state.locations.isEmpty : true;

    final place = await Navigator.of(context).push<PlaceResult?>(
      MaterialPageRoute(
        builder: (_) => const CustomerLocationMapScreen(isPickerMode: true),
      ),
    );

    if (place == null || !context.mounted) return;

    final res = await CustomerLocationFormSheet.show(
      context,
      place: place,
      isFirstLocation: isFirst,
      onSave: (location) async {
        await cubit.addLocation(
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
      },
    );
    if (res == true && context.mounted) {
      AppSnackbar.show(
        context,
        message: 'Ubicación guardada.',
        type: SnackbarType.success,
      );
      cubit.loadLocations(customerId);
    }
  }

  Future<void> _editLocation(
    BuildContext context,
    CustomerLocationEntity loc,
  ) async {
    final cubit = context.read<CustomerLocationsCubit>();
    final res = await CustomerLocationFormSheet.show(
      context,
      existing: loc,
      onSave: (location) async {
        await cubit.updateLocation(customerId, loc.id, location);
      },
    );
    if (res == true && context.mounted) {
      AppSnackbar.show(
        context,
        message: 'Ubicación actualizada.',
        type: SnackbarType.success,
      );
      cubit.loadLocations(customerId);
    }
  }

  Future<void> _setDefault(
    BuildContext context,
    CustomerLocationEntity loc,
  ) async {
    final cubit = context.read<CustomerLocationsCubit>();
    try {
      await cubit.setAsDefault(customerId, loc.id);
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: 'Ubicación principal actualizada.',
        type: SnackbarType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString(),
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _deleteLocation(
    BuildContext context,
    CustomerLocationEntity loc,
  ) async {
    final cubit = context.read<CustomerLocationsCubit>();
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Eliminar ubicación',
      message: '¿Eliminar "${loc.name}"? Esta acción no se puede deshacer.',
      confirmText: 'Eliminar',
      confirmColor: AppColors.error,
    );
    if (confirmed != true) return;
    try {
      await cubit.deleteLocation(customerId, loc.id);
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: 'Ubicación eliminada.',
        type: SnackbarType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString(),
        type: SnackbarType.error,
      );
    }
  }

  void _openMap(
    BuildContext context,
    CustomerLocationEntity loc,
    List<CustomerLocationEntity> all,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) =>
                CustomerLocationMapScreen(locations: all, focusedLocation: loc),
      ),
    );
  }

  void _openAllMap(BuildContext context, List<CustomerLocationEntity> all) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerLocationMapScreen(locations: all),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerLocationsCubit, CustomerLocationsState>(
      builder: (context, state) {
        return CustomerLayout(
          title: 'Mis Ubicaciones',
          showBackButton: true,
          showBottomNav: false,
          showCartIcon: false,
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              context.read<CustomerLocationsCubit>().loadLocations(customerId);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildHeaderBanner(context, state),
                  ),
                ),
                _buildBody(context, state),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderBanner(
    BuildContext context,
    CustomerLocationsState state,
  ) {
    List<CustomerLocationEntity> locations = [];
    if (state is CustomerLocationsLoaded) {
      locations = state.locations;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.teal, Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis Ubicaciones',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  locations.isEmpty
                      ? 'Agrega tus chacras, fundos y casas'
                      : '${locations.length} registrada${locations.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (locations.isNotEmpty)
            GestureDetector(
              onTap: () => _openAllMap(context, locations),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.map_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Ver mapa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.add_location_alt_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, CustomerLocationsState state) {
    if (state is CustomerLocationsLoading ||
        state is CustomerLocationsInitial) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: AppShimmer(
              width: double.infinity,
              height: 120,
              borderRadius: 20,
            ),
          ),
          childCount: 3,
        ),
      );
    }

    if (state is CustomerLocationsError) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: AppEmptyState(
            icon: Icons.error_outline,
            title: 'Algo salió mal',
            message: state.message,
          ),
        ),
      );
    }

    if (state is CustomerLocationsLoaded) {
      final locations = state.locations;

      if (locations.isEmpty) {
        return SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 24),
              const AppEmptyState(
                icon: Icons.add_location_alt_outlined,
                title: 'Sin ubicaciones aún',
                message:
                    'Agrega tus chacras, fundos y casas\npara que te encontremos fácilmente.',
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _addLocation(context, state),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      elevation: 6,
                      shadowColor: AppColors.teal.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                    label: const Text(
                      'Agregar primera ubicación',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == locations.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _addLocation(context, state),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    side: BorderSide(
                      color: AppColors.teal.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                  label: const Text(
                    'Agregar nueva ubicación',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            );
          }

          final loc = locations[index];
          return LocationCard(
            location: loc,
            isProcessing: false,
            onView: () => _openMap(context, loc, locations),
            onEdit: () => _editLocation(context, loc),
            onSetDefault: () => _setDefault(context, loc),
            onDelete: () => _deleteLocation(context, loc),
          );
        }, childCount: locations.length + 1),
      );
    }

    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }
}
