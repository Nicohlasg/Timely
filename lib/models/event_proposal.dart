import 'package:cloud_firestore/cloud_firestore.dart';

class EventProposal {
  final String id;
  final String proposerId;
  final String proposerName;
  final String recipientId;
  final String title;
  final String location;
  final Timestamp start;
  final Timestamp end;
  final String status; // 'pending', 'accepted', 'declined'
  final Timestamp createdAt;

  EventProposal({
    this.id = '',
    required this.proposerId,
    required this.proposerName,
    required this.recipientId,
    required this.title,
    required this.location,
    required this.start,
    required this.end,
    this.status = 'pending',
    required this.createdAt,
  });

  factory EventProposal.fromDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return EventProposal(
      id: doc.id,
      proposerId: data['proposerId'] ?? '',
      proposerName: data['proposerName'] ?? 'Unknown User',
      recipientId: data['recipientId'] ?? '',
      title: data['title'] ?? 'Untitled Proposal',
      location: data['location'] ?? '',
      start: data['start'] ?? Timestamp.now(),
      end: data['end'] ?? Timestamp.now(),
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'proposerId': proposerId,
    'proposerName': proposerName,
    'recipientId': recipientId,
    'title': title,
    'location': location,
    'start': start,
    'end': end,
    'status': status,
    'createdAt': createdAt,
  };
}