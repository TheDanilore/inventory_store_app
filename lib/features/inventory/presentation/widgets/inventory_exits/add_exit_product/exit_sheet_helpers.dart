import 'dart:async';
import 'dart:developer' as developer;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Identificador estable de un lote (para reservas y comparaciones de stock).
String exitBatchKey(Map<String, dynamic>? batch) {
  if (batch == null) return '';
  return (batch['id'] ?? batch['batch_number'] ?? '').toString();
}

String formatExitDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Input decoration común para el modal de añadir producto.
InputDecoration exitInputDecoration({
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textMuted),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.primary, 1.5),
  );
}

class ExitFieldLabel extends StatelessWidget {
  final String text;
  const ExitFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );
}

class ExitLoadingBar extends StatelessWidget {
  const ExitLoadingBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      child: LinearProgressIndicator(minHeight: 3, color: AppColors.primary),
    );
  }
}

class ExitMutedHint extends StatelessWidget {
  final String text;
  const ExitMutedHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ExitSearchHint extends StatelessWidget {
  const ExitSearchHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.outbox_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Escribe el nombre del producto',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ExitProductThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const ExitProductThumbnail({super.key, this.imageUrl, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child:
            imageUrl != null && imageUrl!.trim().isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: imageUrl!,
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
                      (context, url, error) => const Icon(
                        Icons.image_not_supported_rounded,
                        color: AppColors.textMuted,
                      ),
                )
                : const Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.textMuted,
                  size: 28,
                ),
      ),
    );
  }
}

class ExitStockInfo extends StatelessWidget {
  final String formattedAvailable;
  const ExitStockInfo({super.key, required this.formattedAvailable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_rounded,
            size: 18,
            color: AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Stock disponible: $formattedAvailable',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExitNoStockBox extends StatelessWidget {
  final String message;
  const ExitNoStockBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.remove_shopping_cart_outlined,
            size: 20,
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExitAddedBanner extends StatelessWidget {
  final String name;
  const ExitAddedBanner({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$name agregado a la lista',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExitInlineError extends StatelessWidget {
  final String message;
  const ExitInlineError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExitDebouncer {
  final int milliseconds;
  Timer? _timer;
  Completer? _completer;
  dynamic _fallback;

  ExitDebouncer({required this.milliseconds});

  Future<T> run<T>(Future<T> Function() action, T fallbackValue) {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete(_fallback);
      }
    }

    final completer = Completer<T>();
    _completer = completer;
    _fallback = fallbackValue;

    _timer = Timer(Duration(milliseconds: milliseconds), () async {
      try {
        final result = await action();
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        developer.log('Debouncer error', error: e, stackTrace: st);
        if (!completer.isCompleted) completer.complete(fallbackValue);
      }
    });

    return completer.future;
  }

  void dispose() {
    _timer?.cancel();
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(_fallback);
    }
  }
}
