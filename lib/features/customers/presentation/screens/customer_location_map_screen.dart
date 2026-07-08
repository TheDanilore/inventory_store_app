import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:inventory_store_app/features/customers/data/models/customer_location.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/map_markers.dart';

/// Pantalla de mapa compartida.
///
/// Modos:
/// - [isPickerMode] = false → muestra ubicaciones existentes (solo vista)
/// - [isPickerMode] = true  → mueve el mapa para elegir coordenadas;
///   al confirmar retorna un [LatLng] via Navigator.pop().
class CustomerLocationMapScreen extends StatefulWidget {
  final List<CustomerLocation> locations;
  final CustomerLocation? focusedLocation;
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
  StreamSubscription<MapEvent>? _mapEventSubscription;

  // Throttle: actualizar coordenadas máximo una vez cada 200ms
  // para no saturar el renderer de Flutter Web.
  Timer? _positionThrottle;

  @override
  void initState() {
    super.initState();
    _pickerPointNotifier = ValueNotifier(
      widget.initialPickerPoint ?? _initialCenter,
    );

    if (widget.isPickerMode) {
      // Escuchar eventos del mapa para actualizar al TERMINAR el movimiento
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapEventSubscription = _mapController.mapEventStream.listen(
          _onMapEvent,
          cancelOnError: false,
        );
      });
    }
  }

  @override
  void dispose() {
    _positionThrottle?.cancel();
    _mapEventSubscription?.cancel();
    _mapController.dispose();
    _pickerPointNotifier.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

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
    return const LatLng(-9.0853, -78.5783); // Default: Chimbote, Perú
  }

  double get _initialZoom {
    if (widget.isPickerMode) return 15.0;
    if (widget.focusedLocation != null) return 16.0;
    if (widget.locations.length == 1) return 16.0;
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

  // ── Handlers ──────────────────────────────────────────────────────────────

  /// Escucha eventos específicos del mapa (solo fin de movimiento).
  /// Mucho más eficiente que onPositionChanged (que dispara 60 veces/seg).
  void _onMapEvent(MapEvent event) {
    if (!mounted) return;

    final isEndEvent =
        event is MapEventMoveEnd ||
        event is MapEventScrollWheelZoom ||
        event is MapEventDoubleTapZoom ||
        event is MapEventFlingAnimationEnd;

    if (isEndEvent) {
      // Throttle extra: no actualizar si ya hay un timer pendiente
      _positionThrottle?.cancel();
      _positionThrottle = Timer(const Duration(milliseconds: 150), () {
        if (mounted) {
          _pickerPointNotifier.value = _mapController.camera.center;
        }
      });
    }
  }

  void _confirmPickerPoint() {
    // Leer la posición actual del mapa en el momento de confirmar (más preciso)
    final currentCenter = _mapController.camera.center;
    Navigator.of(context).pop(currentCenter);
  }

  // ── Build ──────────────────────────────────────────────────────────────

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
            width: 40,
            height: 40,
            child: MapMarker(
              location: loc,
              color: _typeColor(loc.locationType),
              icon: _typeIcon(loc.locationType),
            ),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Mapa ──────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              // Rango seguro para OSM público — evita tiles 404 que crashean CanvasKit
              minZoom: 9.0,
              maxZoom: 17.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.inventorystore.app',
                // keepBuffer bajo: menos tiles en memoria → menos crash en Web
                keepBuffer: 1,
                // Sin errorImage: evita cargar app_icon.png por cada tile 404
                errorTileCallback: (tile, error, stackTrace) {
                  // Silenciar errores de tiles individuales
                  debugPrint('[Map] tile ignorado: $error');
                },
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // ── Pin central fijo (Modo Uber) ─────────────────────────────
          if (widget.isPickerMode)
            const Align(
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.only(bottom: 30),
                child: MapPin(
                  color: AppColors.accent,
                  icon: Icons.push_pin_rounded,
                  isPicked: true,
                ),
              ),
            ),

          // ── Header Flotante (Reemplaza el AppBar) ─────────────────────
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Botón Atrás
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Título
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.isPickerMode
                              ? 'Mueve el mapa para elegir'
                              : widget.focusedLocation?.name ?? 'Ubicaciones',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Panel de Coordenadas Glassmorphism ────────────────────────
          if (widget.isPickerMode)
            Positioned(
              bottom: 90, // Por encima del FAB
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.center,
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.my_location_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<LatLng>(
                              valueListenable: _pickerPointNotifier,
                              builder:
                                  (_, point, _) => Text(
                                    'Lat: ${point.latitude.toStringAsFixed(5)}  •  Lng: ${point.longitude.toStringAsFixed(5)}',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Créditos OSM (obligatorio por licencia) ───────────────────
          Positioned(
            bottom: 4,
            right: 8,
            child: IgnorePointer(
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
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          widget.isPickerMode
              ? FloatingActionButton.extended(
                onPressed: _confirmPickerPoint,
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const Icon(Icons.check_rounded),
                label: const Text(
                  'Confirmar Ubicación',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
              : null,
    );
  }
}
