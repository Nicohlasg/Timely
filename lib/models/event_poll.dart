import 'package:cloud_firestore/cloud_firestore.dart';

class EventPoll {
  final String id;
  final String title;
  final String location;
  final String createdBy; // User ID of the creator
  final List<String> participants; // List of user IDs
  final List<Timestamp> proposedTimes; // List of start times for the poll options
  final Duration duration; // Duration of the event, e.g., 60 minutes
  final Map<String, List<Timestamp>> votes; // Key: UserID, Value: List of voted times

  EventPoll({
    this.id = '',
    required this.title,
    this.location = '',
    required this.createdBy,
    required this.participants,
    required this.proposedTimes,
    required this.duration,
    required this.votes,
  });

  factory EventPoll.fromDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return EventPoll(
      id: doc.id,
      title: data['title'] ?? 'Untitled Poll',
      location: data['location'] ?? '',
      createdBy: data['createdBy'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      proposedTimes: (data['proposedTimes'] as List<dynamic>? ?? [])
          .map((t) => t as Timestamp)
          .toList(),
      duration: Duration(minutes: data['durationInMinutes'] ?? 60),
      votes: (data['votes'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>).map((t) => t as Timestamp).toList(),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'location': location,
    'createdBy': createdBy,
    'participants': participants,
    'proposedTimes': proposedTimes,
    'durationInMinutes': duration.inMinutes,
    'votes': votes,
  };
}