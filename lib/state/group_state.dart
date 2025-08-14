import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_group.dart';
import '../services/group_service.dart';

class GroupState extends ChangeNotifier {
  final GroupService _service = GroupService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _groupsSubscription;
  StreamSubscription? _authSubscription;
  List<UserGroup> _groups = [];
  bool _isLoading = true;

  List<UserGroup> get groups => _groups;
  bool get isLoading => _isLoading;

  GroupState() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToGroups(user.uid);
      } else {
        _groups.clear();
        _groupsSubscription?.cancel();
        notifyListeners();
      }
    });
  }

  void _listenToGroups(String userId) {
    _isLoading = true;
    notifyListeners();

    _groupsSubscription?.cancel();
    _groupsSubscription = _service.getGroupsStream(userId).listen((loadedGroups) {
      _groups = loadedGroups;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> createGroup(UserGroup group) async {
    await _service.createGroup(group);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _groupsSubscription?.cancel();
    super.dispose();
  }
}