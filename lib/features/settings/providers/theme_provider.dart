import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode { light, dark, system, snoopy }

final themeModeProvider = StateProvider<AppThemeMode>((ref) {
  return AppThemeMode.system;
});