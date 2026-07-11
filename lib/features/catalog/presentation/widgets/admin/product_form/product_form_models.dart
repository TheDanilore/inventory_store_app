import 'dart:math';
import 'dart:typed_data';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';

/// Genera un ID único de 16 caracteres hexadecimales. Reemplaza UniqueKey() de Flutter.
String _generateId() {
  final rng = Random.secure();
  return List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Modelo inmutable de una fila de detalle clave/valor del formulario de producto.
/// Los [TextEditingController] correspondientes viven en el [StatefulWidget] que los renderiza.
class DetailModel {
  final String id;
  final String key;
  final String value;

  DetailModel({String? id, this.key = '', this.value = ''})
      : id = id ?? _generateId();

  DetailModel copyWith({String? key, String? value}) =>
      DetailModel(id: id, key: key ?? this.key, value: value ?? this.value);
}

/// Modelo inmutable de una fila de ingrediente activo del formulario de producto.
/// Los [TextEditingController] correspondientes viven en el [StatefulWidget] que los renderiza.
class IngredientRowModel {
  final String id;
  final String? ingredientId;
  final String name;
  final String concentration;
  final String unit;

  IngredientRowModel({
    String? id,
    this.ingredientId,
    this.name = '',
    this.concentration = '',
    this.unit = '',
  }) : id = id ?? _generateId();

  IngredientRowModel copyWith({
    String? ingredientId,
    bool clearIngredientId = false,
    String? name,
    String? concentration,
    String? unit,
  }) =>
      IngredientRowModel(
        id: id,
        ingredientId:
            clearIngredientId ? null : (ingredientId ?? this.ingredientId),
        name: name ?? this.name,
        concentration: concentration ?? this.concentration,
        unit: unit ?? this.unit,
      );
}

/// Modelo de un ítem de imagen en el formulario de producto.
/// Puede ser una imagen existente (persistida) o una nueva imagen local.
class FormImageItem {
  /// ID único generado localmente — sin [UniqueKey] de Flutter.
  final String id;
  final ProductImageEntity? existing;
  final Uint8List? newBytes;
  final String? newName;

  FormImageItem({String? id, this.existing, this.newBytes, this.newName})
      : id = id ?? _generateId();

  bool get isExisting => existing != null;
}
