import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class LocaleState extends Equatable {
  final Locale locale;

  const LocaleState(this.locale);

  String get languageName {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'pt':
        return 'Português';
      case 'qu':
        return 'Runasimi (Quechua)';
      case 'es':
      default:
        return 'Español';
    }
  }

  String get flagEmoji {
    switch (locale.languageCode) {
      case 'en':
        return '🇺🇸';
      case 'pt':
        return '🇧🇷';
      case 'qu':
        return '🇵🇪';
      case 'es':
      default:
        return '🇪🇸';
    }
  }

  @override
  List<Object?> get props => [locale];
}
