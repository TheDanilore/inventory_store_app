import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/models/product_image_model.dart';
import 'package:go_router/go_router.dart';

// ─── GALLERY ─────────────────────────────────────────────────────────────────

class ProductGallerySection extends StatelessWidget {
  final List<ProductImageModel> images;
  final PageController pageController;
  final int selectedIndex;
  final ValueChanged<int> onPageChanged;
  final Widget? wishlistWidget;
  final String? variantImageOverrideUrl;
  final String? variantLabelOverride;
  final String? fallbackImageUrl;

  const ProductGallerySection({
    super.key,
    required this.images,
    required this.pageController,
    required this.selectedIndex,
    required this.onPageChanged,
    this.wishlistWidget,
    this.variantImageOverrideUrl,
    this.variantLabelOverride,
    this.fallbackImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveUrls = <String>[];
    if (variantImageOverrideUrl != null) {
      effectiveUrls.add(variantImageOverrideUrl!);
    } else {
      if (fallbackImageUrl != null && fallbackImageUrl!.isNotEmpty) {
        effectiveUrls.add(fallbackImageUrl!);
      }
      for (final img in images) {
        if (fallbackImageUrl == null || img.imageUrl != fallbackImageUrl) {
          effectiveUrls.add(img.imageUrl);
        }
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.white),
        PageView.builder(
          controller: pageController,
          itemCount: effectiveUrls.isNotEmpty ? effectiveUrls.length : 1,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) {
            if (effectiveUrls.isEmpty) {
              return Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                ),
              );
            }
            return GestureDetector(
              onTap:
                  () => context.push(
                    '/gallery',
                    extra: {'imageUrls': effectiveUrls, 'initialIndex': index},
                  ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: effectiveUrls.length > 1 && variantLabelOverride == null ? 72 : 16,
                  right: 16,
                  top: 16,
                  bottom: 16,
                ),
                child: CachedNetworkImage(
                  imageUrl: effectiveUrls[index],
                  fit: BoxFit.contain,
                  placeholder:
                      (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                  errorWidget:
                      (_, _, _) => const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                      ),
                ),
              ),
            );
          },
        ),

        if (wishlistWidget != null)
          Positioned(top: 14, right: 14, child: wishlistWidget!),

        if (variantLabelOverride != null &&
            variantLabelOverride!.trim().isNotEmpty)
          Positioned(
            bottom: 28,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  variantLabelOverride!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),

        if (effectiveUrls.isNotEmpty)
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.open_in_full_rounded,
                color: Colors.white,
                size: 13,
              ),
            ),
          ),

        if (effectiveUrls.length > 1 && variantLabelOverride == null)
          Positioned(
            top: 20,
            bottom: 20,
            left: 12,
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    effectiveUrls.length,
                    (i) => GestureDetector(
                      onTap: () {
                        if (pageController.hasClients) {
                          pageController.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color:
                                i == selectedIndex
                                    ? AppColors.primary
                                    : AppColors.border,
                            width: i == selectedIndex ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            if (i == selectedIndex)
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: effectiveUrls[i],
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            errorWidget:
                                (_, _, _) => const Icon(
                                  Icons.broken_image_rounded,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
