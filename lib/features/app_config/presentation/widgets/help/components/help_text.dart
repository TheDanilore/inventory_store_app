import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';

/// Scope reactivo para inyectar tokens de búsqueda y tokens de tema a todos los hijos.
class HelpHighlightScope extends InheritedWidget {
  final List<String> searchTokens;
  final HelpThemeTokens tokens;

  const HelpHighlightScope({
    super.key,
    required this.searchTokens,
    required this.tokens,
    required super.child,
  });

  static HelpHighlightScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HelpHighlightScope>();

  static HelpHighlightScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No HelpHighlightScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(HelpHighlightScope oldWidget) =>
      !listEquals(searchTokens, oldWidget.searchTokens) ||
      tokens.isDark != oldWidget.tokens.isDark;
}

/// Widget de texto inteligente que resalta automáticamente las palabras que coinciden
/// con los tokens de búsqueda activos en [HelpHighlightScope].
///
/// Optimizado con memoización acotada y normalización O(N) sin regex ni bucles de replaceAll
/// para reducir la presión en el Garbage Collector en dispositivos de gama baja.
class HelpText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const HelpText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  static final Map<String, String> _normalizeCache = <String, String>{};

  /// Normaliza una cadena removiendo tildes y diéresis de forma O(N).
  /// Almacena en caché estática acotada (máx 512 cadenas) para acceso O(1).
  static String normalize(String s) {
    if (s.isEmpty) return s;
    final cached = _normalizeCache[s];
    if (cached != null) return cached;

    final buffer = StringBuffer();
    final lower = s.toLowerCase();
    for (var i = 0; i < lower.length; i++) {
      final code = lower.codeUnitAt(i);
      switch (code) {
        case 0xE1: // á
        case 0xE0: // à
        case 0xE4: // ä
        case 0xE2: // â
          buffer.write('a');
        case 0xE9: // é
        case 0xE8: // è
        case 0xEB: // ë
        case 0xEA: // ê
          buffer.write('e');
        case 0xED: // í
        case 0xEC: // ì
        case 0xEF: // ï
        case 0xEE: // î
          buffer.write('i');
        case 0xF3: // ó
        case 0xF2: // ò
        case 0xF6: // ö
        case 0xF4: // ô
          buffer.write('o');
        case 0xFA: // ú
        case 0xF9: // ù
        case 0xFC: // ü
        case 0xFB: // û
          buffer.write('u');
        case 0xF1: // ñ
          buffer.write('n');
        default:
          buffer.writeCharCode(code);
      }
    }
    final result = buffer.toString();
    if (_normalizeCache.length < 512) {
      _normalizeCache[s] = result;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final scope = HelpHighlightScope.maybeOf(context);
    final tokens = scope?.searchTokens ?? const [];
    if (tokens.isEmpty) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final t = scope!.tokens;
    final baseStyle = style ?? TextStyle(fontSize: 13, color: t.body);
    final normalizedText = normalize(text);
    final spans = <TextSpan>[];
    var index = 0;

    while (index < text.length) {
      int? nextMatchIndex;
      String? matchedToken;
      for (final token in tokens) {
        final matchIndex = normalizedText.indexOf(token, index);
        if (matchIndex == -1) continue;
        if (nextMatchIndex == null || matchIndex < nextMatchIndex) {
          nextMatchIndex = matchIndex;
          matchedToken = token;
        } else if (matchIndex == nextMatchIndex && matchedToken != null) {
          if (token.length > matchedToken.length) {
            matchedToken = token;
          }
        }
      }
      if (nextMatchIndex == null || matchedToken == null) {
        spans.add(TextSpan(text: text.substring(index), style: baseStyle));
        break;
      }
      if (nextMatchIndex > index) {
        spans.add(
          TextSpan(
            text: text.substring(index, nextMatchIndex),
            style: baseStyle,
          ),
        );
        index = nextMatchIndex;
        continue;
      }
      final matchLength = matchedToken.length;
      if (index + matchLength <= text.length) {
        final matchText = text.substring(index, index + matchLength);
        spans.add(
          TextSpan(
            text: matchText,
            style: baseStyle.copyWith(
              backgroundColor: t.accent.withValues(
                alpha: t.isDark ? 0.22 : 0.16,
              ),
              color: t.title,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        index += matchLength;
      } else {
        spans.add(TextSpan(text: text.substring(index), style: baseStyle));
        break;
      }
    }

    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(children: spans),
    );
  }
}
