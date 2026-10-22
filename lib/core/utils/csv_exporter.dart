/// Utility for exporting tabular business records into standard RFC 4180 CSV format.
class CsvExporter {
  CsvExporter._();

  /// Escapes a single cell according to RFC 4180 standards:
  /// - If the cell contains commas, quotes, or newlines, wrap in quotes.
  /// - Internal quotes are escaped as `""`.
  static String escapeCell(dynamic val) {
    if (val == null) return '';
    final str = val.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      final escaped = str.replaceAll('"', '""');
      return '"$escaped"';
    }
    return str;
  }

  /// Converts a header row and data rows into a complete RFC 4180 CSV document string.
  static String generateCsv({
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(escapeCell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(escapeCell).join(','));
    }
    return buffer.toString();
  }
}
