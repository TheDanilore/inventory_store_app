import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Capa base del mapa interactivo con OpenStreetMap y capas de marcadores.
class CustomerMapBase extends StatelessWidget {
  final MapController mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final List<Marker> markers;
  final void Function(TapPosition tapPos, LatLng point)? onTap;

  const CustomerMapBase({
    super.key,
    required this.mapController,
    required this.initialCenter,
    required this.initialZoom,
    required this.markers,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: 8.0,
        maxZoom: 18.5,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: onTap,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.inventorystore.app',
          keepBuffer:
              1, // Reducido para minimizar consumo de RAM en móviles de 1-2GB
          errorTileCallback: (tile, error, stackTrace) {},
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}
