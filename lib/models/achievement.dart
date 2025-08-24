import 'package:cloud_firestore/cloud_firestore.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final String iconAssetPath; // e.g., 'assets/achievements/first_login.png'
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconAssetPath,
    this.unlockedAt,
  });

  bool get isUnlocked => unlockedAt != null;

  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    String? iconAssetPath,
    DateTime? unlockedAt,
    bool? clearUnlockedAt,
  }) {
    return Achievement(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconAssetPath: iconAssetPath ?? this.iconAssetPath,
      unlockedAt: clearUnlockedAt == true ? null : unlockedAt ?? this.unlockedAt,
    );
  }

  // This represents the static definition of an achievement
  Map<String, dynamic> toDefinitionJson() => {
        'name': name,
        'description': description,
        'iconAssetPath': iconAssetPath,
      };

  // This represents a user's specific instance of an achievement
  Map<String, dynamic> toUserAchievementJson() => {
    'unlockedAt': unlockedAt != null ? Timestamp.fromDate(unlockedAt!) : null,
    'achievementId': id,
  };

  // Creates an Achievement from its static definition
  static Achievement fromDefinitionDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return Achievement(
      id: doc.id,
      name: data['name'] ?? 'Unknown Achievement',
      description: data['description'] ?? '',
      iconAssetPath: data['iconAssetPath'] ?? '',
    );
  }

  // Updates an Achievement with a user's unlocked data
  Achievement withUserData(DocumentSnapshot userDoc) {
    final data = userDoc.data() as Map<String, dynamic>?;
    return copyWith(
      unlockedAt: data?['unlockedAt'] != null
          ? (data!['unlockedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
