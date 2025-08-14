import 'dart:async';
import 'package:flutter/material.dart';
import '../models/event_poll.dart';
import '../services/poll_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PollState extends ChangeNotifier {
  final PollService _service = PollService();
  StreamSubscription? _pollsSubscription;
  List<EventPoll> _polls = [];
  bool _isLoading = true;

  List<EventPoll> get polls => _polls;
  bool get isLoading => _isLoading;

  PollState() {
    _listenToPolls();
  }

  void _listenToPolls() {
    _isLoading = true;
    notifyListeners();

    _pollsSubscription?.cancel();
    _pollsSubscription = _service.getPollsStream().listen((loadedPolls) {
      _polls = loadedPolls;
      _isLoading = false;
      notifyListeners();
    });
  }
  
  // Expose service methods if needed, e.g., for creating a poll
  Future<void> createPoll(EventPoll poll) async {
    await _service.createPoll(poll);
  }
  
  Future<void> castVote(String pollId, List<DateTime> selectedTimes) async {
    final timestamps = selectedTimes.map((dt) => Timestamp.fromDate(dt)).toList();
    await _service.castVote(pollId, timestamps);
  }

  @override
  void dispose() {
    _pollsSubscription?.cancel();
    super.dispose();
  }
}