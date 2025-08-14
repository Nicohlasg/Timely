import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/calendar_event.dart';
import '../services/firebase_calendar_service.dart';

class CalendarState extends ChangeNotifier {
  final FirebaseCalendarService _service = FirebaseCalendarService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CalendarEvent> _events = [];
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _authSubscription;
  bool _isLoading = true;

  CalendarEvent? _lastDeletedEvent;
  CalendarEvent? _lastUpdatedEventOriginalState;
  Timer? _undoTimer;

  List<CalendarEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get currentUserId => _auth.currentUser?.uid;
  CalendarEvent? get lastDeletedEvent => _lastDeletedEvent;

  CalendarState() {
    _authSubscription = _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _listenToEvents();
      } else {
        _cancelEventsSubscription();
        _events = [];
        _isLoading = true;
        notifyListeners();
      }
    });
  }

  void _listenToEvents() {
    _cancelEventsSubscription();

    _isLoading = true;
    notifyListeners();

    _eventsSubscription = _service.getEventsStream().listen(
      (loadedEvents) {
        _events = loadedEvents;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        print('Error loading events: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _cancelEventsSubscription() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
  }

  void _startUndoTimer(Function onConfirm) {
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 7), () {
      onConfirm();
      _lastDeletedEvent = null;
      _lastUpdatedEventOriginalState = null;
      notifyListeners();
    });
  }

  Future<void> addEvent(CalendarEvent event) async {
    if (currentUserId == null) {
      throw Exception('Must be logged in to add events');
    }

    _events.add(event);
    _events.sort((a, b) => a.start.compareTo(b.start));
    notifyListeners();

    try {
      await _service.addEvent(event);
    } catch (e) {
      print('Error adding event: $e');
      _events.remove(event);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateEvent(CalendarEvent event) async {
    if (currentUserId == null || event.userId != currentUserId) {
      throw Exception('Cannot update an event that belongs to another user');
    }

    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      _events[index] = event;
      notifyListeners();
    }

    try {
      await _service.updateEvent(event);
    } catch (e) {
      _listenToEvents();
      print('Error updating event: $e');
      rethrow;
    }
  }

  Future<void> updateSingleOccurrence({
    required CalendarEvent masterEvent,
    required DateTime occurrenceDate,
    required CalendarEvent updatedEvent,
  }) async {
    if (currentUserId == null || masterEvent.userId != currentUserId) return;

    _events.add(updatedEvent);

    final masterEventIndex = _events.indexWhere((e) => e.id == masterEvent.id);
    CalendarEvent? masterWithException;
    if (masterEventIndex != -1) {
      final normalizedDate = DateTime.utc(
        occurrenceDate.year,
        occurrenceDate.month,
        occurrenceDate.day,
      );
      masterWithException = masterEvent.copyWith(
        exceptions: [...masterEvent.exceptions, normalizedDate],
      );
      _events[masterEventIndex] = masterWithException;
    }
    _events.sort((a, b) => a.start.compareTo(b.start));
    notifyListeners();

    try {
      // Use the new atomic service method
      if (masterWithException != null) {
        await _service.createExceptionForRecurringEvent(masterWithException, updatedEvent);
      }
    } catch (e) {
      print('Error updating single occurrence: $e');
      _listenToEvents(); // Revert optimistic update on error
    }
  }

  Future<void> moveThisAndFollowingEvents({
    required CalendarEvent masterEvent,
    required DateTime occurrenceDate,
    required DateTime newStartDate,
  }) async {
    if (currentUserId == null || masterEvent.userId != currentUserId) return;

    bool isSameDate(DateTime? d1, DateTime? d2) {
      if (d1 == null || d2 == null) return false;
      return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
    }

    // If this is the last event in the series, just move it as a single event.
    if (masterEvent.repeatUntil != null && isSameDate(occurrenceDate, masterEvent.repeatUntil)) {
      final newSingleEvent = masterEvent.copyWith(
        id: '',
        start: newStartDate,
        end: newStartDate.add(masterEvent.end.difference(masterEvent.start)),
        repeatRule: RepeatRule.never,
        repeatUntil: null,
        clearRepeatUntil: true,
        exceptions: [],
        userId: currentUserId,
      );
      await updateSingleOccurrence(
        masterEvent: masterEvent,
        occurrenceDate: occurrenceDate,
        updatedEvent: newSingleEvent,
      );
      return;
    }

    final oldMasterEventUpdated = masterEvent.copyWith(
      repeatUntil: occurrenceDate.subtract(const Duration(days: 1)),
    );

    final timeDifference = newStartDate.difference(occurrenceDate);

    final newMasterEvent = masterEvent.copyWith(
      id: '', // Will be a new document
      start: newStartDate,
      end: newStartDate.add(masterEvent.end.difference(masterEvent.start)),
      exceptions: [], // For simplicity, we are not moving exceptions over.
      repeatUntil: masterEvent.repeatUntil?.add(timeDifference),
      userId: currentUserId,
    );

    try {
      await _service.moveThisAndFollowing(oldMasterEventUpdated, newMasterEvent);
    } catch (e) {
      print('Error moving this and following events: $e');
      _listenToEvents();
      rethrow;
    }
  }

  Future<void> moveAllEventsInSeries({
    required CalendarEvent masterEvent,
    required DateTime occurrenceDate,
    required DateTime newStartDate,
  }) async {
    if (currentUserId == null || masterEvent.userId != currentUserId) return;

    final timeDifference = newStartDate.difference(occurrenceDate);

    final updatedMasterEvent = masterEvent.copyWith(
      start: masterEvent.start.add(timeDifference),
      end: masterEvent.end.add(timeDifference),
      repeatUntil: masterEvent.repeatUntil?.add(timeDifference),
      exceptions: masterEvent.exceptions.map((e) => e.add(timeDifference)).toList(),
    );

    try {
      await updateEvent(updatedMasterEvent);
    } catch (e) {
      print('Error moving all events in series: $e');
      _listenToEvents();
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    if (currentUserId == null) return;

    final eventIndex = _events.indexWhere((e) => e.id == eventId);
    if (eventIndex == -1) return;

    final eventToDelete = _events[eventIndex];
    if (eventToDelete.userId != currentUserId) {
      throw Exception('Cannot delete an event that belongs to another user');
    }

    _lastDeletedEvent = eventToDelete;
    _events.removeAt(eventIndex);
    notifyListeners();

    _startUndoTimer(() {
      _service.deleteEvent(eventId).catchError((e) {
        print('Error confirming deletion: $e');
        _listenToEvents();
      });
    });
  }

  Future<void> deleteSingleOccurrence(
    CalendarEvent event,
    DateTime occurrenceDate,
  ) async {
    if (currentUserId == null || event.userId != currentUserId) return;

    final masterEventIndex = _events.indexWhere((e) => e.id == event.id);
    if (masterEventIndex == -1) return;

    _lastUpdatedEventOriginalState = _events[masterEventIndex];
    final masterEvent = _events[masterEventIndex];

    final normalizedDate =
        DateTime.utc(occurrenceDate.year, occurrenceDate.month, occurrenceDate.day);

    if (!masterEvent.exceptions.contains(normalizedDate)) {
      final updatedEvent = masterEvent.copyWith(
        exceptions: [...masterEvent.exceptions, normalizedDate],
      );
      _events[masterEventIndex] = updatedEvent;
      _lastDeletedEvent = updatedEvent;
      notifyListeners();

      _startUndoTimer(() {
        _service.updateEvent(updatedEvent).catchError((e) {
          print('Error confirming single deletion: $e');
          _listenToEvents();
        });
      });
    }
  }

  Future<void> deleteThisAndFollowing(
    CalendarEvent event,
    DateTime occurrenceDate,
  ) async {
    if (currentUserId == null || event.userId != currentUserId) return;

    final masterEventIndex = _events.indexWhere((e) => e.id == event.id);
    if (masterEventIndex == -1) return;

    _lastUpdatedEventOriginalState = _events[masterEventIndex];
    final masterEvent = _events[masterEventIndex];

    final updatedEvent = masterEvent.copyWith(
      repeatUntil: occurrenceDate.subtract(const Duration(days: 1)),
    );
    _events[masterEventIndex] = updatedEvent;
    _lastDeletedEvent = updatedEvent;
    notifyListeners();

    _startUndoTimer(() {
      _service.updateEvent(updatedEvent).catchError((e) {
        print('Error confirming following deletion: $e');
        _listenToEvents();
      });
    });
  }

  void undoDeletion() {
    _undoTimer?.cancel();
    if (_lastUpdatedEventOriginalState != null) {
      final index = _events.indexWhere((e) => e.id == _lastUpdatedEventOriginalState!.id);
      if (index != -1) {
        _events[index] = _lastUpdatedEventOriginalState!;
      } else {
        _events.add(_lastUpdatedEventOriginalState!);
      }
    } else if (_lastDeletedEvent != null) {
      _events.add(_lastDeletedEvent!);
      _events.sort((a, b) => a.start.compareTo(b.start));
    }

    _lastDeletedEvent = null;
    _lastUpdatedEventOriginalState = null;
    notifyListeners();
  }

  void dismissUndo() {
    _undoTimer?.cancel();
    if (_lastDeletedEvent != null) {
      if (_lastUpdatedEventOriginalState != null) {
        _service.updateEvent(_lastDeletedEvent!);
      } else {
        _service.deleteEvent(_lastDeletedEvent!.id);
      }
    }
    _lastDeletedEvent = null;
    _lastUpdatedEventOriginalState = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelEventsSubscription();
    _authSubscription?.cancel();
    _undoTimer?.cancel();
    super.dispose();
  }
}
