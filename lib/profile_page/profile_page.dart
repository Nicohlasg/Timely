import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../state/friend_state.dart';
import '../state/profile_state.dart';
import '../models/user_profile_data.dart';
import '../models/friendship.dart';
import 'set_status_dialog.dart';
import 'notifications_page.dart';
import 'add_friend_page.dart';
import '../state/group_state.dart';
import 'create_group_page.dart';
// import '../models/user_group.dart';
import 'friend_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Profile & Friends',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsPage()),
              );
            },
          ),
        ],
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildMyProfileHeader(context),
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'FRIENDS'),
              Tab(text: 'GROUPS'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(context),
                _buildGroupsTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyProfileHeader(BuildContext context) {
    return Consumer<ProfileState>(
      builder: (context, profileState, child) {
        final profile = profileState.userProfile;
        if (profile == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 35,
                backgroundImage: NetworkImage(profile.photoURL),
                backgroundColor: Colors.white24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.firstName} ${profile.lastName}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${profile.username}',
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    if (profile.status.isNotEmpty &&
                        profile.status['text'] != null &&
                        (profile.status['text'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${profile.status['text']}',
                            style: GoogleFonts.inter(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (profile.occupation.isNotEmpty)
                      _buildProfileInfoRow(
                          Icons.work_outline, profile.occupation),
                    if (profile.location.isNotEmpty)
                      _buildProfileInfoRow(
                          Icons.location_on_outlined, profile.location),
                    if (profile.phoneNumber.isNotEmpty)
                      _buildProfileInfoRow(
                          Icons.phone_outlined, profile.phoneNumber),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.white, size: 20),
                onPressed: () {
                  // We will create a dialog to set the status
                  _showSetStatusDialog(context);
                },
                tooltip: 'Set Status',
              ),
              // Unified Add Friend/Group action
              PopupMenuButton<String>(
                tooltip: 'Add',
                icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white),
                onSelected: (value) {
                  if (value == 'friend') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddFriendPage()),
                    );
                  } else if (value == 'group') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateGroupPage()),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'friend', child: Text('Add Friend')),
                  const PopupMenuItem(value: 'group', child: Text('Create Group')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSetStatusDialog(BuildContext context) {
    showDialog(
      context: context,
      // Using a transparent barrier color allows our BackdropFilter to be visible
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) {
        return const SetStatusDialog();
      },
    );
  }

  Widget _buildFriendsTab(BuildContext context) {
  return Consumer<FriendState>(
    builder: (context, friendState, child) {
      if (friendState.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      final requests = friendState.pendingRequests;
      final friends = friendState.friendProfiles;

      if (requests.isEmpty && friends.isEmpty) {
        return Center(
          child: Text(
            'Search for friends to add them!',
            style: GoogleFonts.inter(color: Colors.white70),
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          // Section for "My Friends"
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text(
                'MY FRIENDS (${friends.length})',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              children: friends.map((friend) => _buildFriendTile(context, friend)).toList(),
            ),
          ),
          
          const Divider(color: Colors.white30, indent: 16, endIndent: 16),

          // Section for "Friend Requests"
          if (requests.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(
                  'FRIEND REQUESTS (${requests.length})',
                  style: GoogleFonts.inter(
                      color: Colors.orange.shade300, fontWeight: FontWeight.bold),
                ),
                children: requests.map((request) => _buildRequestTile(context, request, friendState)).toList(),
              ),
            ),
        ],
      );
    },
  );
}

  Widget _buildProfileInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(BuildContext context, UserProfileData friend) {
  return ListTile(
    leading: CircleAvatar(
      backgroundImage: NetworkImage(friend.photoURL),
    ),
    title: Text('${friend.firstName} ${friend.lastName}',
        style: const TextStyle(color: Colors.white)),
    subtitle: Text(
      (friend.status['text'] as String? ?? '').isNotEmpty
          ? friend.status['text']
          : '@${friend.username}',
      style: const TextStyle(color: Colors.white70),
      overflow: TextOverflow.ellipsis,
    ),
    trailing: IconButton(
      icon: const Icon(Icons.person_remove_alt_1, color: Colors.red),
      tooltip: 'Unfriend',
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Unfriend?'),
            content: Text('Remove ${friend.firstName} ${friend.lastName} from your friends?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Unfriend', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await context.read<FriendState>().removeFriendByUserId(friend.uid);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Removed ${friend.firstName} from friends')),
            );
          }
        }
      },
    ),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FriendProfilePage(friendProfile: friend),
        ),
      );
    },
  );
}

  Widget _buildRequestTile(BuildContext context, Friendship request, FriendState friendState) {
  // Find the full profile of the user who sent the request
  final requesterProfile = friendState.requesterProfiles.firstWhere(
    (profile) => profile.uid == request.requesterId,
    orElse: () => UserProfileData(uid: '', email: '', firstName: 'Unknown', lastName: 'User', username: '', occupation: '', location: '', phoneNumber: '', photoURL: ''),
  );

  return ListTile(
    leading: CircleAvatar(
      backgroundImage: NetworkImage(requesterProfile.photoURL),
      backgroundColor: Colors.white24,
    ),
    title: Text(
      '${requesterProfile.firstName} ${requesterProfile.lastName}',
      style: const TextStyle(color: Colors.white),
    ),
    subtitle: Text('@${requesterProfile.username}', style: TextStyle(color: Colors.white70)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check_circle, color: Colors.green),
          onPressed: () => friendState.acceptRequest(request.uid),
          tooltip: 'Accept',
        ),
        IconButton(
          icon: const Icon(Icons.cancel, color: Colors.red),
          onPressed: () => friendState.declineRequest(request.uid),
          tooltip: 'Decline',
        ),
      ],
    ),
  );
}

  Widget _buildGroupsTab(BuildContext context) {
  return Consumer<GroupState>(
    builder: (context, groupState, child) {
      if (groupState.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      final groups = groupState.groups;

      return Stack(
        children: [
          if (groups.isEmpty)
            const Center(
              child: Text('Create a group to share calendars!', style: TextStyle(color: Colors.white70)),
            )
          else
            ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return ListTile(
                  leading: CircleAvatar(
                    // You can add a photoURL to your Group model later
                    child: Text(group.name.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(group.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text('${group.members.length} members', style: const TextStyle(color: Colors.white70)),
                  onTap: () {
                    // TODO: Navigate to a Group Detail Page
                  },
                );
              },
            ),
          // Group creation is accessible from the Add menu in the app bar
        ],
      );
    },
  );
}
}
