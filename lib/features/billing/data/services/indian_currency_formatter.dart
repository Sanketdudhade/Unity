class IndianCurrencyFormatter {
  static const List<String> _ones = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];

  static const List<String> _tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  /// Formats amount in Indian numbering system: e.g. 1234567.89 -> "12,34,567.89"
  static String format(double amount, {bool includeSymbol = true}) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final parts = absAmount.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';

    String formattedInteger;
    if (integerPart.length <= 3) {
      formattedInteger = integerPart;
    } else {
      final lastThree = integerPart.substring(integerPart.length - 3);
      final remaining = integerPart.substring(0, integerPart.length - 3);
      final regExp = RegExp(r'\B(?=(\d{2})+(?!\d))');
      final formattedRemaining = remaining.replaceAll(regExp, ',');
      formattedInteger = '$formattedRemaining,$lastThree';
    }

    final sign = isNegative ? '-' : '';
    final symbol = includeSymbol ? '₹ ' : '';
    return '$sign$symbol$formattedInteger.$decimalPart';
  }

  /// Converts a number into Indian Currency Words.
  /// Example: 39345.92 -> "INR Thirty Nine Thousand Three Hundred Forty Five and Ninety Two Paise Only"
  static String convertToWords(double amount, {String prefix = 'INR '}) {
    if (amount == 0) return '${prefix}Zero Only';

    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final rupees = absAmount.floor();
    final paise = ((absAmount - rupees) * 100).round();

    final rupeeWords = _convertNumberToWords(rupees);
    final paiseWords = paise > 0 ? _convertNumberToWords(paise) : '';

    final buffer = StringBuffer();
    if (isNegative) buffer.write('Minus ');
    buffer.write(prefix);

    if (rupees > 0) {
      buffer.write(rupeeWords);
    } else if (paise > 0) {
      buffer.write('Zero Rupees');
    }

    if (paise > 0) {
      buffer.write(' and $paiseWords Paise');
    }

    buffer.write(' Only');
    return buffer.toString().trim();
  }

  static String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';

    final crore = number ~/ 10000000;
    var remainder = number % 10000000;

    final lakh = remainder ~/ 100000;
    remainder %= 100000;

    final thousand = remainder ~/ 1000;
    remainder %= 1000;

    final hundred = remainder ~/ 100;
    remainder %= 100;

    final parts = <String>[];

    if (crore > 0) {
      parts.add('${_convertLessThanOneThousand(crore)} Crore');
    }
    if (lakh > 0) {
      parts.add('${_convertLessThanOneThousand(lakh)} Lakh');
    }
    if (thousand > 0) {
      parts.add('${_convertLessThanOneThousand(thousand)} Thousand');
    }
    if (hundred > 0) {
      parts.add('${_convertLessThanOneThousand(hundred)} Hundred');
    }
    if (remainder > 0) {
      parts.add(_convertLessThanOneThousand(remainder));
    }

    return parts.join(' ');
  }

  static String _convertLessThanOneThousand(int number) {
    if (number == 0) return '';

    if (number < 20) {
      return _ones[number];
    } else if (number < 100) {
      final ten = number ~/ 10;
      final one = number % 10;
      return '${_tens[ten]} ${_ones[one]}'.trim();
    } else {
      final hundred = number ~/ 100;
      final rest = number % 100;
      if (rest == 0) {
        return '${_ones[hundred]} Hundred';
      }
      return '${_ones[hundred]} Hundred ${_convertLessThanOneThousand(rest)}'.trim();
    }
  }
}
