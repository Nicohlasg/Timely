import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_profile_data.dart';
import '../state/friend_state.dart';
import '../widgets/background_container.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final TextEditingController _searchController = TextEditingController();
  List<UserProfileData> _searchResults = [];
  bool _isLoading = false;
  String _lastQuery = '';
  final Set<String> _sentRequests = {}; // Track requests sent in this session
  List<UserProfileData> _currentFriends = [];

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query == _lastQuery) return;

    setState(() {
      _isLoading = true;
      _lastQuery = query;
    });

    // Get dynamic results based on prefix query
    final results = query.isEmpty
        ? <UserProfileData>[]
        : await context.read<FriendState>().searchUsers(query);

    if (!mounted) return;

    // Filter out already-friends and self
    final friendIds = _currentFriends.map((u) => u.uid).toSet();
    setState(() {
      _searchResults = results.where((u) => !friendIds.contains(u.uid)).toList();
      _isLoading = false;
    });
  }

  Future<void> _sendRequest(String recipientId) async {
    await context.read<FriendState>().sendFriendRequest(recipientId);
    setState(() {
      _sentRequests.add(recipientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    _currentFriends = context.watch<FriendState>().friendProfiles;
    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Add Friends or Groups', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildResultsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by email or username...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: _searchUsers,
          ),
        ),
        onChanged: (_) => _searchUsers(),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_searchResults.isEmpty) {
      if (_lastQuery.isEmpty) {
        // Show current friends as a selectable list (disabled add buttons)
        final friends = _currentFriends;
        if (friends.isEmpty) {
          return const Center(child: Text('No friends yet. Start searching above.', style: TextStyle(color: Colors.white70)));
        }
        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final user = friends[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(user.photoURL),
                backgroundColor: Colors.white24,
              ),
              title: Text('${user.firstName} ${user.lastName}', style: const TextStyle(color: Colors.white)),
              subtitle: Text('@${user.username}', style: const TextStyle(color: Colors.white70)),
              trailing: const Text('Friend', style: TextStyle(color: Colors.white54)),
            );
          },
        );
      }
      return const Center(child: Text('No users found.', style: TextStyle(color: Colors.white70)));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isRequestSent = _sentRequests.contains(user.uid);
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(user.photoURL),
            backgroundColor: Colors.white24,
          ),
          title: Text('${user.firstName} ${user.lastName}', style: const TextStyle(color: Colors.white)),
          subtitle: Text('@${user.username}', style: const TextStyle(color: Colors.white70)),
          trailing: ElevatedButton(
            onPressed: isRequestSent ? null : () => _sendRequest(user.uid),
            style: ElevatedButton.styleFrom(
              backgroundColor: isRequestSent ? Colors.grey : Colors.blue,
            ),
            child: Text(isRequestSent ? 'Pending' : 'Add'),
          ),
        );
      },
    );
  }
}