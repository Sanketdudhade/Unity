/// Industrial unit converters and presentation formatters.
class FactoryFormatters {
  FactoryFormatters._();

  /// Converts raw integer base units to formatted decimal string using [unitScale].
  /// Example: baseUnits = 1500, unitScale = 1000 -> "1.500"
  static String formatBaseUnitsToDisplay({
    required int baseUnits,
    required int unitScale,
  }) {
    if (unitScale <= 1) {
      return baseUnits.toString();
    }
    final val = baseUnits / unitScale;
    if (unitScale == 1000) {
      return val.toStringAsFixed(3);
    } else if (unitScale == 100) {
      return val.toStringAsFixed(2);
    }
    return val.toStringAsFixed(1);
  }

  /// Converts human decimal input (e.g. 1.500) into integer base units using [unitScale].
  /// Example: displayValue = 1.5, unitScale = 1000 -> 1500
  static int parseDisplayToBaseUnits({
    required double displayValue,
    required int unitScale,
  }) {
    if (unitScale <= 1) {
      return displayValue.round();
    }
    return (displayValue * unitScale).round();
  }

  /// Formats completion percentage: 0.754 -> "75.4%"
  static String formatPercentage(double ratio) {
    final clamped = ratio.clamp(0.0, 1.0);
    return '${(clamped * 100).toStringAsFixed(0)}%';
  }
}
