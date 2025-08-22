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

  // Example for GOOGLE_SERVER_CLIENT_ID
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: 'GOOGLE_ID_NOT_SET', // Provide a meaningful default
  );

  // You can add a helper to check if critical values were actually provided
  static void checkValues() {
    if (ocrFunctionUrl == 'OCR_URL_NOT_SET') {
      print('WARNING: OCR_FUNCTION_URL was not provided via --dart-define.');
    }
    if (chatFunctionUrl == 'CHAT_URL_NOT_SET') {
      print('WARNING: CHAT_FUNCTION_URL was not provided via --dart-define.');
    }
    if (googleServerClientId == 'GOOGLE_ID_NOT_SET') {
      print('WARNING: GOOGLE_SERVER_CLIENT_ID was not provided via --dart-define.');
    }
    // Add checks for other critical variables
  }
}