import 'package:equatable/equatable.dart';

class AppSettingEntity extends Equatable {
  final String key;
  final double value;
  final String? description;

  const AppSettingEntity({
    required this.key,
    required this.value,
    this.description,
  });

  @override
  List<Object?> get props => [key, value, description];
}
