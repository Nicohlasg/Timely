import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile_data.dart';
import '../services/firebase_storage_service.dart';
import '../services/firebase_profile_service.dart';

class ProfileState extends ChangeNotifier {
  final FirebaseProfileService _service = FirebaseProfileService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserProfileData? _userProfile;
  StreamSubscription? _profileSubscription;
  StreamSubscription? _authSubscription;
  bool _isLoading = true;

  UserProfileData? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get currentUserId => _auth.currentUser?.uid;

  ProfileState() {
    _authSubscription = _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _listenToProfile();
      } else {
        _cancelProfileSubscription();
        _userProfile = null;
        _isLoading = true;
        notifyListeners();
      }
    });
  }

  void _listenToProfile() {
    _cancelProfileSubscription();

    _isLoading = true;
    notifyListeners();

    _profileSubscription = _service.getProfileStream().listen(
      (profile) {
        _userProfile = profile;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        print('Error loading profile: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _cancelProfileSubscription() {
    _profileSubscription?.cancel();
    _profileSubscription = null;
  }

  Future<void> updateProfile(UserProfileData profile) async {
    if (currentUserId == null) {
      throw Exception('Must be logged in to update profile');
    }

    if (profile.uid != currentUserId) {
      throw Exception('Cannot update a profile that belongs to another user');
    }

    try {
      await _service.updateProfile(profile);
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  Future<void> createInitialProfile(User user) async {
    try {
      await _service.createInitialProfile(
        email: user.email ?? '',
        displayName: user.displayName ?? '',
        photoURL: user.photoURL ?? '',
      );
    } catch (e) {
      print('Error creating initial profile: $e');
      rethrow;
    }
  }

  Future<void> updateBackgroundImage(String imagePathOrUrl) async {
    if (currentUserId == null || _userProfile == null) return;
    _userProfile = _userProfile!.copyWith(backgroundImage: imagePathOrUrl);
    await _service.updateProfile(_userProfile!);
    notifyListeners();
  }

  Future<void> setPresetBackground(String assetPath) async {
    if (currentUserId == null || _userProfile == null) return;

    try {
      _userProfile = _userProfile!.copyWith(backgroundImage: assetPath);
      notifyListeners();

      await _service.updateProfile(_userProfile!);
    } catch (e) {
      print('Error setting preset background: $e');
      _listenToProfile();
    }
  }

  Future<void> setCustomBackground() async {
    if (currentUserId == null || _userProfile == null) return;

    try {
      final XFile? imageFile = await _storageService.pickImage();
      if (imageFile == null) return;

      final String? downloadUrl = await _storageService.uploadBackgroundImage(currentUserId!, imageFile);
      if (downloadUrl == null) {
        print('Upload failed, could not get download URL.');
        return;
      }

      await setPresetBackground(downloadUrl);

    } catch (e) {
      print('Error setting custom background: $e');
      _listenToProfile();
    }
  }

  @override
  void dispose() {
    _cancelProfileSubscription();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> updateUserStatus(String statusText, {Duration? duration}) async {
    if (currentUserId == null) return;
    
    final Map<String, dynamic> newStatus = {
      'text': statusText,
      'type': 'custom', // You can add types later e.g. 'focus', 'meeting'
    };
    
    if (duration != null) {
      newStatus['expires'] = Timestamp.fromDate(DateTime.now().add(duration));
    } else {
      newStatus['expires'] = null; // A permanent status until cleared
    }

    // Optimistic UI update
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(status: newStatus);
      notifyListeners();
    }
    
    try {
      await _service.updateUserStatus(newStatus);
    } catch (e) {
      print("Error updating status: $e");
      // Revert on error
      _listenToProfile();
    }
  }

  Future<void> clearUserStatus() async {
    await updateUserStatus('');
  }
}
