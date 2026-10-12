import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';

@lazySingleton
class ThemeCubit extends Cubit<ThemeMode> {
  static const String _prefKey = 'app_user_theme_mode';

  ThemeCubit() : super(ThemeMode.light) {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_prefKey);
      if (modeStr != null) {
        switch (modeStr) {
          case 'dark':
            emit(ThemeMode.dark);
            break;
          case 'light':
            emit(ThemeMode.light);
            break;
          case 'system':
            emit(ThemeMode.system);
            break;
        }
        LoggerService.i(
          'Tema recuperado de preferencias: $modeStr',
          tag: 'ThemeCubit',
        );
      }
    } catch (e) {
      LoggerService.w(
        'Error cargando tema de preferencias: $e',
        tag: 'ThemeCubit',
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;

    emit(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr =
          mode == ThemeMode.dark
              ? 'dark'
              : mode == ThemeMode.light
              ? 'light'
              : 'system';
      await prefs.setString(_prefKey, modeStr);
      LoggerService.i(
        'Tema guardado en preferencias: $modeStr',
        tag: 'ThemeCubit',
      );
    } catch (e) {
      LoggerService.e(
        'Error guardando tema en preferencias: $e',
        tag: 'ThemeCubit',
      );
    }
  }

  Future<void> toggleTheme() async {
    final nextMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(nextMode);
  }

  bool get isDarkMode => state == ThemeMode.dark;
}
