import '../models/calendar_event.dart';

class RecurrenceService {
  /// Returns concrete occurrences of [masterEvent] within [startRange]..[endRange] (inclusive of boundaries)
  /// up to [maxOccurrences] occurrences. Each returned CalendarEvent is a copyWith start/end adjusted.
  static List<CalendarEvent> occurrencesInRange({
    required CalendarEvent masterEvent,
    required DateTime startRange,
    required DateTime endRange,
    int maxOccurrences = 1000,
  }) {
    assert(!endRange.isBefore(startRange), 'endRange must be after startRange');

    // Normalize to midnight boundaries for iteration.
    final rangeStartDay = DateTime(startRange.year, startRange.month, startRange.day);
    final rangeEndDay = DateTime(endRange.year, endRange.month, endRange.day);

    // Determine series end respecting repeatUntil.
    DateTime seriesEnd = masterEvent.repeatUntil ?? rangeEndDay;
    if (seriesEnd.isAfter(rangeEndDay)) seriesEnd = rangeEndDay;

    // If non-recurring, shortcut.
    if (masterEvent.repeatRule == RepeatRule.never) {
      if (_isWithin(masterEvent.start, startRange, endRange) ||
          _isWithin(masterEvent.end, startRange, endRange) ||
          (masterEvent.start.isBefore(startRange) && masterEvent.end.isAfter(endRange))) {
        return [masterEvent];
      }
      return [];
    }

    final occurrences = <CalendarEvent>[];
    final duration = masterEvent.end.difference(masterEvent.start);

    // Iterate day-by-day (acceptable for <= multi-year small ranges). Optimizable later.
    for (DateTime day = rangeStartDay;
        !day.isAfter(seriesEnd) && occurrences.length < maxOccurrences;
        day = day.add(const Duration(days: 1))) {
      if (day.isBefore(DateTime(masterEvent.start.year, masterEvent.start.month, masterEvent.start.day))) {
        continue; // Skip before first event start day.
      }

      if (_isException(masterEvent, day)) continue; // skip exception dates

      if (_isOccurrenceOnDay(masterEvent, day)) {
        final occStart = DateTime(day.year, day.month, day.day, masterEvent.start.hour, masterEvent.start.minute);
        final occEnd = occStart.add(duration);
        if (occEnd.isBefore(startRange) || occStart.isAfter(endRange)) continue; // outside exact range
        occurrences.add(masterEvent.copyWith(start: occStart, end: occEnd));
      }
    }

    return occurrences;
  }

  /// Returns all occurrences for the calendar day (local) specified by [day].
  static List<CalendarEvent> eventsForDay(List<CalendarEvent> masterEvents, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
    final list = <CalendarEvent>[];
    for (final e in masterEvents) {
      list.addAll(occurrencesInRange(masterEvent: e, startRange: dayStart, endRange: dayEnd, maxOccurrences: 64));
    }
    list.sort((a, b) {
      if (a.allDay && !b.allDay) return -1;
      if (!a.allDay && b.allDay) return 1;
      return a.start.compareTo(b.start);
    });
    return list;
  }

  /// Convenience: upcoming occurrences after [from] until [to] (exclusive of those starting before from).
  static List<CalendarEvent> upcomingOccurrences({
    required List<CalendarEvent> masterEvents,
    required DateTime from,
    required DateTime to,
    int perEventMax = 500,
  }) {
    final results = <CalendarEvent>[];
    for (final e in masterEvents) {
      for (final occ in occurrencesInRange(masterEvent: e, startRange: from, endRange: to, maxOccurrences: perEventMax)) {
        if (occ.start.isAfter(from)) results.add(occ);
      }
    }
    results.sort((a, b) => a.start.compareTo(b.start));
    return results;
  }

  /// Whether the master event produces an occurrence on the (midnight) [day].
  static bool _isOccurrenceOnDay(CalendarEvent event, DateTime day) {
    switch (event.repeatRule) {
      case RepeatRule.never:
        return false; // handled earlier
      case RepeatRule.daily:
        return true;
      case RepeatRule.weekly:
        if (event.repeatWeekdays.isNotEmpty) {
          return event.repeatWeekdays.contains(day.weekday);
        }
        return day.weekday == event.start.weekday;
      case RepeatRule.everyTwoWeeks:
        final startDay = DateTime(event.start.year, event.start.month, event.start.day);
        final diff = day.difference(startDay).inDays;
        if (diff < 0) return false;
        final weekdayMatch = event.repeatWeekdays.isEmpty
            ? day.weekday == event.start.weekday
            : event.repeatWeekdays.contains(day.weekday);
        return weekdayMatch && diff % 14 == 0;
      case RepeatRule.monthly:
        // Simple rule: same numeric day-of-month.
        return day.day == event.start.day;
      case RepeatRule.yearly:
        return day.month == event.start.month && day.day == event.start.day;
    }
  }

  static bool _isException(CalendarEvent event, DateTime day) {
    return event.exceptions.any((ex) => ex.year == day.year && ex.month == day.month && ex.day == day.day);
  }

  static bool _isWithin(DateTime dt, DateTime start, DateTime end) =>
      !dt.isBefore(start) && !dt.isAfter(end);
}
