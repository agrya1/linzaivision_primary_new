import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linzaivision_primary/utils/bloc_feature_toggles.dart';

void main() {
  group('BlocFeatureToggles - appBarBlocDriven', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('default is false after loadSettings', () async {
      final toggles = BlocFeatureToggles();
      await toggles.loadSettings();
      expect(toggles.appBarBlocDriven, isFalse);
    });

    test('can be enabled and persisted', () async {
      final toggles = BlocFeatureToggles();
      await toggles.loadSettings();
      await toggles.setFeatureEnabled('appBarBlocDriven', true);

      // Simulate new app start
      final toggles2 = BlocFeatureToggles();
      await toggles2.loadSettings();
      expect(toggles2.appBarBlocDriven, isTrue);
    });
  });
}

