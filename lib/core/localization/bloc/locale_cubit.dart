import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/core/localization/bloc/locale_state.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';

@lazySingleton
class LocaleCubit extends Cubit<LocaleState> {
  static const String _prefKey = 'app_user_locale_code';

  LocaleCubit() : super(const LocaleState(Locale('es'))) {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code != null && ['es', 'en', 'pt', 'qu'].contains(code)) {
        emit(LocaleState(Locale(code)));
        LoggerService.i('Idioma recuperado de preferencias: $code', tag: 'LocaleCubit');
      }
    } catch (e) {
      LoggerService.w('Error cargando idioma de preferencias: $e', tag: 'LocaleCubit');
    }
  }

  Future<void> changeLocale(Locale newLocale) async {
    if (state.locale.languageCode == newLocale.languageCode) return;

    emit(LocaleState(newLocale));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, newLocale.languageCode);
      LoggerService.i('Idioma cambiado a: ${newLocale.languageCode}', tag: 'LocaleCubit');
    } catch (e) {
      LoggerService.e('Error guardando idioma en preferencias: $e', tag: 'LocaleCubit');
    }
  }
}
