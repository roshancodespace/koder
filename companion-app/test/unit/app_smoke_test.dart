import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:companion_app/core/constants.dart';
import 'package:companion_app/main.dart';

void main() {
  group('App Smoke & Configuration Tests', () {
    test('Riverpod ProviderContainer initializes cleanly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container, isNotNull);
    });

    test('Theme color seed is indigo and valid', () {
      expect(CompanionApp.seedColor, equals(Colors.indigo));

      final lightTheme = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: CompanionApp.seedColor,
          brightness: Brightness.light,
        ),
      );

      final darkTheme = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: CompanionApp.seedColor,
          brightness: Brightness.dark,
        ),
      );

      expect(lightTheme.useMaterial3, isTrue);
      expect(darkTheme.useMaterial3, isTrue);
      expect(lightTheme.colorScheme.brightness, equals(Brightness.light));
      expect(darkTheme.colorScheme.brightness, equals(Brightness.dark));
    });

    test('Protocol constants define valid defaults', () {
      expect(AppConstants.appName, equals('VS Code Companion'));
      expect(AppConstants.defaultWsHost, equals('127.0.0.1'));
      expect(AppConstants.defaultWsPort, equals(38848));
      expect(AppConstants.protocolVersion, equals('1.0.0'));
      expect(AppConstants.minAndroidSdk, equals(28));
    });
  });
}
