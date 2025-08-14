import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileData {
  String uid;
  String email;
  String firstName;
  String lastName;
  String username;
  String occupation;
  String location;
  String phoneNumber;
  String photoURL;
  String backgroundImage;
  String schedulePermission;
  Map<String, dynamic> status;

  UserProfileData({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.occupation,
    required this.location,
    required this.phoneNumber,
    required this.photoURL,
    this.backgroundImage = 'assets/img/background.jpg',
    this.schedulePermission = 'friends',
    this.status = const {},
  });

  factory UserProfileData.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserProfileData(
      uid: doc.id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      username: data['username'] ?? '',
      occupation: data['occupation'] ?? '',
      location: data['location'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      photoURL: data['photoURL'] ?? 'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
      backgroundImage: data['backgroundImage'] ?? 'assets/img/background.jpg',
      schedulePermission: data['schedulePermission'] ?? 'friends',
      status: data['status'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'occupation': occupation,
      'location': location,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'backgroundImage': backgroundImage,
      'schedulePermission': schedulePermission,
      'status': status,
    };
  }

  UserProfileData copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    String? username,
    String? occupation,
    String? location,
    String? phoneNumber,
    String? photoURL,
    String? backgroundImage,
    Map<String, dynamic>? status,
  }) {
    return UserProfileData(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      occupation: occupation ?? this.occupation,
      location: location ?? this.location,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      status: status ?? this.status,
    );
  }
}