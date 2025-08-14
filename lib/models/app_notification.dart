import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId;
  final String type; // e.g. 'proposalAccepted'
  final String title;
  final String byUserId;
  final Timestamp createdAt;
  final Map<String, dynamic> meta;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.byUserId,
    required this.createdAt,
    this.meta = const {},
  });

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      byUserId: data['byUserId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      meta: (data['meta'] as Map<String, dynamic>?) ?? {},
    );
  }
}


