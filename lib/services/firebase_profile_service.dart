import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile_data.dart';

class FirebaseProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Stream<UserProfileData?> getProfileStream() {
    if (currentUserId == null) {
      return Stream.value(null);
    }

    return _firestore.collection('users').doc(currentUserId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserProfileData.fromFirestore(snapshot);
      } else {
        return null;
      }
    });
  }

  Future<void> updateProfile(UserProfileData profile) async {
    if (currentUserId == null) {
      throw Exception('No user is currently signed in');
    }

    if (profile.uid != currentUserId) {
      throw Exception('Cannot update a profile that belongs to another user');
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .update(profile.toFirestore());
  }

  Future<void> createInitialProfile({
    required String email,
    String displayName = '',
    String photoURL = '',
  }) async {
    if (currentUserId == null) {
      throw Exception('No user is currently signed in');
    }

    String firstName = '';
    String lastName = '';

    if (displayName.isNotEmpty) {
      final nameParts = displayName.split(' ');
      firstName = nameParts.first;
      lastName = nameParts.length > 1 ? nameParts.last : '';
    }

    return _firestore.collection('users').doc(currentUserId).set({
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'username': email.split('@').first,
      'occupation': '',
      'location': '',
      'phoneNumber': '',
      'photoURL': photoURL.isNotEmpty
          ? photoURL
          : 'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
      'createdAt': FieldValue.serverTimestamp(),
      'backgroundImage': 'assets/img/background.jpg',
    });
  }

  Future<void> updateUserStatus(Map<String, dynamic> status) async {
    if (currentUserId == null) {
      throw Exception('No user is currently signed in');
    }
    return _firestore.collection('users').doc(currentUserId).update({
      'status': status,
    });
  }
}