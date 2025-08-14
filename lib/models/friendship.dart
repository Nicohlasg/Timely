import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendshipStatus { pending, accepted, declined, blocked }

class Friendship {
  final String uid; // Document ID
  final List<String> users; // List of two user UIDs
  final String requesterId;
  final FriendshipStatus status;
  final Timestamp createdAt;

  Friendship({
    required this.uid,
    required this.users,
    required this.requesterId,
    required this.status,
    required this.createdAt,
  });

  factory Friendship.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Friendship(
      uid: doc.id,
      users: List<String>.from(data['users'] ?? []),
      requesterId: data['requesterId'] ?? '',
      status: FriendshipStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => FriendshipStatus.pending,
      ),
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}