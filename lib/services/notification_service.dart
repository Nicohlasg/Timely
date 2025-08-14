import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    // Request permission from the user
    await _fcm.requestPermission();

    // Get the FCM token for this device
    final token = await _fcm.getToken();
    print("FCM Token: $token");

    // Save the token to Firestore
    await _saveTokenToDatabase(token);

    // Listen for token refreshes
    _fcm.onTokenRefresh.listen(_saveTokenToDatabase);
  }

  Future<void> _saveTokenToDatabase(String? token) async {
    if (token == null) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('fcm_tokens')
        .doc(token)
        .set({
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}