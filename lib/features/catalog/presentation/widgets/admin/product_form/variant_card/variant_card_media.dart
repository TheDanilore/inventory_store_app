import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_draft_form_model.dart';

class VariantCardMedia extends StatelessWidget {
  final VariantDraftFormModel draft;
  final VoidCallback onPickImage;
  final ValueChanged<String> onSetExternalUrl;
  final VoidCallback onClearImage;

  const VariantCardMedia({
    super.key,
    required this.draft,
    required this.onPickImage,
    required this.onSetExternalUrl,
    required this.onClearImage,
  });

  Future<void> _promptForImageUrl(BuildContext context) async {
    String? url;
    await showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Pegar URL de Imagen'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                url = ctrl.text.trim();
                Navigator.pop(ctx);
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
    if (url != null && url!.isNotEmpty) {
      onSetExternalUrl(url!);
    }
  }

  Widget _buildAddButtons(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onPickImage,
          child: Container(
            margin: const EdgeInsets.only(right: 8, top: 4),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
                style: BorderStyle.solid,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
                SizedBox(height: 4),
                Text(
                  'Subir',
                  style: TextStyle(fontSize: 10, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _promptForImageUrl(context),
          child: Container(
            margin: const EdgeInsets.only(right: 8, top: 4),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.blueGrey.withValues(alpha: 0.4),
                style: BorderStyle.solid,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.link_rounded, color: Colors.blueGrey, size: 22),
                SizedBox(height: 4),
                Text(
                  'URL',
                  style: TextStyle(fontSize: 10, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(Widget image) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8, top: 6),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: image,
          ),
        ),
        Positioned(
          top: 0,
          right: 2,
          child: GestureDetector(
            onTap: onClearImage,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.red,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 14,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Text(
              'Imagen de la variante',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(Máximo 1)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: Row(
            children: [
              if (draft.urlsExistentes.isEmpty &&
                  draft.nuevasImagenes.isEmpty &&
                  draft.externalImageUrl == null)
                _buildAddButtons(context),
              if (draft.urlsExistentes.isNotEmpty)
                _buildThumbnail(
                  CachedNetworkImage(
                    imageUrl: draft.urlsExistentes.first,
                    fit: BoxFit.cover,
                    placeholder:
                        (_, _) =>
                            const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, _, _) => const Icon(Icons.error),
                  ),
                ),
              if (draft.externalImageUrl != null)
                _buildThumbnail(
                  CachedNetworkImage(
                    imageUrl: draft.externalImageUrl!,
                    fit: BoxFit.cover,
                    placeholder:
                        (_, _) =>
                            const Center(child: CircularProgressIndicator()),
                    errorWidget:
                        (_, _, _) =>
                            const Icon(Icons.broken_image, color: Colors.red),
                  ),
                ),
              if (draft.nuevasImagenes.isNotEmpty)
                _buildThumbnail(
                  Image.memory(draft.nuevasImagenes.first, fit: BoxFit.cover),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
