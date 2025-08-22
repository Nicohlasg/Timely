import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../Theme/app_theme.dart';

enum RepeatRule { never, daily, weekly, everyTwoWeeks, monthly, yearly }

enum EventImportance { low, medium, high }

class CalendarEvent {
  String id;
  String userId;
  String title;
  String location;
  DateTime start;
  DateTime end;
  Color color;
  bool allDay;
  RepeatRule repeatRule;
  DateTime? repeatUntil;
  List<DateTime> exceptions;
  EventImportance importance;
  List<int> repeatWeekdays; // New: for weekly recurrences on multiple weekdays

  CalendarEvent({
    this.id = '',
    this.userId = '',
    required this.title,
    this.location = '',
    required this.start,
    required this.end,
    this.color = PRIMARY_COLOR,
    this.allDay = false,
    this.repeatRule = RepeatRule.never,
    this.repeatUntil,
    this.exceptions = const [],
    this.importance = EventImportance.medium,
    this.repeatWeekdays = const [], // NEW default
  });

  CalendarEvent copyWith({
    String? id,
    String? userId,
    String? title,
    String? location,
    DateTime? start,
    DateTime? end,
    Color? color,
    bool? allDay,
    RepeatRule? repeatRule,
    DateTime? repeatUntil,
    List<DateTime>? exceptions,
    EventImportance? importance,
    bool? clearRepeatUntil,
    List<int>? repeatWeekdays, // NEW
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      location: location ?? this.location,
      start: start ?? this.start,
      end: end ?? this.end,
      color: color ?? this.color,
      allDay: allDay ?? this.allDay,
      repeatRule: repeatRule ?? this.repeatRule,
      repeatUntil: clearRepeatUntil == true
          ? null
          : (repeatUntil ?? this.repeatUntil),
      exceptions: exceptions ?? this.exceptions,
      importance: importance ?? this.importance,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays, // NEW
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'id': id,
    'title': title,
    'location': location,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'color': color.toARGB32(),
    'allDay': allDay,
    'repeatRule': repeatRule.name,
    'repeatUntil': repeatUntil?.toIso8601String(),
    'exceptions': exceptions.map((d) => d.toIso8601String()).toList(),
    'importance': importance.name,
    'repeatWeekdays': repeatWeekdays, // NEW
  };

  static CalendarEvent fromDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;

    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else {
        throw ArgumentError('Invalid date format');
      }
    }

    final exceptionsList =
        (data['exceptions'] as List<dynamic>?)
            ?.map((value) => parseDateTime(value))
            .toList() ??
        [];

    return CalendarEvent(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? 'Untitled',
      location: data['location'] ?? '',
      start: parseDateTime(data['start']),
      end: parseDateTime(data['end']),
      color: data['color'] != null ? Color(data['color']) : PRIMARY_COLOR,
      allDay: data['allDay'] ?? false,
      repeatRule: RepeatRule.values.firstWhere(
        (e) => e.name == data['repeatRule'],
        orElse: () => RepeatRule.never,
      ),
      repeatUntil: data['repeatUntil'] != null
          ? parseDateTime(data['repeatUntil'])
          : null,
      exceptions: exceptionsList,
      importance: EventImportance.values.firstWhere(
        (e) => e.name == data['importance'],
        orElse: () => EventImportance.medium,
      ),
      repeatWeekdays: (data['repeatWeekdays'] as List<dynamic>? )
              ?.map((e) => e as int)
              .toList() ??
          const [], // NEW
    );
  }

  String get startIso => start.toIso8601String();
  String get endIso => end.toIso8601String();
}
