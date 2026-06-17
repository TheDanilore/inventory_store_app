import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class AttributesProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _attributes = [];
  List<Map<String, dynamic>> get attributes => _attributes;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  AttributesProvider() {
    fetchAttributes();
  }

  Future<void> fetchAttributes() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _supabase
          .from('attributes')
          .select('*, attribute_values(*)')
          .order('name');

      _attributes = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error en fetchAttributes: $e');
      _attributes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveAttribute(
    BuildContext context, {
    Map<String, dynamic>? existingAttribute,
    required String name,
    required String description,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    notifyListeners();

    try {
      final payload = {
        'name': name.trim(),
        'description':
            description.trim().isNotEmpty ? description.trim() : null,
      };

      if (existingAttribute != null) {
        await _supabase
            .from('attributes')
            .update(payload)
            .eq('id', existingAttribute['id']);
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: 'Propiedad actualizada',
            type: SnackbarType.success,
          );
        }
      } else {
        await _supabase.from('attributes').insert(payload);
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: 'Propiedad creada',
            type: SnackbarType.success,
          );
        }
      }

      await fetchAttributes();
      return true;
    } catch (e) {
      debugPrint('Error saving attribute: $e');
      if (context.mounted) {
        final errStr = e.toString().toLowerCase();
        String msg = 'Error inesperado al guardar la propiedad.';
        if (errStr.contains('attributes_name_key')) {
          msg = 'Ya existe una propiedad con ese nombre.';
        } else if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
          msg = 'Sin conexión a internet.';
        }
        AppSnackbar.show(
          context,
          message: msg,
          type: SnackbarType.error,
        );
      }
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> saveAttributeValue(
    BuildContext context, {
    required String attributeId,
    required String value,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    notifyListeners();

    try {
      await _supabase.from('attribute_values').insert({
        'attribute_id': attributeId,
        'value': value.trim(),
      });

      await fetchAttributes();
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'Valor añadido',
          type: SnackbarType.success,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error adding attribute value: $e');
      if (context.mounted) {
        final errStr = e.toString().toLowerCase();
        String msg = 'Error inesperado al añadir el valor.';
        if (errStr.contains('attribute_values_attribute_id_value_key')) {
          msg = 'Este valor ya existe para la propiedad actual.';
        } else if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
          msg = 'Sin conexión a internet.';
        }
        AppSnackbar.show(
          context,
          message: msg,
          type: SnackbarType.error,
        );
      }
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> deleteAttributeValue(
    BuildContext context,
    String valueId,
    String valueName,
  ) async {
    if (_isSaving) return;

    _isSaving = true;
    notifyListeners();

    try {
      await _supabase.from('attribute_values').delete().eq('id', valueId);
      await fetchAttributes();

      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'Valor eliminado',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      debugPrint('Error deleting attribute value: $e');
      if (context.mounted) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('foreign key violation') ||
            errStr.contains('violates foreign key constraint')) {
          AppSnackbar.show(
            context,
            message:
                'No puedes borrar "$valueName" porque hay productos que usan este valor.',
            type: SnackbarType.error,
            duration: const Duration(seconds: 4),
          );
        } else {
          String msg = 'Error al eliminar el valor.';
          if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
            msg = 'Sin conexión a internet.';
          }
          AppSnackbar.show(
            context,
            message: msg,
            type: SnackbarType.error,
          );
        }
      }
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
