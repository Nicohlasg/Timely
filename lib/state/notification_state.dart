import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/app_notification.dart';

class NotificationState extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _authSub;
  StreamSubscription? _notifSub;
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;

  NotificationState() {
    _authSub = _auth.authStateChanges().listen((user) {
      if (user == null) {
        _notifications = [];
        _notifSub?.cancel();
        _isLoading = false;
        notifyListeners();
        return;
      }
      _attach(user.uid);
    });
    if (_auth.currentUser != null) {
      _attach(_auth.currentUser!.uid);
    } else {
      _isLoading = false;
    }
  }

  void _attach(String uid) {
    _isLoading = true;
    notifyListeners();
    _notifSub?.cancel();
    _notifSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _notifications = snapshot.docs.map((d) => AppNotification.fromDoc(d)).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Notifications stream error: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }
}


