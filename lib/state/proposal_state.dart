import 'dart:async';
import 'package:flutter/material.dart';
import '../models/event_proposal.dart';
import '../services/firebase_friend_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProposalState extends ChangeNotifier {
  final FirebaseFriendService _service = FirebaseFriendService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _proposalsSubscription;
  StreamSubscription? _authSubscription;
  List<EventProposal> _proposals = [];
  bool _isLoading = true;

  List<EventProposal> get proposals => _proposals;
  bool get isLoading => _isLoading;

  ProposalState() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _attachProposalsListener();
      } else {
        _clear();
      }
    });
    // Also try attach immediately in case a user is already signed in
    if (_auth.currentUser != null) {
      _attachProposalsListener();
    } else {
      _isLoading = false;
    }
  }

  void _attachProposalsListener() {
    _isLoading = true;
    notifyListeners();

    _proposalsSubscription?.cancel();
    _proposalsSubscription = _service.getProposalsStream().listen(
      (snapshot) {
        _proposals = snapshot.docs.map((doc) => EventProposal.fromDoc(doc)).toList();
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        // Surface index errors or permission issues in console; keep UI from hanging
        debugPrint('Proposals stream error: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _clear() {
    _proposalsSubscription?.cancel();
    _proposals = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<void> respondToProposal({required String proposalId, required bool accept}) async {
    _proposals.removeWhere((p) => p.id == proposalId);
    notifyListeners();

    try {
      await _service.respondToProposal(proposalId: proposalId, accept: accept);
    } catch (e) {
      debugPrint('Error responding to proposal: $e');
      _attachProposalsListener();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _proposalsSubscription?.cancel();
    super.dispose();
  }
}