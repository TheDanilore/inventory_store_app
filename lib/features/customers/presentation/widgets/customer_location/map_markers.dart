import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_location_entity.dart';

/// Marcador estático para ubicaciones ya guardadas en el mapa.
class MapMarker extends StatelessWidget {
  final CustomerLocationEntity location;
  final Color color;
  final IconData icon;

  const MapMarker({
    super.key,
    required this.location,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

/// Pin central fijo que se muestra en modo selección (estilo Uber).
class MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final bool isPicked;

  const MapPin({
    super.key,
    required this.color,
    required this.icon,
    this.isPicked = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: isPicked ? 16 : 6,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2.5),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
