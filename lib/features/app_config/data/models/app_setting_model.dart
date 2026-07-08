class AppSettingModel {
  final String key;
  final double value;
  final String? description;

  const AppSettingModel({
    required this.key,
    required this.value,
    this.description,
  });

  factory AppSettingModel.fromMap(Map<String, dynamic> map) {
    return AppSettingModel(
      key: map['key'] as String,
      value: (map['value'] as num).toDouble(),
      description: map['description'] as String?,
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
