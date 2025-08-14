import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/calendar_event.dart';

class FirebaseCalendarService {
  final CollectionReference _eventCollection = FirebaseFirestore.instance
      .collection('events');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Stream<List<CalendarEvent>> getEventsStream() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _eventCollection
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CalendarEvent.fromDoc(doc))
              .toList();
        });
  }

  Future<void> addEvent(CalendarEvent event) {
    if (currentUserId == null) {
      throw Exception('No user is currently signed in');
    }

    final eventWithUserId = event.copyWith(userId: currentUserId);
    return _eventCollection.add(eventWithUserId.toJson());
  }

  Future<void> updateEvent(CalendarEvent event) async {
    if (currentUserId == null) {
      throw Exception('No user is currently signed in');
    }

    if (event.userId != currentUserId) {
      throw Exception('Cannot update an event that belongs to another user');
    }

    return _eventCollection.doc(event.id).update(event.toJson());
  }

  Future<void> createExceptionForRecurringEvent(CalendarEvent masterWithException, CalendarEvent newEvent) async {
    if (currentUserId == null) throw Exception('No user signed in');

    final batch = FirebaseFirestore.instance.batch();

    // Update the master event with the new exception
    final masterRef = _eventCollection.doc(masterWithException.id);
    batch.update(masterRef, masterWithException.toJson());

    // Create the new standalone event
    final newEventRef = _eventCollection.doc(); // Firestore generates ID
    batch.set(newEventRef, newEvent.copyWith(id: newEventRef.id).toJson());

    await batch.commit();
  }

  Future<void> moveThisAndFollowing(CalendarEvent oldMaster, CalendarEvent newMaster) async {
    if (currentUserId == null) throw Exception('No user signed in');

    final batch = FirebaseFirestore.instance.batch();

    final oldRef = _eventCollection.doc(oldMaster.id);
    batch.update(oldRef, oldMaster.toJson());

    final newRef = _eventCollection.doc(); // new event
    batch.set(newRef, newMaster.toJson());

    await batch.commit();
  }

  Future<void> deleteEvent(String eventId) async {
    if (currentUserId == null) {
      throw Exception('No user is currently signed in');
    }

    final docSnapshot = await _eventCollection.doc(eventId).get();
    if (!docSnapshot.exists) {
      return;
    }

    final data = docSnapshot.data() as Map<String, dynamic>?;
    if (data == null || data['userId'] != currentUserId) {
      throw Exception('Cannot delete an event that belongs to another user');
    }

    return _eventCollection.doc(eventId).delete();
  }
}
