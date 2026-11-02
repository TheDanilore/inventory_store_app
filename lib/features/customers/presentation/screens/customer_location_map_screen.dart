import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:inventory_store_app/core/services/geocoding_service.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_location_map/controls/customer_map_controls.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_location_map/map/customer_map_base.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_location_map/picker/customer_map_picker_panel.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_location_map/picker/customer_map_picker_pin.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_location_map/picker/customer_map_search_bar.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_location_map/picker/customer_map_search_results.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_location_map/viewer/customer_map_viewer_header.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_location_map/viewer/customer_map_viewer_panel.dart';

/// Pantalla moderna de visualización y selección de ubicaciones de cliente en mapa.
/// - Si [isPickerMode] = true, permite buscar/fijar un punto y retorna un [PlaceResult] via Navigator.pop().
/// - Si [isPickerMode] = false, visualiza las ubicaciones con panel de detalles y enlace a Google Maps.
///
/// Refactorizada con arquitectura modular, cero rebuilds globales al buscar o mover el mapa,
/// y soporte de caché LRU para geocodificación.
class CustomerLocationMapScreen extends StatefulWidget {
  final List<CustomerLocationEntity> locations;
  final CustomerLocationEntity? focusedLocation;
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
  final GeocodingService _geocodingService = GeocodingService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final ValueNotifier<LatLng> _pickerPointNotifier;
  final ValueNotifier<String?> _addressNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _isSearchingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isLocatingNotifier = ValueNotifier(false);
  final ValueNotifier<List<PlaceResult>> _searchResultsNotifier = ValueNotifier(
    [],
  );

  CustomerLocationEntity? _selectedLocation;

  StreamSubscription<MapEvent>? _mapEventSubscription;
  Timer? _positionThrottle;
  Timer? _searchDebounce;
  bool _isReverseGeocoding = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation =
        widget.focusedLocation ??
        (widget.locations.isNotEmpty ? widget.locations.first : null);

    _pickerPointNotifier = ValueNotifier(
      widget.initialPickerPoint ?? _initialCenter,
    );

