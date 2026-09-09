import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Modal de confirmación destructiva camaleónico (Vercel / Supabase Style).
///
/// - En **Desktop / Tablet (>= 720px)**: Diálogo flotante centrado con alta densidad,
///   autofocus en el campo de texto, y atajos de teclado (`Escape` para cerrar, `Enter` para confirmar).
/// - En **Móvil (< 720px)**: Modal BottomSheet estilo Apple HIG con esquinas suavizadas,
///   área del pulgar optimizada y retroalimentación háptica al validar.
class AdaptiveDestructiveDialog extends StatefulWidget {
  final String title;
  final String itemName;
  final String description;
  final String matchText;
  final String confirmButtonText;
  final Future<bool> Function()? onConfirmAsync;

  const AdaptiveDestructiveDialog({
    super.key,
    required this.title,
    required this.itemName,
    required this.description,
    required this.matchText,
    this.confirmButtonText = 'Eliminar',
    this.onConfirmAsync,
  });

  /// Muestra el modal destructivo adaptativo según el dispositivo actual.
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String itemName,
    required String description,
    String? matchText,
    String confirmButtonText = 'Eliminar',
    Future<bool> Function()? onConfirmAsync,
  }) {
    final effectiveMatchText = matchText ?? itemName;
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    if (isDesktop) {
      return showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder:
            (ctx) => AdaptiveDestructiveDialog(
              title: title,
              itemName: itemName,
              description: description,
              matchText: effectiveMatchText,
              confirmButtonText: confirmButtonText,
              onConfirmAsync: onConfirmAsync,
            ),
      );
    } else {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (ctx) => AdaptiveDestructiveDialog(
              title: title,
              itemName: itemName,
              description: description,
              matchText: effectiveMatchText,
              confirmButtonText: confirmButtonText,
              onConfirmAsync: onConfirmAsync,
            ),
      );
    }
  }

  @override
  State<AdaptiveDestructiveDialog> createState() =>
      _AdaptiveDestructiveDialogState();
}

class _AdaptiveDestructiveDialogState extends State<AdaptiveDestructiveDialog> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isMatching = false;
  bool _isLoading = false;
  bool _hasTriggeredHaptic = false;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final cleanInput = _textCtrl.text.trim().toLowerCase();
    final cleanTarget = widget.matchText.trim().toLowerCase();
    final matches = cleanInput == cleanTarget;

    if (matches != _isMatching) {
      setState(() {
        _isMatching = matches;
      });

      if (matches && !_hasTriggeredHaptic) {
        _hasTriggeredHaptic = true;
        HapticFeedback.mediumImpact();
      } else if (!matches) {
        _hasTriggeredHaptic = false;
      }
    }
  }

  Future<void> _handleConfirm() async {
    if (!_isMatching || _isLoading) return;

    if (widget.onConfirmAsync != null) {
      setState(() => _isLoading = true);
      try {
        final success = await widget.onConfirmAsync!();
        if (mounted) {
          Navigator.of(context).pop(success);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      Navigator.of(context).pop(true);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (!_isLoading) {
          Navigator.of(context).pop(false);
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_isMatching && !_isLoading) {
          _handleConfirm();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    final content = Focus(
      onKeyEvent: _handleKeyEvent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle superior para móvil (Apple HIG)
          if (!isDesktop) ...[
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],

          // Cabecera: Título y botón cerrar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textSecondary,
                  tooltip: 'Cerrar (Esc)',
                  splashRadius: 18,
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Descripción del impacto
                Text(
                  widget.description,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),

                // Prompt de verificación tipo Vercel/Supabase
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      const TextSpan(text: 'Para confirmar, escribe '),
                      TextSpan(
                        text: '"${widget.matchText}"',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const TextSpan(text: ' abajo:'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Campo de texto con validación y autofocus
                TextField(
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  autofocus: true,
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleConfirm(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.matchText,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor:
                        _isMatching
                            ? const Color(0xFFFFF1F2)
                            : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      borderSide: BorderSide(
                        color:
                            _isMatching
                                ? AppColors.error
                                : const Color(0xFFE2E8F0),
                        width: _isMatching ? 1.5 : 1.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      borderSide: BorderSide(
                        color:
                            _isMatching
                                ? AppColors.error
                                : const Color(0xFFCBD5E1),
                        width: _isMatching ? 1.5 : 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      borderSide: BorderSide(
                        color:
                            _isMatching
                                ? AppColors.error
                                : AppColors.primary,
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Warning Callout Badge (WCAG AAA contrast: > 7.5:1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2), // Rose 50
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(
                      color: const Color(0xFFFECDD3), // Rose 200
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: Color(0xFFE11D48), // Rose 600
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Eliminar "${widget.itemName}" no se puede deshacer.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFBE123C), // Rose 700
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Botones de Acción (Cancelar vs Eliminar)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusSm,
                          ),
                        ),
                      ),
                      onPressed:
                          _isLoading
                              ? null
                              : () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    MouseRegion(
                      cursor:
                          _isMatching && !_isLoading
                              ? SystemMouseCursors.click
                              : SystemMouseCursors.forbidden,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isMatching
                                    ? AppColors.error
                                    : AppColors.error.withValues(alpha: 0.35),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.error.withValues(
                              alpha: 0.35,
                            ),
                            disabledForegroundColor: Colors.white.withValues(
                              alpha: 0.7,
                            ),
                            elevation: _isMatching ? 1 : 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusSm,
                              ),
                            ),
                          ),
                          onPressed:
                              (_isMatching && !_isLoading)
                                  ? _handleConfirm
                                  : null,
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Text(
                                    widget.confirmButtonText,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radius),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: content,
        ),
      );
    } else {
      return Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: content,
            ),
          ),
        ),
      );
    }
  }
}
