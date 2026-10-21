import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Tarjeta de identidad de marca con previsualización en tiempo real.
/// Muestra cómo aparecerá el logo, nombre, dirección y RUC en comprobantes.
class BusinessPreviewCard extends StatelessWidget {
  final String businessName;
  final String businessLogoUrl;
  final String businessAddress;
  final String businessTaxId;
  final String businessPhone;

  /// Si es null, el logo no es clicable (ej. sin permiso de edición).
  final VoidCallback? onUploadLogo;

  const BusinessPreviewCard({
    super.key,
    required this.businessName,
    required this.businessLogoUrl,
    required this.businessAddress,
    required this.businessTaxId,
    required this.businessPhone,
    this.onUploadLogo,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Identidad de Marca',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isDark
                      ? const Color(0xFFF8FAFC)
                      : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _LiveBadge(isDark: isDark),
            ],
          ),
          const SizedBox(height: 14),

          // Tarjeta corporativa simulada
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Logo (clicable solo si hay permiso)
                    onUploadLogo != null
                        ? InkWell(
                            onTap: onUploadLogo,
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                BusinessLogoBadge(logoUrl: businessLogoUrl),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : BusinessLogoBadge(logoUrl: businessLogoUrl),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        businessTaxId,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  businessName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        businessAddress,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      businessPhone,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Se sincroniza automáticamente en tickets PDF, reportes y catálogo web.',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final bool isDark;
  const _LiveBadge({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.3)
            : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? const Color(0xFF059669).withValues(alpha: 0.4)
              : const Color(0xFFA7F3D0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_rounded,
            size: 12,
            color: isDark
                ? const Color(0xFF34D399)
                : const Color(0xFF059669),
          ),
          const SizedBox(width: 4),
          Text(
            'En vivo',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? const Color(0xFF34D399)
                  : const Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge con el logo del negocio. Usa CachedNetworkImage si hay URL.
class BusinessLogoBadge extends StatelessWidget {
  final String logoUrl;

  const BusinessLogoBadge({super.key, required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    if (logoUrl.isEmpty) {
      return Container(
        width: 54,
        height: 54,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Image.asset('assets/logo_icon.png', fit: BoxFit.contain),
      );
    }

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Padding(
          padding: const EdgeInsets.all(8),
          child: Image.asset('assets/logo_icon.png', fit: BoxFit.contain),
        ),
      ),
    );
  }
}