    if (widget.isPickerMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapEventSubscription = _mapController.mapEventStream.listen(
          _onMapEvent,
          cancelOnError: false,
        );
        _fetchAddressForCenter();
      });
    }
  }

  @override
  void dispose() {
    _positionThrottle?.cancel();
    _searchDebounce?.cancel();
    _mapEventSubscription?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pickerPointNotifier.dispose();
    _addressNotifier.dispose();
    _isSearchingNotifier.dispose();
    _isLocatingNotifier.dispose();
    _searchResultsNotifier.dispose();
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
    return const LatLng(-9.0853, -78.5783); // Chimbote, Perú
  }

  double get _initialZoom {
    if (widget.isPickerMode) return 15.5;
    if (widget.focusedLocation != null) return 16.0;
    if (widget.locations.length == 1) return 16.0;
    return 13.5;
  }

  void _onMapEvent(MapEvent event) {
    if (!mounted) return;

    final isEndEvent =
        event is MapEventMoveEnd ||
        event is MapEventScrollWheelZoom ||
        event is MapEventDoubleTapZoom ||
        event is MapEventFlingAnimationEnd;

    if (isEndEvent) {
      _positionThrottle?.cancel();
      _positionThrottle = Timer(const Duration(milliseconds: 350), () {
        if (mounted) {
          _pickerPointNotifier.value = _mapController.camera.center;
          _fetchAddressForCenter();
        }
      });
    }
  }

  Future<void> _fetchAddressForCenter() async {
    if (_isReverseGeocoding) return;
    _isReverseGeocoding = true;
    _addressNotifier.value = 'Buscando dirección...';

    final center = _mapController.camera.center;
    final address = await _geocodingService.reverseGeocode(
      center.latitude,
      center.longitude,
    );

    if (mounted) {
      _addressNotifier.value = address ?? 'Punto marcado en el mapa';
      _isReverseGeocoding = false;
    }
  }

  void _onSearchQueryChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      _searchResultsNotifier.value = [];
      _isSearchingNotifier.value = false;
      return;
    }

    _isSearchingNotifier.value = true;
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _geocodingService.searchPlaces(
        query,
        locationBias: _mapController.camera.center,
      );
      if (mounted) {
        _searchResultsNotifier.value = results;
        _isSearchingNotifier.value = false;
      }
    });
  }

  void _selectSearchResult(PlaceResult place) {
    final target = LatLng(place.latitude, place.longitude);
    _mapController.move(target, 16.5);
    _pickerPointNotifier.value = target;
    _addressNotifier.value = place.fullAddress;
    _searchController.text = place.name;
    _searchFocusNode.unfocus();
    _searchResultsNotifier.value = [];
  }

  void _confirmPickerPoint() {
    final currentCenter = _mapController.camera.center;
    final result = PlaceResult(
      name: _addressNotifier.value ?? 'Ubicación seleccionada',
      latitude: currentCenter.latitude,
      longitude: currentCenter.longitude,
      city: null,
      state: null,
      country: null,
    );
    Navigator.of(context).pop(result);
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      (currentZoom + 1).clamp(9.0, 18.0),
    );
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      (currentZoom - 1).clamp(9.0, 18.0),
    );
  }

  Future<void> _locateMe() async {
    _isLocatingNotifier.value = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El servicio de ubicación (GPS) está desactivado en el dispositivo',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 7),
          ),
        );
        final target = LatLng(pos.latitude, pos.longitude);
        _mapController.move(target, 16.5);
        if (widget.isPickerMode) {
          _pickerPointNotifier.value = target;
          _fetchAddressForCenter();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de ubicación no concedido'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, st) {
      LoggerService.e(
        'Error al obtener ubicación GPS en mapa',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación GPS actual'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) _isLocatingNotifier.value = false;
    }
  }

  void _fitAllLocations() {
    if (widget.locations.isEmpty) return;
    if (widget.locations.length == 1) {
      final loc = widget.locations.first;
      _mapController.move(LatLng(loc.latitude, loc.longitude), 16.0);
      setState(() => _selectedLocation = loc);
      return;
    }

    final points =
        widget.locations.map((l) => LatLng(l.latitude, l.longitude)).toList();
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(70)),
    );
  }

  Future<void> _openInExternalMaps(double lat, double lng, String label) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyCoordinates(double lat, double lng) {
    Clipboard.setData(ClipboardData(text: '$lat, $lng'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Coordenadas copiadas: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Marker> _buildMarkers() {
    if (widget.isPickerMode) return const [];
    final markers = <Marker>[];

    for (final loc in widget.locations) {
      final isSelected = _selectedLocation?.id == loc.id;
      final color = CustomerLocationTypeHelper.getColor(loc.locationType);
      final icon = CustomerLocationTypeHelper.getIcon(loc.locationType);

      markers.add(
        Marker(
          point: LatLng(loc.latitude, loc.longitude),
          width: isSelected ? 52 : 44,
          height: isSelected ? 52 : 44,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedLocation = loc);
              _mapController.move(LatLng(loc.latitude, loc.longitude), 16.0);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : color,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? color : Colors.black).withValues(
                      alpha: 0.35,
                    ),
                    blurRadius: isSelected ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: isSelected ? 26 : 22,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle =
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    final bottomControlPos =
        widget.isPickerMode
            ? 230.0
            : (widget.locations.length > 1 ? 285.0 : 225.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // 1. Mapa Base con OpenStreetMap
            CustomerMapBase(
              mapController: _mapController,
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              markers: _buildMarkers(),
              onTap: (tapPos, point) {
                if (_searchFocusNode.hasFocus) {
                  _searchFocusNode.unfocus();
                }
                if (_searchResultsNotifier.value.isNotEmpty) {
                  _searchResultsNotifier.value = [];
                }
              },
            ),

            // 2. Pin Central Fijo (Solo Picker Mode)
            if (widget.isPickerMode) const CustomerMapPickerPin(),

            // 3. Controles Flotantes del Mapa (Zoom / GPS / Reset)
            ValueListenableBuilder<bool>(
              valueListenable: _isLocatingNotifier,
              builder: (context, isLocating, _) {
                return CustomerMapControls(
                  onZoomIn: _zoomIn,
                  onZoomOut: _zoomOut,
                  onLocateMe: _locateMe,
                  isLocating: isLocating,
                  onFitAll: _fitAllLocations,
                  showFitAll:
                      !widget.isPickerMode && widget.locations.length > 1,
                  bottomPosition: bottomControlPos,
                );
              },
            ),

            // 4. Cabecera Flotante (Buscador o Título)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isPickerMode)
                        CustomerMapSearchBar(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _onSearchQueryChanged,
                          onClear: () {
                            _searchController.clear();
                            _onSearchQueryChanged('');
                          },
                          isSearchingNotifier: _isSearchingNotifier,
                          onBack: () => Navigator.of(context).pop(),
                        )
                      else
                        CustomerMapViewerHeader(
                          onBack: () => Navigator.of(context).pop(),
                          selectedLocationName: _selectedLocation?.name,
                          locationsCount: widget.locations.length,
                        ),

                      // Resultados de búsqueda emergentes en Picker Mode
                      if (widget.isPickerMode)
                        ValueListenableBuilder<List<PlaceResult>>(
                          valueListenable: _searchResultsNotifier,
                          builder: (context, results, _) {
                            return CustomerMapSearchResults(
                              results: results,
                              onSelectPlace: _selectSearchResult,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Panel Inferior
            if (widget.isPickerMode)
              CustomerMapPickerPanel(
                addressNotifier: _addressNotifier,
                pointNotifier: _pickerPointNotifier,
                onConfirm: _confirmPickerPoint,
              )
            else if (_selectedLocation != null)
              CustomerMapViewerPanel(
                locations: widget.locations,
                selectedLocation: _selectedLocation!,
                onSelectLocation: (loc) {
                  setState(() => _selectedLocation = loc);
                  _mapController.move(
                    LatLng(loc.latitude, loc.longitude),
                    16.0,
                  );
                },
                onCopyCoordinates: _copyCoordinates,
                onOpenExternalMaps: _openInExternalMaps,
              ),

            // 6. Créditos OpenStreetMap
            Positioned(
              left: 16,
              bottom: bottomControlPos,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Text(
                    '© OpenStreetMap',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
