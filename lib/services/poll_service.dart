import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_poll.dart';

class PollService {
  final CollectionReference _pollCollection =
      FirebaseFirestore.instance.collection('event_polls');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Stream of polls the current user is a participant in
  Stream<List<EventPoll>> getPollsStream() {
    if (currentUserId == null) return Stream.value([]);
    
    return _pollCollection
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => EventPoll.fromDoc(doc)).toList());
  }

  Future<void> createPoll(EventPoll poll) async {
    if (currentUserId == null) throw Exception('No user signed in');
    await _pollCollection.add(poll.toJson());
  }

  Future<void> castVote(String pollId, List<Timestamp> selectedTimes) async {
    if (currentUserId == null) throw Exception('No user signed in');
    await _pollCollection.doc(pollId).update({
      'votes.$currentUserId': selectedTimes,
    });
  }
  
  // Finalizing a poll would involve more complex logic:
  // 1. Read the poll data.
  // 2. Find the most voted time.
  // 3. Create a new CalendarEvent using the calendar service.
  // 4. Delete the poll document.
  // This could be a good candidate for a Cloud Function.
}