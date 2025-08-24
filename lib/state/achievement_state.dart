import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/achievement.dart';

class AchievementState extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Achievement> _allAchievements = [];
  List<Achievement> get allAchievements => _allAchievements;

  Achievement? _lastUnlocked;
  Achievement? get lastUnlocked => _lastUnlocked;

  StreamSubscription? _authSub;
  StreamSubscription? _achievementSub;

  AchievementState() {
    _loadAllAchievements();
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToUserAchievements(user.uid);
      } else {
        _achievementSub?.cancel();
        _allAchievements.forEach((ach) => ach.copyWith(clearUnlockedAt: true));
        notifyListeners();
      }
    });
  }

  Future<void> _loadAllAchievements() async {
    // In a real app, this would come from Firestore or a config file.
    // For now, we define them statically.
    _allAchievements = [
      Achievement(
        id: 'first_login',
        name: 'First Login',
        description: 'Welcome aboard! You logged in for the first time.',
        iconAssetPath: 'assets/achievements/first_login.png', // Placeholder
      ),
      Achievement(
        id: 'first_task',
        name: 'Task Initiator',
        description: 'You created your very first task.',
        iconAssetPath: 'assets/achievements/first_task.png', // Placeholder
      ),
      Achievement(
        id: 'task_complete',
        name: 'Task Master',
        description: 'You completed your first task. Well done!',
        iconAssetPath: 'assets/achievements/task_complete.png', // Placeholder
      ),
    ];
    notifyListeners();
  }

  void _listenToUserAchievements(String userId) {
    _achievementSub?.cancel();
    _achievementSub = _firestore
        .collection('users')
        .doc(userId)
        .collection('unlocked_achievements')
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final index = _allAchievements.indexWhere((ach) => ach.id == doc.id);
        if (index != -1) {
          _allAchievements[index] = _allAchievements[index].withUserData(doc);
        }
      }
      notifyListeners();
    });
  }

  Future<void> unlockAchievement(String achievementId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final achievement = _allAchievements.firstWhere((ach) => ach.id == achievementId);
    if (achievement.isUnlocked) return; // Already unlocked

    final unlockedData = {
      'unlockedAt': Timestamp.now(),
      'achievementId': achievementId,
    };

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('unlocked_achievements')
        .doc(achievementId)
        .set(unlockedData);

    // Set this as the last unlocked to trigger UI animations
    _lastUnlocked = achievement.copyWith(unlockedAt: DateTime.now());
    notifyListeners();
  }

  void clearLastUnlocked() {
    _lastUnlocked = null;
    // No need to notify listeners, this is a silent clear
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _achievementSub?.cancel();
    super.dispose();
  }
}
