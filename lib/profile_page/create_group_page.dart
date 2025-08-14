import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_group.dart';
import '../models/user_profile_data.dart';
import '../state/friend_state.dart';
import '../state/group_state.dart';
import '../widgets/background_container.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _nameController = TextEditingController();
  final Set<UserProfileData> _selectedFriends = {};

  void _createGroup() {
    if (_nameController.text.isEmpty || _selectedFriends.isEmpty) return;
    
    final friendState = context.read<FriendState>();
    final groupState = context.read<GroupState>();

    final currentUserId = friendState.currentUserId!;
    final memberIds = [currentUserId, ..._selectedFriends.map((f) => f.uid)];

    final newGroup = UserGroup(
      name: _nameController.text.trim(),
      creatorId: currentUserId,
      members: memberIds,
      createdAt: Timestamp.now(),
    );

    groupState.createGroup(newGroup);
    Navigator.of(context).pop();
  }
  
  @override
  Widget build(BuildContext context) {
    final friends = context.watch<FriendState>().friendProfiles;
    
    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Create Group', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            TextButton(
              onPressed: _createGroup,
              child: Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Select Friends', style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
            const Divider(color: Colors.white30),
            ...friends.map((friend) {
              final isSelected = _selectedFriends.contains(friend);
              return CheckboxListTile(
                value: isSelected,
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedFriends.add(friend);
                    } else {
                      _selectedFriends.remove(friend);
                    }
                  });
                },
                title: Text('${friend.firstName} ${friend.lastName}', style: TextStyle(color: Colors.white)),
                secondary: CircleAvatar(
                  backgroundImage: NetworkImage(friend.photoURL),
                ),
                activeColor: Colors.blue,
              );
            }),
          ],
        ),
      ),
    );
  }
}