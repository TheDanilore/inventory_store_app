import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/geocoding_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Menú flotante desplegable con la lista de lugares sugeridos por la búsqueda de Photon/OSM.
class CustomerMapSearchResults extends StatelessWidget {
  final List<PlaceResult> results;
  final ValueChanged<PlaceResult> onSelectPlace;

  const CustomerMapSearchResults({
    super.key,
    required this.results,
    required this.onSelectPlace,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

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
          itemCount: results.length,
          separatorBuilder:
              (context, i) => const Divider(height: 1, color: AppColors.border),
          itemBuilder: (context, index) {
            final place = results[index];
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
              onTap: () => onSelectPlace(place),
            );
          },
        ),
      ),
    );
  }
}
