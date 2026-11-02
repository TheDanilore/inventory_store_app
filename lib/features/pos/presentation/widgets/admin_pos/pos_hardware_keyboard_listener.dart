import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PosHardwareKeyHandler {
  final int Function() getSelectedTab;
  final ValueChanged<String> onBarcodeScanned;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onFocusSearch;
  final VoidCallback onTriggerDraft;
  final VoidCallback onOpenClientSearch;
  final VoidCallback onQuickCreateCustomer;
  final VoidCallback onToggleIngredientSearch;
  final VoidCallback onRefreshTab;
  final VoidCallback onTriggerCheckout;
  final VoidCallback onCameraScanner;
  final VoidCallback onUnfocusSearch;

  final StringBuffer _barcodeBuffer = StringBuffer();
  DateTime _lastBarcodeKeystrokeTime = DateTime.now();
  bool _isAttached = false;

  PosHardwareKeyHandler({
    required this.getSelectedTab,
    required this.onBarcodeScanned,
    required this.onTabSelected,
    required this.onFocusSearch,
    required this.onTriggerDraft,
    required this.onOpenClientSearch,
    required this.onQuickCreateCustomer,
    required this.onToggleIngredientSearch,
    required this.onRefreshTab,
    required this.onTriggerCheckout,
    required this.onCameraScanner,
    required this.onUnfocusSearch,
  });

  void attach() {
    if (!_isAttached) {
      _isAttached = true;
      HardwareKeyboard.instance.addHandler(handleKeyEvent);
    }
  }

  void detach() {
    if (_isAttached) {
      _isAttached = false;
      HardwareKeyboard.instance.removeHandler(handleKeyEvent);
      _barcodeBuffer.clear();
    }
  }

  bool _isInputFieldFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    final context = primaryFocus.context;
    if (context == null) return false;

    if (context.widget is EditableText) return true;

    bool isEditing = false;
    context.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        isEditing = true;
        return false;
      }
      return true;
    });
    return isEditing;
  }

  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    try {
      final isAlt = HardwareKeyboard.instance.isAltPressed;
      final isControl = HardwareKeyboard.instance.isControlPressed;
      final isMeta = HardwareKeyboard.instance.isMetaPressed;
      final hasModifier = isAlt || isControl || isMeta;

      // ── Detección de Pistola / Lector de Código de Barras Hardware (HID) ──
      // Las pistolas envían una ráfaga muy rápida de pulsaciones (<60ms entre teclas)
      // terminando con la tecla Enter.
      final char = event.character;
      final now = DateTime.now();
      final diffMs = now.difference(_lastBarcodeKeystrokeTime).inMilliseconds;
      _lastBarcodeKeystrokeTime = now;

      if (!hasModifier) {
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          if (_barcodeBuffer.length >= 3 && diffMs < 150) {
            final scannedCode = _barcodeBuffer.toString().trim();
            _barcodeBuffer.clear();
            if (scannedCode.isNotEmpty) {
              onBarcodeScanned(scannedCode);
              return true;
            }
          }
          _barcodeBuffer.clear();
        } else if (char != null &&
            char.isNotEmpty &&
            char.codeUnitAt(0) >= 32) {
          if (diffMs > 250) {
            _barcodeBuffer.clear();
          }
          _barcodeBuffer.write(char);
        }
      } else {
        _barcodeBuffer.clear();
      }

      // ── Regla de Aislamiento de Foco Pro Tools ───────────────────────────
      // Si el usuario presiona una tecla SIN modificador pero tiene el foco
      // en un campo de texto editable, NO interceptamos la tecla para permitir
      // la escritura normal de caracteres.
      if (!hasModifier && _isInputFieldFocused()) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          onUnfocusSearch();
          return true;
        }
        return false;
      }

      final activeTab = getSelectedTab();

      // Atajo de apertura de escáner de cámara (F3 o Alt+E o Alt+S)
      if (event.logicalKey == LogicalKeyboardKey.f3 ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.keyE) ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.keyS)) {
        if (activeTab == 0) {
          onCameraScanner();
          return true;
        }
      }

      // Tab 0: Venta POS (V, Alt+V, Alt+1, 1 numpad)
      if (event.logicalKey == LogicalKeyboardKey.keyV ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.digit1) ||
          (isControl && event.logicalKey == LogicalKeyboardKey.digit1) ||
          event.logicalKey == LogicalKeyboardKey.numpad1) {
        onTabSelected(0);
        return true;
      }

      // Tab 1: Lotes / Inventario (L, Alt+L, Alt+2, 2 numpad)
      if (event.logicalKey == LogicalKeyboardKey.keyL ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.digit2) ||
          (isControl && event.logicalKey == LogicalKeyboardKey.digit2) ||
          event.logicalKey == LogicalKeyboardKey.numpad2) {
        onTabSelected(1);
        return true;
      }

      // Tab 2: Historial de Ventas (H, Alt+H, Alt+3, 3 numpad)
      if (event.logicalKey == LogicalKeyboardKey.keyH ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.digit3) ||
          (isControl && event.logicalKey == LogicalKeyboardKey.digit3) ||
          event.logicalKey == LogicalKeyboardKey.numpad3) {
        onTabSelected(2);
        return true;
      }

      // Tab 3: Turnos de Caja (T, Alt+T, Alt+4, 4 numpad)
      if (event.logicalKey == LogicalKeyboardKey.keyT ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.digit4) ||
          (isControl && event.logicalKey == LogicalKeyboardKey.digit4) ||
          event.logicalKey == LogicalKeyboardKey.numpad4) {
        onTabSelected(3);
        return true;
      }

      // Foco en Buscador de Productos (/ o K o Alt+K o Ctrl+K)
      if (event.logicalKey == LogicalKeyboardKey.slash ||
          event.logicalKey == LogicalKeyboardKey.keyK ||
          ((isAlt || isControl || isMeta) &&
              event.logicalKey == LogicalKeyboardKey.keyK)) {
        if (activeTab == 0) {
          onFocusSearch();
          return true;
        }
      }

      // Guardar Borrador (B o Alt+B)
      if (event.logicalKey == LogicalKeyboardKey.keyB ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.keyB)) {
        if (activeTab == 0) {
          onTriggerDraft();
          return true;
        }
      }

      // Abrir Buscador de Cliente (C o Alt+C)
      if (event.logicalKey == LogicalKeyboardKey.keyC ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.keyC)) {
        if (activeTab == 0) {
          onOpenClientSearch();
          return true;
        }
      }

      // Nuevo Cliente Express (N o Alt+A o Alt+N)
      if (event.logicalKey == LogicalKeyboardKey.keyN ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.keyA) ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.keyN)) {
        if (activeTab == 0) {
          onQuickCreateCustomer();
          return true;
        }
      }

      // Alternar modo Producto vs Ingrediente Activo (I o Alt+I o Ctrl+I)
      if (event.logicalKey == LogicalKeyboardKey.keyI ||
          ((isAlt || isControl || isMeta) &&
              event.logicalKey == LogicalKeyboardKey.keyI)) {
        if (activeTab == 0) {
          onToggleIngredientSearch();
          return true;
        }
      }

      // Cobrar Inmediato en Desktop (F2 o Alt+Enter)
      if (event.logicalKey == LogicalKeyboardKey.f2 ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.enter)) {
        if (activeTab == 0) {
          onTriggerCheckout();
          return true;
        }
      }

      // Recargar datos de la pestaña activa (R o Alt+R)
      if (event.logicalKey == LogicalKeyboardKey.keyR ||
          (isAlt && event.logicalKey == LogicalKeyboardKey.keyR)) {
        onRefreshTab();
        return true;
      }
    } catch (_) {
      return false;
    }

    return false;
  }
}
