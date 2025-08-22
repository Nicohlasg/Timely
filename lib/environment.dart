import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  // Static getter for OCR Function URL, using String.fromEnvironment
  static const String ocrFunctionUrl = String.fromEnvironment(
    'OCR_FUNCTION_URL',
    defaultValue: 'OCR_URL_NOT_SET', // Provide a meaningful default
  );

  // Static getter for AI Chatbot Function URL, using String.fromEnvironment
  static const String chatFunctionUrl = String.fromEnvironment(
    'CHAT_FUNCTION_URL',
    defaultValue: 'CHAT_URL_NOT_SET', // Provide a meaningful default
  );

  static String get googleServerClientId => _get('GOOGLE_SERVER_CLIENT_ID');
  static String get chatFunctionUrl => _get('CHAT_FUNCTION_URL');
  static String get syncStoreTokenUrl => _get('SYNC_STORE_TOKEN_URL');
  static String get syncCalendarUrl => _get('SYNC_CALENDAR_URL');
  static String get ocrFunctionUrl => _get('OCR_FUNCTION_URL');
}