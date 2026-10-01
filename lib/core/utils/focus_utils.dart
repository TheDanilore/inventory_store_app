import 'package:flutter/material.dart';

/// Utilidad centralizada de protección y aislamiento de foco.
///
/// Garantiza que los atajos de teclado globales de una sola tecla (ej. N, C, R, 1, 2, 3, /, E, etc.)
/// jamás interfieran ni intercepten la escritura cuando el usuario se encuentra digitando
/// en buscadores, campos de texto, áreas de edición, formularios o diálogos.
class FocusUtils {
  FocusUtils._();

  /// Comprueba de forma infalible y multi-capa si el foco actual se encuentra
  /// sobre un campo editable (`TextField`, `TextFormField`, `EditableText`, `InputDecorator`)
  /// o sobre un [explicitFocusNode] provisto.
  static bool isInputFieldFocused([FocusNode? explicitFocusNode]) {
    // 1. Nodo explícito asignado directamente (ej. _searchFocusNode)
    if (explicitFocusNode != null && explicitFocusNode.hasFocus) {
      return true;
    }

    // 2. Foco primario del sistema en Flutter
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;

    if (explicitFocusNode != null && primaryFocus == explicitFocusNode) {
      return true;
    }

    // 3. Inspeccionar debugLabel del FocusNode primario o su padre
    final debugLabel = primaryFocus.debugLabel?.toLowerCase() ?? '';
    if (debugLabel.contains('editabletext') ||
        debugLabel.contains('textfield') ||
        debugLabel.contains('textformfield')) {
      return true;
    }
    final parentLabel = primaryFocus.parent?.debugLabel?.toLowerCase() ?? '';
    if (parentLabel.contains('editabletext') ||
        parentLabel.contains('textfield')) {
      return true;
    }

    // 4. Analizar el contexto del widget con foco
    final context = primaryFocus.context;
    if (context == null) return false;

    // 5. Widget directo
    final widget = context.widget;
    if (widget is EditableText ||
        widget is TextField ||
        widget is TextFormField) {
      return true;
    }

    // 6. Ancestros inmediatos y estados (EditableTextState / InputDecorator)
    if (context.findAncestorWidgetOfExactType<EditableText>() != null ||
        context.findAncestorWidgetOfExactType<TextField>() != null ||
        context.findAncestorWidgetOfExactType<TextFormField>() != null ||
        context.findAncestorWidgetOfExactType<InputDecorator>() != null ||
        context.findAncestorStateOfType<EditableTextState>() != null) {
      return true;
    }

    // 7. Recorrido recursivo de descendientes
    // En Flutter, `TextField` construye: Focus(child: ... EditableText(...))
    // por lo que el contexto de `primaryFocus` envuelve a `EditableText` como hijo/nieto.
    if (context is Element && _hasEditableDescendant(context, 12)) {
      return true;
    }

    // 8. Recorrido hacia arriba por ancestros
    bool isEditingAncestor = false;
    context.visitAncestorElements((element) {
      final w = element.widget;
      if (w is EditableText ||
          w is TextField ||
          w is TextFormField ||
          w is InputDecorator) {
        isEditingAncestor = true;
        return false;
      }
      return true;
    });

    return isEditingAncestor;
  }

  static bool _hasEditableDescendant(Element element, int depth) {
    if (depth <= 0) return false;
    final w = element.widget;
    if (w is EditableText || w is TextField || w is TextFormField) {
      return true;
    }
    bool found = false;
    element.visitChildElements((child) {
      if (!found && _hasEditableDescendant(child, depth - 1)) {
        found = true;
      }
    });
    return found;
  }
}
