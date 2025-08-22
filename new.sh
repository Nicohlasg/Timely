sh
    flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID="YOUR_ACTUAL_ID" --dart-define=OCR_FUNCTION_URL="YOUR_URL"
    # Or for appbundle
    flutter build appbundle --dart-define=GOOGLE_SERVER_CLIENT_ID="YOUR_ACTUAL_ID" --dart-define=OCR_FUNCTION_URL="YOUR_URL"