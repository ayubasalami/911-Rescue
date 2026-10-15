import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/data/repositories/theme_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final repository = ThemeRepository();

  test('follows the system when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await repository.load(), ThemeMode.system);
  });

  test('reads the web-style values', () async {
    SharedPreferences.setMockInitialValues({'theme': 'dark'});
    expect(await repository.load(), ThemeMode.dark);
    SharedPreferences.setMockInitialValues({'theme': 'light'});
    expect(await repository.load(), ThemeMode.light);
  });

  test('saves a choice, and system clears it', () async {
    SharedPreferences.setMockInitialValues({});
    await repository.save(ThemeMode.dark);
    expect(await repository.load(), ThemeMode.dark);
    await repository.save(ThemeMode.system);
    expect(await repository.load(), ThemeMode.system);
  });
}
