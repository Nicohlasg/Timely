import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String _get(String key) =>
      dotenv.env[key] ?? String.fromEnvironment(key, defaultValue: '');

  static String get googleServerClientId => _get('GOOGLE_SERVER_CLIENT_ID');
  static String get chatFunctionUrl => _get('CHAT_FUNCTION_URL');
  static String get syncStoreTokenUrl => _get('SYNC_STORE_TOKEN_URL');
  static String get syncCalendarUrl => _get('SYNC_CALENDAR_URL');
  static String get ocrFunctionUrl => _get('OCR_FUNCTION_URL');
}