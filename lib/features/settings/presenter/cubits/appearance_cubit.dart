import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which theme the person chose.
///
/// Both themes existed and were good, and the product followed the operating
/// system with no way to disagree with it. Someone who reads a ledger at night
/// on a bright phone, or in daylight on a dark desktop, had no say.
class AppearanceCubit extends Cubit<ThemeMode> {
  /// Dark, not `system`. The palette was designed in the dark and that is
  /// where it works; following the system handed half the devices the theme
  /// the owner described as a scientific paper.
  AppearanceCubit() : super(ThemeMode.dark) {
    _restore();
  }

  static const _key = 'appearance.themeMode';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return;
    final mode = ThemeMode.values.where((value) => value.name == stored);
    if (mode.isNotEmpty && !isClosed) emit(mode.first);
  }

  Future<void> set(ThemeMode mode) async {
    emit(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

extension ThemeModeLabel on ThemeMode {
  String get label => switch (this) {
    ThemeMode.system => 'Sistema',
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Escuro',
  };

  IconData get icon => switch (this) {
    ThemeMode.system => Icons.brightness_auto_rounded,
    ThemeMode.light => Icons.light_mode_rounded,
    ThemeMode.dark => Icons.dark_mode_rounded,
  };

  ThemeMode get next => switch (this) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  };
}
