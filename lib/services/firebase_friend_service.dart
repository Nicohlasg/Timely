import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// removed duplicate import
import 'package:flutter/material.dart';
import '../models/user_profile_data.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/calendar_event.dart';

class FirebaseFriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Helper to get IDs of users who are in a 'blocked' friendship with the current user.
  Future<Set<String>> _getBlockedUserIds() async {
    if (currentUserId == null) return {};
    try {
      final snapshot = await _firestore
          .collection('friendships')
          .where('users', arrayContains: currentUserId)
          .where('status', isEqualTo: 'blocked')
          .get();

      final blockedIds = <String>{};
      for (final doc in snapshot.docs) {
        final List<dynamic> users = doc.data()['users'];
        // Find the other user's ID in the relationship
        final otherUser = users.firstWhere((id) => id != currentUserId, orElse: () => null);
        if (otherUser != null) {
          blockedIds.add(otherUser);
        }
      }
      return blockedIds;
    } catch (e) {
      print("Error getting blocked user IDs: $e");
      return {}; // Return empty set on error
    }
  }

  // Search for users by email or username, excluding blocked users.
  Future<List<UserProfileData>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    final blockedUserIds = await _getBlockedUserIds();

    try {
      // Username prefix search
      final usernameSnapshot = await _firestore
          .collection('users')
          .orderBy('username')
          .startAt([query])
          .endAt(['${query}\uf8ff'])
          .limit(20)
          .get();

      // Email prefix search
      final emailSnapshot = await _firestore
          .collection('users')
          .orderBy('email')
          .startAt([query])
          .endAt(['${query}\uf8ff'])
          .limit(20)
          .get();

      final users = <String, UserProfileData>{};
      for (final doc in [...usernameSnapshot.docs, ...emailSnapshot.docs]) {
        // Exclude self and blocked users
        if (doc.id == currentUserId || blockedUserIds.contains(doc.id)) continue;
        users[doc.id] = UserProfileData.fromFirestore(doc);
      }
      return users.values.toList();
    } catch (e) {
      // Fallback to exact matching if indexes are missing or any error occurs
      try {
        final emailQuery = _firestore
            .collection('users')
            .where('email', isEqualTo: query)
            .get();
        final usernameQuery = _firestore
            .collection('users')
            .where('username', isEqualTo: query)
            .get();
        final results = await Future.wait([emailQuery, usernameQuery]);
        final users = results.expand((snapshot) => snapshot.docs).toList();
        final uniqueUsers = {
          for (var doc in users)
            // Exclude self and blocked users in fallback as well
            if (doc.id != currentUserId && !blockedUserIds.contains(doc.id))
              doc.id: UserProfileData.fromFirestore(doc)
        };
        return uniqueUsers.values.toList();
      } catch (_) {
        return [];
      }
    }
  }

  // Send a friend request
  Future<void> sendFriendRequest(String recipientId) async {
    if (currentUserId == null) throw Exception('No user signed in');
    if (currentUserId == recipientId) throw Exception('Cannot add yourself');

    final users = [currentUserId!, recipientId]..sort();
    final docId = users.join('_');

    final friendshipDoc = _firestore.collection('friendships').doc(docId);

    await friendshipDoc.set({
      'users': users,
      'requesterId': currentUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get streams for friends and friend requests
  Stream<List<DocumentSnapshot>> get friendshipsStream {
    if (currentUserId == null) return Stream.value([]);
    return _firestore
        .collection('friendships')
        .where('users', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  // Accept a friend request
  Future<void> acceptFriendRequest(String friendshipId) async {
    await _firestore.collection('friendships').doc(friendshipId).update({
      'status': 'accepted',
    });
  }

  // Decline a friend request
  Future<void> declineFriendRequest(String friendshipId) async {
    await _firestore.collection('friendships').doc(friendshipId).delete();
  }

  // Remove an existing friend (or cancel a pending request) by other user's ID
  Future<void> removeFriend(String otherUserId) async {
    if (currentUserId == null) throw Exception('No user signed in');
    final users = [currentUserId!, otherUserId]..sort();
    final docId = users.join('_');
    await _firestore.collection('friendships').doc(docId).delete();
  }

  Future<List<DateTime>> findFreeSlotsForFriends({
    required List<String> friendIds,
    required Duration duration,
    required DateTimeRange range,
  }) async {
    if (currentUserId == null) return [];

    try {
      final HttpsCallable callable = _functions.httpsCallable('findFreeSlots');
      final allUserIds = [currentUserId!, ...friendIds];

      final response = await callable.call<Map<String, dynamic>>({
        'userIds': allUserIds,
        'durationMinutes': duration.inMinutes,
        'startRangeISO': range.start.toIso8601String(),
        'endRangeISO': range.end.toIso8601String(),
      });

      final slots = response.data['availableSlots'] as List<dynamic>? ?? [];
      return slots.map((iso) => DateTime.parse(iso)).toList();
    } on FirebaseFunctionsException catch (e) {
      print('Cloud function failed with error: ${e.code} - ${e.message}');
      return [];
    } catch (e) {
      print("Error calling findFreeSlots function: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFriendSchedule(String friendId) async {
    try {
      final callable = _functions.httpsCallable('getFriendSchedule');
      final response =
          await callable.call<Map<String, dynamic>>({'friendId': friendId});
      final raw = response.data['events'] as List<dynamic>? ?? [];
      final eventsList = raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return eventsList;
    } on FirebaseFunctionsException catch (e) {
      print('Cloud function failed: ${e.code} - ${e.message}');
      // Re-throw the message to display it in the UI
      throw Exception(e.message);
    } catch (e) {
      print('Error getting friend schedule: $e');
      throw Exception('An unknown error occurred.');
    }
  }

  Future<Map<String, dynamic>> proposeEvent({
    required String recipientId,
    required CalendarEvent event,
  }) async {
    try {
      final callable = _functions.httpsCallable('proposeEvent');
      final response = await callable.call<Map<String, dynamic>>({
        'recipientId': recipientId,
        'eventData': {
          'title': event.title,
          'location': event.location,
          'startISO': event.start.toIso8601String(),
          'endISO': event.end.toIso8601String(),
        },
      });
      return response.data;
    } on FirebaseFunctionsException catch (e) {
      print('Cloud function failed: ${e.code} - ${e.message}');
      return {'success': false, 'reason': e.message};
    } catch (e) {
      print('Error proposing event: $e');
      return {'success': false, 'reason': 'An unknown error occurred.'};
    }
  }

  // Get a stream of incoming proposals
  Stream<QuerySnapshot> getProposalsStream() {
    // The state ensures a valid user is signed in before listening.
    final userId = FirebaseAuth.instance.currentUser?.uid;
    // Only listen to pending proposals; no orderBy to avoid composite index.
    return FirebaseFirestore.instance
        .collection('eventProposals')
        .where('recipientId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
}

// Method to call the new cloud function
  Future<void> respondToProposal(
      {required String proposalId, required bool accept}) async {
    try {
      final callable = _functions.httpsCallable('respondToProposal');
      await callable.call<void>({
        'proposalId': proposalId,
        'response': accept ? 'accepted' : 'declined',
      });
    } on FirebaseFunctionsException catch (e) {
      print('Cloud function failed: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Error responding to proposal: $e');
      throw Exception('An unknown error occurred.');
    }
  }

  Future<void> blockUser(String userIdToBlock) async {
    try {
      final callable = _functions.httpsCallable('blockUser');
      await callable.call({'userIdToBlock': userIdToBlock});
    } on FirebaseFunctionsException catch (e) {
      print('Cloud function failed: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Error blocking user: $e');
      throw Exception('An unknown error occurred while blocking the user.');
    }
  }

  Future<void> submitReport({
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    try {
      final callable = _functions.httpsCallable('submitReport');
      await callable.call({
        'reportedUserId': reportedUserId,
        'reason': reason,
        'details': details ?? '',
      });
    } on FirebaseFunctionsException catch (e) {
      print('Cloud function failed: ${e.code} - ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Error submitting report: $e');
      throw Exception('An unknown error occurred while submitting the report.');
    }
  }
}
