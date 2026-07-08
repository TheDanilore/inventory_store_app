import 'package:inventory_store_app/features/app_config/domain/entities/app_setting_entity.dart';

class AppSettingModel extends AppSettingEntity {

  const AppSettingModel({
    required super.key,
    required super.value,
    super.description,
  });

  factory AppSettingModel.fromMap(Map<String, dynamic> map) {
    return AppSettingModel(
      key: map['key'] as String,
      value: (map['value'] as num).toDouble(),
      description: map['description'] as String?,
    );
  }

  factory AppSettingModel.fromEntity(AppSettingEntity entity) {
    return AppSettingModel(
      key: entity.key,
      value: entity.value,
      description: entity.description,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'key': key,
      'value': value,
    };
    if (description != null && description!.isNotEmpty) {
      map['description'] = description;
    }
    return map;
  }
}
