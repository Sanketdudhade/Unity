/// Manufacturing date and timezone formatting utilities.
/// Primary display timezone: Asia/Kolkata (IST = UTC + 5 hours 30 minutes).
class FactoryDateUtils {
  FactoryDateUtils._();

  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  /// Converts any UTC or local DateTime to Asia/Kolkata (IST).
  static DateTime toKolkata(DateTime dateTime) {
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
    return utc.add(istOffset);
  }

  /// Formats date for factory tags & deadlines: "15 Oct 2026".
  static String formatFactoryDate(DateTime? dateTime) {
    if (dateTime == null) return '—';
    final ist = toKolkata(dateTime);
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${ist.day.toString().padLeft(2, '0')} ${months[ist.month - 1]} ${ist.year}';
  }

  /// Formats date and time: "15 Oct 2026, 02:30 PM".
  static String formatFactoryDateTime(DateTime? dateTime) {
    if (dateTime == null) return '—';
    final ist = toKolkata(dateTime);
    final dateStr = formatFactoryDate(dateTime);

    final hour12 = ist.hour == 0 ? 12 : (ist.hour > 12 ? ist.hour - 12 : ist.hour);
    final period = ist.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = ist.minute.toString().padLeft(2, '0');

    return '$dateStr, ${hour12.toString().padLeft(2, '0')}:$minuteStr $period';
  }

  /// Formats time only: "02:30 PM".
  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '—';
    final ist = toKolkata(dateTime);
    final hour12 = ist.hour == 0 ? 12 : (ist.hour > 12 ? ist.hour - 12 : ist.hour);
    final period = ist.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = ist.minute.toString().padLeft(2, '0');

    return '${hour12.toString().padLeft(2, '0')}:$minuteStr $period';
  }

  /// Returns true if the deadline has passed.
  static bool isOverdue(DateTime? dueAt) {
    if (dueAt == null) return false;
    return DateTime.now().toUtc().isAfter(dueAt.toUtc());
  }

  /// Returns true if the deadline falls on today's factory shift (in Asia/Kolkata).
  static bool isDueToday(DateTime? dueAt) {
    if (dueAt == null) return false;
    final nowIst = toKolkata(DateTime.now());
    final dueIst = toKolkata(dueAt);

    return nowIst.year == dueIst.year &&
        nowIst.month == dueIst.month &&
        nowIst.day == dueIst.day;
  }
}
