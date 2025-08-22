import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/google_calendar_service.dart';
import '../state/calendar_state.dart';

class SyncState extends ChangeNotifier {
  final GoogleCalendarService _googleCalendarService;
  CalendarState _calendarState;
  late final StreamSubscription<GoogleSignInAuthenticationEvent> _authSubscription;

  static const String _selectedCalPrefKey = 'selected_calendar_id';

  GoogleSignInAccount? _currentUser;
  bool _isSyncing = false;
  List<gcal.CalendarListEntry> _calendars = [];
  String? _selectedCalendarId;
  bool _isLoadingCalendars = false;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSyncing => _isSyncing;
  List<gcal.CalendarListEntry> get calendars => _calendars;
  String? get selectedCalendarId => _selectedCalendarId;
  bool get isLoadingCalendars => _isLoadingCalendars;

  SyncState(this._googleCalendarService, this._calendarState) {
    _googleCalendarService.initialize().then((_) {
      _authSubscription = _googleCalendarService.authenticationEvents.listen(
        _handleAuthEvent,
        onError: (e) => print("Auth stream error: $e"),
      );
      _googleCalendarService.attemptLightweightAuthentication();
    });
  }

  void _handleAuthEvent(GoogleSignInAuthenticationEvent event) async {
    GoogleSignInAccount? user;
    if (event is GoogleSignInAuthenticationEventSignIn) {
      user = event.user;
    } else if (event is GoogleSignInAuthenticationEventSignOut) {
      user = null;
    }
    
    if (_currentUser?.id != user?.id) {
      _currentUser = user;
      notifyListeners();

      if (user != null) {
        await _loadSelectedCalendar();
        await _fetchCalendars();
        await _sendAuthCodeToServer(user);
      } else {
        _calendars = [];
        _selectedCalendarId = null;
        notifyListeners();
      }
    }
  }
  
  Future<void> _fetchCalendars() async {
    if (_currentUser == null) return;
    _isLoadingCalendars = true;
    notifyListeners();

    try {
      _calendars = await _googleCalendarService.getCalendarList(_currentUser!);

      if (_calendars.isNotEmpty) {
        final currentSelectionExists = _calendars.any((c) => c.id == _selectedCalendarId);

        if (!currentSelectionExists) {
          final primaryCalendar = _calendars.firstWhere((c) => c.primary == true, orElse: () => _calendars.first);
          _selectedCalendarId = primaryCalendar.id;
          final prefs = await SharedPreferences.getInstance();
          if (_selectedCalendarId != null) {
            await prefs.setString(_selectedCalPrefKey, _selectedCalendarId!);
          }
        }
      } else {
        _selectedCalendarId = null;
      }
    } catch (e) {
      print('Error fetching calendars: $e');
      _calendars = [];
      _selectedCalendarId = null;
    } finally {
      _isLoadingCalendars = false;
      notifyListeners();
    }
  }

  Future<void> _loadSelectedCalendar() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedCalendarId = prefs.getString(_selectedCalPrefKey);
    // No need to call notifyListeners() here as it will be called in _handleAuthEvent
  }

  Future<void> selectCalendar(String? calendarId) async {
    if (calendarId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCalPrefKey, calendarId);
    _selectedCalendarId = calendarId;
    notifyListeners();
  }

  Future<void> signIn() async {
    await _googleCalendarService.authenticate();
  }

  Future<void> signOut() async {
    await _googleCalendarService.signOut();
  }

  Future<String> syncNow() async {
    if (_currentUser == null || _calendarState.currentUserId == null) return "Please sign in first.";
    if (_selectedCalendarId == null) return "Please select a calendar to sync.";

    _isSyncing = true;
    notifyListeners();

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('syncGoogleCalendar');
      final result = await callable.call({'calendarId': _selectedCalendarId});
      final message = result.data['message'] as String? ?? "Sync complete!";
      return message;
    } on FirebaseFunctionsException catch (e) {
      return "Sync failed: ${e.message}";
    } catch (e) {
      return "An error occurred: $e";
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
  
  void updateCalendarState(CalendarState newCalendarState) {
    _calendarState = newCalendarState;
  }

  Future<void> _sendAuthCodeToServer(GoogleSignInAccount user) async {
    try {
      final serverAuthCode = await _googleCalendarService.getServerAuthCode(user);
      if (serverAuthCode != null && _calendarState.currentUserId != null) {
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('storeAuthToken');
        await callable.call({'code': serverAuthCode});
      }
    } on FirebaseFunctionsException catch (e) {
      print("Error sending auth code to server: ${e.code} - ${e.message}");
    } catch (e) {
      print("Error sending auth code to server: $e");
    }
  }
}



// final String _storeTokenUrl = 'https://us-central1-calendar-application-bfe33.cloudfunctions.net/storeAuthToken';
// final String _syncCalendarUrl = 'https://us-central1-calendar-application-bfe33.cloudfunctions.net/syncGoogleCalendar';