import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/services/mushroom/season_config.dart';

void main() {
  group('SeasonConfig', () {
    test('seasonMultiplier: Sept 15 (full season) -> 1.0', () {
      final date = DateTime.utc(2026, 9, 15);
      final multiplier = SeasonConfig.seasonMultiplier(date);
      expect(multiplier, equals(SeasonConfig.fullSeasonMultiplier));
    });

    test('seasonMultiplier: Oct 15 (full season) -> 1.0', () {
      final date = DateTime.utc(2026, 10, 15);
      final multiplier = SeasonConfig.seasonMultiplier(date);
      expect(multiplier, equals(SeasonConfig.fullSeasonMultiplier));
    });

    test('seasonMultiplier: Aug 10 (ramp entry) -> between 0.15 and 1.0', () {
      final date = DateTime.utc(2026, 8, 10);
      final multiplier = SeasonConfig.seasonMultiplier(date);
      expect(multiplier, greaterThan(SeasonConfig.outOfSeasonMultiplier));
      expect(multiplier, lessThan(SeasonConfig.fullSeasonMultiplier));
    });

    test('seasonMultiplier: Aug 5 (before ramp) -> 0.15', () {
      final date = DateTime.utc(2026, 8, 5);
      final multiplier = SeasonConfig.seasonMultiplier(date);
      expect(multiplier, equals(SeasonConfig.outOfSeasonMultiplier));
    });

    test('seasonMultiplier: Dec 5 (ramp exit) -> between 0.15 and 1.0', () {
      final date = DateTime.utc(2026, 12, 5);
      final multiplier = SeasonConfig.seasonMultiplier(date);
      expect(multiplier, greaterThan(SeasonConfig.outOfSeasonMultiplier));
      expect(multiplier, lessThan(SeasonConfig.fullSeasonMultiplier));
    });

    test('seasonMultiplier: Jan 1 (out of season) -> 0.15', () {
      final date = DateTime.utc(2026, 1, 1);
      final multiplier = SeasonConfig.seasonMultiplier(date);
      expect(multiplier, equals(SeasonConfig.outOfSeasonMultiplier));
    });
  });
}
