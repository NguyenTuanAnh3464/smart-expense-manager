import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_expense_manager/services/theme_service.dart';

void main() {
  test('ThemeService defaults to system theme mode', () {
    final themeService = ThemeService();

    expect(themeService.themeMode, ThemeMode.system);
    expect(themeService.isDarkMode, isFalse);
  });
}
