import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Helper inteligente para identificación, recursos gráficos y renderizado
/// de marcas comerciales (Bayer, Molinos & Cía, Genfar, MK, Alkofarma, etc.).
class BrandLogoHelper {
  BrandLogoHelper._();

  /// Mapeo de nombres o fragmentos de marca a sus recursos locales de logo oficial.
  static const Map<String, String> _presetAssets = {
    'BAYER': 'assets/icons/brands/bayer.png',
    'MOLINOS': 'assets/icons/brands/molinos.png',
    'MOLINOS & CIA': 'assets/icons/brands/molinos.png',
    'MOLINOS & CÍA': 'assets/icons/brands/molinos.png',
    'GENFAR': 'assets/icons/brands/genfar.png',
    'MK': 'assets/icons/brands/mk.png',
    'TECNOQUIMICAS': 'assets/icons/brands/mk.png',
    'ALKOFARMA': 'assets/icons/brands/alkofarma.svg',
  };

  /// Paletas de color representativas de cada marca.
  static const Map<String, Color> _brandColors = {
    'BAYER': Color(0xFF003087),
    'MOLINOS': Color(0xFF00843D),
    'MOLINOS & CIA': Color(0xFF00843D),
    'GENFAR': Color(0xFFE20613),
    'MK': Color(0xFF1B365D),
    'ALKOFARMA': Color(0xFF00A3CD),
    'AGUA': Color(0xFF0284C7),
  };

  /// Obtiene la ruta del asset local para una marca, si existe.
  static String? getPresetAsset(String brandName) {
    final clean = brandName.trim().toUpperCase();
    for (final entry in _presetAssets.entries) {
      if (clean == entry.key || clean.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Obtiene el color distintivo de la marca para fondos o acentos.
  static Color getBrandColor(String brandName) {
    final clean = brandName.trim().toUpperCase();
    for (final entry in _brandColors.entries) {
      if (clean == entry.key || clean.contains(entry.key)) {
        return entry.value;
      }
    }
    return AppColors.primary;
  }

  /// Renderiza el logo de la marca de forma adaptativa:
  /// 1. Si viene [logoUrl] (HTTP), lo carga con CachedNetworkImage y caché.
  /// 2. Si no hay [logoUrl] o falla, busca el logo oficial en assets locales.
  /// 3. Si no tiene asset oficial, renderiza un avatar estilizado con icono/inicial
  ///    acorde al tipo de marca (ej. Agua = gota, otros = inicial moderna con gradiente).
  static Widget buildBrandLogo({
    required String name,
    String? logoUrl,
    double size = 48,
    double borderRadius = 12,
    bool showBorder = true,
    BoxFit fit = BoxFit.contain,
  }) {
    final hasRemoteUrl = logoUrl != null && logoUrl.trim().startsWith('http');
    final presetAsset = getPresetAsset(name);

    Widget fallbackWidget = _buildFallback(
      name: name,
      size: size,
      presetAsset: presetAsset,
      fit: fit,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border:
            showBorder ? Border.all(color: AppColors.border, width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child:
          hasRemoteUrl
              ? CachedNetworkImage(
                imageUrl: logoUrl.trim(),
                fit: fit,
                placeholder:
                    (ctx, url) => Center(
                      child: SizedBox(
                        width: size * 0.35,
                        height: size * 0.35,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                errorWidget: (ctx, url, err) => fallbackWidget,
              )
              : fallbackWidget,
    );
  }

  static Widget _buildFallback({
    required String name,
    required double size,
    String? presetAsset,
    BoxFit fit = BoxFit.contain,
  }) {
    if (presetAsset != null) {
      final isSvg = presetAsset.toLowerCase().endsWith('.svg');
      return Padding(
        padding: EdgeInsets.all(size * 0.12),
        child:
            isSvg
                ? SvgPicture.asset(
                  presetAsset,
                  fit: fit,
                  placeholderBuilder: (_) => _buildStylizedAvatar(name, size),
                )
                : Image.asset(
                  presetAsset,
                  fit: fit,
                  errorBuilder:
                      (ctx, err, stack) => _buildStylizedAvatar(name, size),
                ),
      );
    }

    return _buildStylizedAvatar(name, size);
  }

  /// Construye un avatar refinado para marcas sin logo en assets (ej. "Agua" o marcas personalizadas).
  static Widget _buildStylizedAvatar(String name, double size) {
    final clean = name.trim().toUpperCase();

    // Caso especial: Bebidas / Agua
    if (clean.contains('AGUA') ||
        clean.contains('BEBIDA') ||
        clean.contains('WATER')) {
      return Container(
        color: const Color(0xFFE0F2FE),
        child: Center(
          child: Icon(
            Icons.water_drop_rounded,
            color: const Color(0xFF0284C7),
            size: size * 0.55,
          ),
        ),
      );
    }

    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'M';
    final brandColor = getBrandColor(name);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brandColor.withValues(alpha: 0.12),
            brandColor.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
            color: brandColor,
          ),
        ),
      ),
    );
  }
}
