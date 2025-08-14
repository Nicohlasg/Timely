import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import '../environment.dart';

/// A helper class to create an authenticated HTTP client for Google APIs.
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Intercepts the request and adds the authorization headers.
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GoogleCalendarService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static const List<String> _scopes = [
    gcal.CalendarApi.calendarScope,
    gcal.CalendarApi.calendarReadonlyScope,
  ];

  Future<void> initialize() async {
    try {
      final clientId = AppEnv.googleServerClientId;
      await _googleSignIn.initialize(
        serverClientId: clientId.isEmpty ? null : clientId,
      );
    } catch (e) {
      print("Google Sign-In initialization error: $e");
    }
  }

  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      _googleSignIn.authenticationEvents;

  Future<void> authenticate() async {
    try {
      await _googleSignIn.authenticate();
    } catch (e) {
      print("Error during authenticate: $e");
    }
  }

  Future<String?> getServerAuthCode(GoogleSignInAccount user) async {
    try {
      final serverAuth = await user.authorizationClient.authorizeServer(_scopes);
      return serverAuth?.serverAuthCode;
    } catch (e) {
      print("Error getting server auth code: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (error) {
      print("Error during sign out: $error");
    }
  }

  Future<void> attemptLightweightAuthentication() async {
    try {
      await _googleSignIn.attemptLightweightAuthentication();
    } catch (e) {
      print("Error during lightweight authentication: $e");
    }
  }

  Future<gcal.CalendarApi?> getCalendarApi(GoogleSignInAccount user) async {
    GoogleSignInClientAuthorization? authorization =
        await user.authorizationClient.authorizationForScopes(_scopes);

    if (authorization == null) {
      try {
        authorization = await user.authorizationClient.authorizeScopes(_scopes);
      } catch (e) {
        print("Error authorizing scopes: $e");
        return null;
      }
    }
    
    final authHeaders = await user.authorizationClient.authorizationHeaders(_scopes);

    if (authHeaders == null) return null;

    final client = _GoogleAuthClient(authHeaders);
    return gcal.CalendarApi(client);
  }

  // ### FIX: Removed direct access to _googleSignIn.currentUser ###
  // The user account is now passed in as a parameter.
  Future<List<gcal.CalendarListEntry>> getCalendarList(GoogleSignInAccount user) async {
    final calendarApi = await getCalendarApi(user);
    if (calendarApi == null) return [];

    try {
      final gcal.CalendarList calendarList = await calendarApi.calendarList.list();
      return calendarList.items
              ?.where((cal) =>
                  cal.accessRole == 'writer' || cal.accessRole == 'owner')
              .toList() ??
          [];
    } catch (e) {
      print("Error fetching calendar list: $e");
      return [];
    }
  }
}



// 555685092170-vk16v8lmrdg7k6vd03747qvqlrnkar76.apps.googleusercontent.com