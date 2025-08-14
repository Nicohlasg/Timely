import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_group.dart';

class GroupService {
  final CollectionReference _groupCollection = FirebaseFirestore.instance.collection('groups');

  Stream<List<UserGroup>> getGroupsStream(String userId) {
    return _groupCollection
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserGroup.fromDoc(doc)).toList());
  }

  Future<void> createGroup(UserGroup group) async {
    await _groupCollection.add(group.toJson());
  }
}