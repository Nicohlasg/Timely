import 'package:cloud_firestore/cloud_firestore.dart';

class UserGroup {
  final String id;
  final String name;
  final String creatorId;
  final List<String> members; // List of user UIDs
  final Timestamp createdAt;
  final String photoURL; // For a group icon

  UserGroup({
    this.id = '',
    required this.name,
    required this.creatorId,
    required this.members,
    required this.createdAt,
    this.photoURL = '',
  });

  factory UserGroup.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserGroup(
      id: doc.id,
      name: data['name'] ?? 'Untitled Group',
      creatorId: data['creatorId'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      photoURL: data['photoURL'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'creatorId': creatorId,
    'members': members,
    'createdAt': createdAt,
    'photoURL': photoURL,
  };
}