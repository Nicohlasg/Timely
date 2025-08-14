import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/friendship.dart';
import '../models/user_profile_data.dart';
import '../services/firebase_friend_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendState extends ChangeNotifier {
  final FirebaseFriendService _service = FirebaseFriendService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _authSubscription;
  StreamSubscription? _friendshipSubscription;

  List<Friendship> _friendships = [];
  List<UserProfileData> _friendProfiles = [];
  List<UserProfileData> _requesterProfiles = []; // <-- NEW: Store requester profiles
  bool _isLoading = true;

  List<UserProfileData> get friendProfiles => _friendProfiles;
  List<UserProfileData> get requesterProfiles => _requesterProfiles; // <-- NEW
  bool get isLoading => _isLoading;
  String? get currentUserId => _auth.currentUser?.uid;

  List<Friendship> get acceptedFriends => _friendships.where((f) => f.status == FriendshipStatus.accepted).toList();
  List<Friendship> get pendingRequests => _friendships.where((f) => f.status == FriendshipStatus.pending && f.requesterId != currentUserId).toList();

  FriendState() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToFriendships();
      } else {
        _friendships.clear();
        _friendProfiles.clear();
        _requesterProfiles.clear();
        _friendshipSubscription?.cancel();
        notifyListeners();
      }
    });
  }

  void _listenToFriendships() {
    _isLoading = true;
    notifyListeners();

    _friendshipSubscription?.cancel();
    _friendshipSubscription = _service.friendshipsStream.listen((snapshots) async {
      _friendships = snapshots.map((doc) => Friendship.fromFirestore(doc)).toList();
      await _fetchFriendAndRequesterProfiles(); // <-- UPDATED to fetch both
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _fetchFriendAndRequesterProfiles() async {
    if (_friendships.isEmpty) {
      _friendProfiles = [];
      _requesterProfiles = [];
      return;
    }

    // Get IDs for accepted friends
    final friendIds = acceptedFriends
        .map((f) => f.users.firstWhere((id) => id != currentUserId))
        .toSet().toList();
    
    // Get IDs for pending requests
    final requesterIds = pendingRequests
        .map((f) => f.requesterId)
        .toSet().toList();

    // Fetch profiles for friends
    if (friendIds.isNotEmpty) {
      final profileDocs = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: friendIds)
          .get();
      _friendProfiles = profileDocs.docs.map((doc) => UserProfileData.fromFirestore(doc)).toList();
    } else {
      _friendProfiles = [];
    }
    
    // Fetch profiles for requesters
    if (requesterIds.isNotEmpty) {
      final requesterDocs = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: requesterIds)
          .get();
      _requesterProfiles = requesterDocs.docs.map((doc) => UserProfileData.fromFirestore(doc)).toList();
    } else {
      _requesterProfiles = [];
    }
  }
  
  // Expose service methods to be called from the UI
  Future<List<UserProfileData>> searchUsers(String query) async {
    return await _service.searchUsers(query);
  }

  Future<void> sendFriendRequest(String recipientId) async {
    await _service.sendFriendRequest(recipientId);
  }

  Future<void> acceptRequest(String friendshipId) async {
    await _service.acceptFriendRequest(friendshipId);
  }

  Future<void> declineRequest(String friendshipId) async {
    await _service.declineFriendRequest(friendshipId);
  }

  Future<void> removeFriendByUserId(String otherUserId) async {
    await _service.removeFriend(otherUserId);
  }

  Future<void> blockUser(String userIdToBlock) async {
    // The stream will handle the UI update automatically when the friendship doc changes.
    await _service.blockUser(userIdToBlock);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _friendshipSubscription?.cancel();
    super.dispose();
  }
}