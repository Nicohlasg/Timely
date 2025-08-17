import 'package:intl/intl.dart';

/// Centralized date formatting utilities
class AppDateUtils {
  static final DateFormat _monthYear = DateFormat.yMMMM();
  static final DateFormat _timeFormat = DateFormat.jm();
  static final DateFormat _dateFormat = DateFormat.MMMd();
  static final DateFormat _fullDateFormat = DateFormat.yMMMd();
  static final DateFormat _dayFormat = DateFormat.E();
  static final DateFormat _hourMinuteFormat = DateFormat.Hm();
  
  /// Formats a DateTime to "January 2024" format
  static String formatMonthYear(DateTime date) {
    return _monthYear.format(date);
  }
  
  /// Formats a DateTime to "3:30 PM" format
  static String formatTime(DateTime date) {
    return _timeFormat.format(date);
  }
  
  /// Formats a DateTime to "Jan 15" format
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }
  
  /// Formats a DateTime to "Jan 15, 2024" format
  static String formatFullDate(DateTime date) {
    return _fullDateFormat.format(date);
  }
  
  /// Formats a DateTime to "Mon" format
  static String formatDay(DateTime date) {
    return _dayFormat.format(date);
  }
  
  /// Formats a DateTime to "15:30" format
  static String formatHourMinute(DateTime date) {
    return _hourMinuteFormat.format(date);
  }
  
  /// Formats a time range as "3:30 PM - 5:00 PM"
  static String formatTimeRange(DateTime start, DateTime end) {
    return "${formatTime(start)} - ${formatTime(end)}";
  }
  
  /// Formats a duration as "2 HOURS" or "30 MINS"
  static String formatDuration(Duration duration) {
    if (duration.inHours >= 1) {
      return "${duration.inHours} HOUR${duration.inHours == 1 ? '' : 'S'}";
    } else {
      return "${duration.inMinutes} MIN${duration.inMinutes == 1 ? '' : 'S'}";
    }
  }
  
  /// Checks if two dates are on the same day
  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  /// Returns a human-readable relative date string
  static String getRelativeDateText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final difference = targetDate.difference(today).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';
    if (difference > 1 && difference <= 7) return 'In $difference days';
    if (difference < -1 && difference >= -7) return '${-difference} days ago';
    
    return formatFullDate(date);
  }
  
  /// Gets the first day of the week containing the given date
  static DateTime getFirstDayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }
  
  /// Gets the last day of the week containing the given date
  static DateTime getLastDayOfWeek(DateTime date) {
    return getFirstDayOfWeek(date).add(const Duration(days: 6));
  }
  
  /// Creates a DateTime with time set to start of day (00:00:00)
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
  
  /// Creates a DateTime with time set to end of day (23:59:59)
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }
}