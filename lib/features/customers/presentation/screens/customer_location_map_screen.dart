import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/services/geocoding_service.dart';

/// Pantalla moderna de visualización y selección de ubicaciones de cliente en mapa.
/// - Si [isPickerMode] = true, permite buscar/fijar un punto y retorna un [PlaceResult] via Navigator.pop().
/// - Si [isPickerMode] = false, visualiza las ubicaciones con panel de detalles y enlace a Google Maps.
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
  CustomerLocationEntity? _selectedLocation;

  StreamSubscription<MapEvent>? _mapEventSubscription;
  Timer? _positionThrottle;
  Timer? _searchDebounce;
  bool _isReverseGeocoding = false;
  bool _isSearching = false;
  bool _isLocating = false;
  List<PlaceResult> _searchResults = [];

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
    setState(() => _isReverseGeocoding = true);
    _addressNotifier.value = 'Buscando dirección...';

    final center = _mapController.camera.center;
    final address = await _geocodingService.reverseGeocode(
      center.latitude,
      center.longitude,
    );

    if (mounted) {
      _addressNotifier.value = address ?? 'Punto marcado en el mapa';
      setState(() => _isReverseGeocoding = false);
    }
  }

  void _onSearchQueryChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _geocodingService.searchPlaces(
        query,
        locationBias: _mapController.camera.center,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
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
    setState(() {
      _searchResults = [];
    });
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
    setState(() => _isLocating = true);
    try {
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación GPS actual'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
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

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    if (!widget.isPickerMode) {
      for (final loc in widget.locations) {
        final isSelected = _selectedLocation?.id == loc.id;
        final color = _typeColor(loc.locationType);
        final icon = _typeIcon(loc.locationType);

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
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle =
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ── 1. Mapa Base ──────────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: _initialZoom,
                minZoom: 8.0,
                maxZoom: 18.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (tapPos, point) {
                  if (_searchFocusNode.hasFocus) {
                    _searchFocusNode.unfocus();
                  }
                  if (_searchResults.isNotEmpty) {
                    setState(() => _searchResults = []);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.inventorystore.app',
                  keepBuffer: 2,
                  errorTileCallback: (tile, error, stackTrace) {},
                ),
                MarkerLayer(markers: markers),
              ],
            ),

            // ── 2. Pin Central Fijo (Solo Picker Mode) ────────────────────
            if (widget.isPickerMode)
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 42),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge flotante sobre el pin
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pan_tool_alt_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Mueve el mapa para fijar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Icono de Pin
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.place_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      // Sombra en el suelo del mapa
                      Container(
                        width: 10,
                        height: 5,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── 3. Controles Flotantes del Mapa (Zoom / GPS / Reset) ───────
            Positioned(
              right: 16,
              bottom:
                  widget.isPickerMode
                      ? 230
                      : (widget.locations.length > 1 ? 285 : 225),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Acercar (+)',
                    onTap: _zoomIn,
                  ),
                  const SizedBox(height: 8),
                  _buildMapButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Alejar (-)',
                    onTap: _zoomOut,
                  ),
                  const SizedBox(height: 12),
                  _buildMapButton(
                    icon:
                        _isLocating
                            ? Icons.hourglass_top_rounded
                            : Icons.my_location_rounded,
                    tooltip: 'Mi ubicación GPS',
                    iconColor: AppColors.teal,
                    onTap: _locateMe,
                  ),
                  if (!widget.isPickerMode && widget.locations.length > 1) ...[
                    const SizedBox(height: 8),
                    _buildMapButton(
                      icon: Icons.fullscreen_rounded,
                      tooltip: 'Ver todas las ubicaciones',
                      iconColor: AppColors.primary,
                      onTap: _fitAllLocations,
                    ),
                  ],
                ],
              ),
            ),

            // ── 4. Cabecera Flotante (Buscador o Título) ───────────────────
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
                        _buildFloatingSearchBar(context)
                      else
                        _buildViewerHeader(context),

                      // Resultados de búsqueda emergentes en Picker Mode
                      if (widget.isPickerMode && _searchResults.isNotEmpty)
                        _buildSearchResultsDropdown(),
                    ],
                  ),
                ),
              ),
            ),

            // ── 5. Panel Inferior ──────────────────────────────────────────
            if (widget.isPickerMode)
              _buildPickerBottomPanel(context)
            else if (_selectedLocation != null)
              _buildViewerBottomPanel(context),

            // ── 6. Créditos OpenStreetMap ─────────────────────────────────
            Positioned(
              left: 16,
              bottom:
                  widget.isPickerMode
                      ? 230
                      : (widget.locations.length > 1 ? 285 : 225),
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

  // ── Botón Circular Estilizado para el Mapa ─────────────────────────────
  Widget _buildMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = AppColors.textPrimary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Icon(icon, size: 20, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }

  // ── Buscador Flotante (Picker Mode) ───────────────────────────────────
  Widget _buildFloatingSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
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
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchQueryChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Buscar calle, distrito o punto...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.teal,
                ),
              ),
            )
          else if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Limpiar',
              onPressed: () {
                _searchController.clear();
                _onSearchQueryChanged('');
              },
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.search_rounded, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }

  // ── Lista de Sugerencias Flotante ─────────────────────────────────────
  Widget _buildSearchResultsDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: _searchResults.length,
          separatorBuilder:
              (context, i) => const Divider(height: 1, color: AppColors.border),
          itemBuilder: (context, index) {
            final place = _searchResults[index];
            return ListTile(
              dense: true,
              leading: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.place_rounded,
                  size: 18,
                  color: AppColors.teal,
                ),
              ),
              title: Text(
                place.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                place.fullAddress,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _selectSearchResult(place),
            );
          },
        ),
      ),
    );
  }

  // ── Cabecera para Modo Visor ──────────────────────────────────────────
  Widget _buildViewerHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ubicaciones del Cliente',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _selectedLocation?.name ?? 'Mapa de Ubicaciones',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: 13,
                  color: AppColors.teal,
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.locations.length} pto${widget.locations.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.teal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Panel Inferior (Picker Mode) ──────────────────────────────────────
  Widget _buildPickerBottomPanel(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dirección Resuelta
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.pin_drop_rounded,
                        color: AppColors.teal,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PUNTO SELECCIONADO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          ValueListenableBuilder<String?>(
                            valueListenable: _addressNotifier,
                            builder: (context, address, _) {
                              return Text(
                                address ??
                                    'Mueve el mapa para obtener la dirección',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Chip de Coordenadas
                ValueListenableBuilder<LatLng>(
                  valueListenable: _pickerPointNotifier,
                  builder: (context, point, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.gps_fixed_rounded,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Lat: ${point.latitude.toStringAsFixed(5)}, Lng: ${point.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Botón Confirmar
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _confirmPickerPoint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text(
                      'Confirmar Ubicación',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Panel Inferior (Viewer Mode) ──────────────────────────────────────
  Widget _buildViewerBottomPanel(BuildContext context) {
    final loc = _selectedLocation!;
    final color = _typeColor(loc.locationType);
    final icon = _typeIcon(loc.locationType);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector de ubicaciones si hay más de una
                if (widget.locations.length > 1) ...[
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.locations.length,
                      separatorBuilder:
                          (context, i) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final item = widget.locations[idx];
                        final isSelected = item.id == loc.id;
                        final itemColor = _typeColor(item.locationType);

                        return InkWell(
                          onTap: () {
                            setState(() => _selectedLocation = item);
                            _mapController.move(
                              LatLng(item.latitude, item.longitude),
                              16.0,
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? itemColor : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    isSelected ? itemColor : AppColors.border,
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow:
                                  isSelected
                                      ? [
                                        BoxShadow(
                                          color: itemColor.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                      : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _typeIcon(item.locationType),
                                  size: 13,
                                  color: isSelected ? Colors.white : itemColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 12),
                ],

                // Datos de la ubicación seleccionada
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  loc.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (loc.isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Principal',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            CustomerLocationEntity.typeLabel(loc.locationType),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          if (loc.addressLine != null &&
                              loc.addressLine!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              loc.addressLine!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (loc.reference != null &&
                              loc.reference!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Ref: ${loc.reference!}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Acciones (Abrir en Google Maps / Copiar Coordenadas)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            () => _copyCoordinates(loc.latitude, loc.longitude),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          backgroundColor: AppColors.background,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text(
                          'Copiar Coords',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            () => _openInExternalMaps(
                              loc.latitude,
                              loc.longitude,
                              loc.name,
                            ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.directions_rounded, size: 17),
                        label: const Text(
                          'Google Maps',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
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
