import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:inventory_store_app/models/customer_location.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/screens/shared/widgets/map_markers.dart';

/// Pantalla de mapa compartida.
///
/// Modos:
/// - [isPickerMode] = false → muestra ubicaciones existentes (solo vista)
/// - [isPickerMode] = true  → permite tocar el mapa para elegir coordenadas;
///   al confirmar retorna un [LatLng] via Navigator.pop().
class CustomerLocationMapScreen extends StatefulWidget {
  final List<CustomerLocation> locations;
  final CustomerLocation? focusedLocation; // null = mostrar todas
  final bool isPickerMode;
  final LatLng? initialPickerPoint;

  const CustomerLocationMapScreen({
    super.key,
    this.locations = const [],
    this.focusedLocation,
    this.isPickerMode = false,
    this.initialPickerPoint,
  });

  @override
  State<CustomerLocationMapScreen> createState() =>
      _CustomerLocationMapScreenState();
}

class _CustomerLocationMapScreenState extends State<CustomerLocationMapScreen> {
  final MapController _mapController = MapController();
  late final ValueNotifier<LatLng> _pickerPointNotifier;

  @override
  void initState() {
    super.initState();
    _pickerPointNotifier = ValueNotifier(widget.initialPickerPoint ?? _initialCenter);
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pickerPointNotifier.dispose();
    super.dispose();
  }

  LatLng get _initialCenter {
    if (widget.isPickerMode && widget.initialPickerPoint != null) {
      return widget.initialPickerPoint!;
    }
    if (widget.focusedLocation != null) {
      return LatLng(
        widget.focusedLocation!.latitude,
        widget.focusedLocation!.longitude,
      );
    }
    if (widget.locations.isNotEmpty) {
      final lat =
          widget.locations.map((l) => l.latitude).reduce((a, b) => a + b) /
          widget.locations.length;
      final lng =
          widget.locations.map((l) => l.longitude).reduce((a, b) => a + b) /
          widget.locations.length;
      return LatLng(lat, lng);
    }
    // Default: Chimbote, Perú
    return const LatLng(-9.0853, -78.5783);
  }

  double get _initialZoom {
    if (widget.isPickerMode) return 15.0;
    if (widget.focusedLocation != null) return 16.0;
    if (widget.locations.length == 1) return 16.0;
    if (widget.locations.length > 1) return 13.0;
    return 13.0;
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

  void _handleMapTap(TapPosition tapPos, LatLng latLng) {
    // Ya no usamos tap para poner el pin, el pin está fijo al centro.
  }

  void _onPositionChanged(MapCamera position, bool hasGesture) {
    if (widget.isPickerMode) {
      _pickerPointNotifier.value = position.center;
    }
  }

  void _confirmPickerPoint() {
    Navigator.of(context).pop(_pickerPointNotifier.value);
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    if (!widget.isPickerMode) {
      final locs =
          widget.focusedLocation != null
              ? [widget.focusedLocation!]
              : widget.locations;
      for (final loc in locs) {
        markers.add(
          Marker(
            point: LatLng(loc.latitude, loc.longitude),
            width: 100,
            height: 100,
            child: UnconstrainedBox(
              child: MapMarker(
                location: loc,
                color: _typeColor(loc.locationType),
                icon: _typeIcon(loc.locationType),
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.isPickerMode
              ? 'Toca para elegir ubicación'
              : widget.focusedLocation?.name ?? 'Ubicaciones',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        actions: [
          if (widget.isPickerMode)
            TextButton.icon(
              onPressed: _confirmPickerPoint,
              icon: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Confirmar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              maxZoom: 19.0,
              onTap: _handleMapTap,
              onPositionChanged: _onPositionChanged,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.inventorystore.app',
                maxZoom: 19.0,
                maxNativeZoom: 19,
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          
          // Pin central fijo (Modo Uber)
          if (widget.isPickerMode)
            const Center(
              child: FractionalTranslation(
                // Desplaza el pin hacia arriba para que la punta inferior coincida con el centro exacto
                translation: Offset(0, -0.5),
                child: MapPin(
                  color: AppColors.accent,
                  icon: Icons.push_pin_rounded,
                  isPicked: true,
                ),
              ),
            ),

          // Instrucción en modo picker
          if (widget.isPickerMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<LatLng>(
                      valueListenable: _pickerPointNotifier,
                      builder: (context, currentPoint, child) {
                        return Text(
                          'Lat: ${currentPoint.latitude.toStringAsFixed(5)}, Lng: ${currentPoint.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          // Créditos OSM (obligatorio por licencia)
          Positioned(
            bottom: 4,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton:
          widget.isPickerMode
              ? FloatingActionButton.extended(
                onPressed: _confirmPickerPoint,
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.check_rounded),
                label: const Text(
                  'Usar este punto',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
              : null,
    );
  }
}
