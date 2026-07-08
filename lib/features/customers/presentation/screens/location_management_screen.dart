import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/customers/data/models/customer_location.dart';
import 'package:inventory_store_app/features/customers/presentation/providers/customer_locations_provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/customer_layout.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_location_form_sheet.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_location_map_screen.dart';

class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() =>
      _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerLocationsProvider>().init();
    });
  }

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

  Future<void> _addLocation(CustomerLocationsProvider provider) async {
    final result = await CustomerLocationFormSheet.show(
      context,
      isFirstLocation: provider.locations.isEmpty,
      onSave: (loc) async {
        await provider.addLocation(loc);
      },
    );
    if (result == true && mounted) {
      AppSnackbar.show(
        context,
        message: 'Ubicación guardada.',
        type: SnackbarType.success,
      );
    }
  }

  Future<void> _editLocation(
    CustomerLocationsProvider provider,
    CustomerLocation loc,
  ) async {
    final result = await CustomerLocationFormSheet.show(
      context,
      existing: loc,
      onSave: (updatedLoc) async {
        await provider.updateLocation(loc.id, updatedLoc);
      },
    );
    if (result == true && mounted) {
      AppSnackbar.show(
        context,
        message: 'Ubicación actualizada.',
        type: SnackbarType.success,
      );
    }
  }

  Future<void> _setDefault(
    CustomerLocationsProvider provider,
    CustomerLocation loc,
  ) async {
    try {
      await provider.setDefaultLocation(loc.id);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Ubicación principal actualizada.',
        type: SnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString(),
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _deleteLocation(
    CustomerLocationsProvider provider,
    CustomerLocation loc,
  ) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Eliminar ubicación',
      message: '¿Eliminar "${loc.name}"? Esta acción no se puede deshacer.',
      confirmText: 'Eliminar',
      confirmColor: AppColors.error,
    );
    if (confirmed != true) return;
    try {
      await provider.deleteLocation(loc.id);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Ubicación eliminada.',
        type: SnackbarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString(),
        type: SnackbarType.error,
      );
    }
  }

  void _openMap(CustomerLocationsProvider provider, CustomerLocation loc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerLocationMapScreen(
          locations: provider.locations,
          focusedLocation: loc,
        ),
      ),
    );
  }

  void _openAllMap(CustomerLocationsProvider provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerLocationMapScreen(locations: provider.locations),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerLocationsProvider>();

    return CustomerLayout(
      title: 'Mis Ubicaciones',
      showBackButton: true,
      showBottomNav: false,
      showCartIcon: false,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: provider.loadLocations,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildHeaderBanner(context, provider),
              ),
            ),
            // Cuerpo
            _buildBody(context, provider),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(
    BuildContext context,
    CustomerLocationsProvider provider,
  ) {
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
                  provider.locations.isEmpty
                      ? 'Agrega tus chacras, fundos y casas'
                      : '${provider.locations.length} registrada${provider.locations.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (provider.locations.isNotEmpty)
            GestureDetector(
              onTap: () => _openAllMap(provider),
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

  Widget _buildBody(
    BuildContext context,
    CustomerLocationsProvider provider,
  ) {
    if (provider.isLoading) {
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

    if (provider.profileId == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: AppEmptyState(
            icon: Icons.person_off_outlined,
            title: 'Necesitas iniciar sesión',
            message: 'Inicia sesión para gestionar tus ubicaciones.',
          ),
        ),
      );
    }

    if (provider.errorMessage.isNotEmpty && provider.locations.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: AppEmptyState(
            icon: Icons.error_outline,
            title: 'Algo salió mal',
            message: provider.errorMessage,
          ),
        ),
      );
    }

    if (provider.locations.isEmpty) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            const SizedBox(height: 24),
            AppEmptyState(
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
                  onPressed: () => _addLocation(provider),
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
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == provider.locations.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _addLocation(provider),
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

          final loc = provider.locations[index];
          final isProcessing = provider.isItemProcessing(loc.id);
          final color = _typeColor(loc.locationType);
          final icon = _typeIcon(loc.locationType);

          return _LocationCard(
            location: loc,
            typeColor: color,
            typeIcon: icon,
            isProcessing: isProcessing,
            onView: () => _openMap(provider, loc),
            onEdit: () => _editLocation(provider, loc),
            onSetDefault: () => _setDefault(provider, loc),
            onDelete: () => _deleteLocation(provider, loc),
          );
        },
        childCount: provider.locations.length + 1,
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final CustomerLocation location;
  final Color typeColor;
  final IconData typeIcon;
  final bool isProcessing;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _LocationCard({
    required this.location,
    required this.typeColor,
    required this.typeIcon,
    required this.isProcessing,
    required this.onView,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: location.isDefault
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
                            CustomerLocation.typeLabel(location.locationType),
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
