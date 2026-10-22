import 'package:flutter_test/flutter_test.dart';
import 'package:unity/core/utils/date_utils.dart';
import 'package:unity/core/utils/formatters.dart';
import 'package:unity/core/utils/validators.dart';

void main() {
  group('FactoryDateUtils Tests (Asia/Kolkata)', () {
    test('Converts UTC to Asia/Kolkata correctly (+5h 30m)', () {
      final utcTime = DateTime.utc(2026, 10, 15, 6, 0); // 06:00 UTC
      final istTime = FactoryDateUtils.toKolkata(utcTime);

      expect(istTime.hour, 11);
      expect(istTime.minute, 30);
      expect(istTime.day, 15);
    });

    test('Formats factory dates in readable standard', () {
      final utcTime = DateTime.utc(2026, 10, 15, 6, 0);
      final formatted = FactoryDateUtils.formatFactoryDate(utcTime);
      expect(formatted, '15 Oct 2026');
    });

    test('Overdue check correctly detects passed deadlines', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final futureDate = DateTime.now().add(const Duration(days: 2));

      expect(FactoryDateUtils.isOverdue(pastDate), isTrue);
      expect(FactoryDateUtils.isOverdue(futureDate), isFalse);
    });
  });

  group('FactoryFormatters Integer Base Units Tests', () {
    test('Converts KG base units with scale 1000 correctly', () {
      // 1.500 KG = 1500 base units
      expect(
        FactoryFormatters.formatBaseUnitsToDisplay(baseUnits: 1500, unitScale: 1000),
        '1.500',
      );

      // Parse 2.750 KG to 2750 base units
      expect(
        FactoryFormatters.parseDisplayToBaseUnits(displayValue: 2.75, unitScale: 1000),
        2750,
      );
    });

    test('Handles discrete PCS scale = 1 without decimals', () {
      expect(
        FactoryFormatters.formatBaseUnitsToDisplay(baseUnits: 45, unitScale: 1),
        '45',
      );
      expect(
        FactoryFormatters.parseDisplayToBaseUnits(displayValue: 45.0, unitScale: 1),
        45,
      );
    });

    test('Formats percentage ratio cleanly', () {
      expect(FactoryFormatters.formatPercentage(0.654), '65%');
      expect(FactoryFormatters.formatPercentage(1.5), '100%');
      expect(FactoryFormatters.formatPercentage(-0.2), '0%');
    });
  });

  group('AppValidators Tests', () {
    test('Validates email format strictly', () {
      expect(AppValidators.validateEmail(''), isNotNull);
      expect(AppValidators.validateEmail('not-an-email'), isNotNull);
      expect(AppValidators.validateEmail('user@factory.com'), isNull);
    });

    test('Validates password length', () {
      expect(AppValidators.validatePassword('123'), isNotNull);
      expect(AppValidators.validatePassword('secret123'), isNull);
    });

    test('Validates positive integers', () {
      expect(AppValidators.validatePositiveInteger('0', 'Quantity'), isNotNull);
      expect(AppValidators.validatePositiveInteger('-5', 'Quantity'), isNotNull);
      expect(AppValidators.validatePositiveInteger('abc', 'Quantity'), isNotNull);
      expect(AppValidators.validatePositiveInteger('50', 'Quantity'), isNull);
    });
  });
}
