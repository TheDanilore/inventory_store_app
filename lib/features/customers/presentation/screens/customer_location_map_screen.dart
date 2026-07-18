import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_location/map_markers.dart';
import 'package:inventory_store_app/core/services/geocoding_service.dart';

/// Pantalla de mapa.
/// - Si [isPickerMode] = true, retorna un [PlaceResult] via Navigator.pop().
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

  late final ValueNotifier<LatLng> _pickerPointNotifier;
  final ValueNotifier<String?> _addressNotifier = ValueNotifier(null);

  StreamSubscription<MapEvent>? _mapEventSubscription;
  Timer? _positionThrottle;
  bool _isReverseGeocoding = false;

  @override
  void initState() {
    super.initState();
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
    _mapEventSubscription?.cancel();
    _mapController.dispose();
    _pickerPointNotifier.dispose();
    _addressNotifier.dispose();
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

  void _onMapEvent(MapEvent event) {
    if (!mounted) return;

    final isEndEvent =
        event is MapEventMoveEnd ||
        event is MapEventScrollWheelZoom ||
        event is MapEventDoubleTapZoom ||
        event is MapEventFlingAnimationEnd;

    if (isEndEvent) {
      _positionThrottle?.cancel();
      _positionThrottle = Timer(const Duration(milliseconds: 300), () {
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
      _addressNotifier.value = address ?? 'Dirección desconocida';
      _isReverseGeocoding = false;
    }
  }

  void _confirmPickerPoint() {
    final currentCenter = _mapController.camera.center;
    final result = PlaceResult(
      name: _addressNotifier.value ?? 'Ubicación',
      latitude: currentCenter.latitude,
      longitude: currentCenter.longitude,
      city: null,
      state: null,
      country: null,
    );
    Navigator.of(context).pop(result);
  }

  Future<void> _openSearch() async {
    final result = await showSearch<PlaceResult?>(
      context: context,
      delegate: _PlaceSearchDelegate(
        _geocodingService,
        _mapController.camera.center,
      ),
    );

    if (result != null && mounted) {
      _mapController.move(LatLng(result.latitude, result.longitude), 16.0);
      _pickerPointNotifier.value = LatLng(result.latitude, result.longitude);
      _addressNotifier.value = result.fullAddress;
    }
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
              minZoom: 9.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.inventorystore.app',
                keepBuffer: 1,
                errorTileCallback: (tile, error, stackTrace) {},
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // ── Pin central fijo ─────────────────────────────
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

          // ── Buscador Flotante (Solo Picker) ─────────────────────
          if (widget.isPickerMode)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: _openSearch,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: AppColors.textPrimary,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Buscar calle o lugar...',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            // Header normal de vista
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
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
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            widget.focusedLocation?.name ?? 'Ubicaciones',
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

          // ── Panel Inferior (Solo Picker) ────────────────────────
          if (widget.isPickerMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  MediaQuery.paddingOf(context).bottom + 20,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dirección
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.tealLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.teal,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ValueListenableBuilder<String?>(
                            valueListenable: _addressNotifier,
                            builder: (context, address, _) {
                              return Text(
                                address ??
                                    'Mueve el mapa para encontrar la dirección',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Botón Confirmar
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _confirmPickerPoint,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Confirmar Ubicación',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Créditos OSM ───────────────────
          if (!widget.isPickerMode)
            Positioned(
              bottom: 4,
              right: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
    );
  }
}

class _PlaceSearchDelegate extends SearchDelegate<PlaceResult?> {
  final GeocodingService service;
  final LatLng currentCenter;

  _PlaceSearchDelegate(this.service, this.currentCenter);

  @override
  String get searchFieldLabel => 'Buscar dirección...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    return _DebouncedSearchSuggestions(
      query: query,
      service: service,
      currentCenter: currentCenter,
      onSelected: (place) => close(context, place),
    );
  }
}

class _DebouncedSearchSuggestions extends StatefulWidget {
  final String query;
  final GeocodingService service;
  final LatLng currentCenter;
  final ValueChanged<PlaceResult> onSelected;

  const _DebouncedSearchSuggestions({
    required this.query,
    required this.service,
    required this.currentCenter,
    required this.onSelected,
  });

  @override
  State<_DebouncedSearchSuggestions> createState() => _DebouncedSearchSuggestionsState();
}

class _DebouncedSearchSuggestionsState extends State<_DebouncedSearchSuggestions> {
  Timer? _debounce;
  Future<List<PlaceResult>>? _searchFuture;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _triggerSearch(widget.query);
  }

  @override
  void didUpdateWidget(covariant _DebouncedSearchSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _triggerSearch(widget.query);
    }
  }

  void _triggerSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchFuture = null;
      });
      return;
    }
    
    if (query == _lastQuery && _searchFuture != null) return;
    _lastQuery = query;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchFuture = widget.service.searchPlaces(query, locationBias: widget.currentCenter);
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isEmpty) {
      return const Center(child: Text('Escribe para buscar...'));
    }

    if (_searchFuture == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    }

    return FutureBuilder<List<PlaceResult>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.teal),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No se encontraron resultados'));
        }

        final results = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final place = results[index];
            return ListTile(
              leading: const Icon(
                Icons.location_on_rounded,
                color: AppColors.textMuted,
              ),
              title: Text(
                place.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(place.fullAddress),
              onTap: () => widget.onSelected(place),
            );
          },
        );
      },
    );
  }
}
