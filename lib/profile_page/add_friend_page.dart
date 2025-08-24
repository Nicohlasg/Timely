import 'package:cloud_firestore/cloud_firestore.dart'; // Add this line
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/friendship.dart';
import '../models/user_profile_data.dart';
import '../state/friend_state.dart';
import '../widgets/background_container.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

// Enum to represent the UI state of the friendship status
enum UIStatus { none, friend, pending, blocked }

class _AddFriendPageState extends State<AddFriendPage> {
  final TextEditingController _searchController = TextEditingController();
  List<UserProfileData> _searchResults = [];
  bool _isLoading = false;
  String _lastQuery = '';
  final Set<String> _sendingRequests = {}; // Track in-flight requests

  @override
  void initState() {
    super.initState();
    // Add listener to clear search results when the user types
    _searchController.addListener(() {
      if (_searchController.text.isEmpty && _searchResults.isNotEmpty) {
        setState(() {
          _searchResults = [];
          _lastQuery = '';
        });
      }
    });
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    if (query == _lastQuery) return;

    setState(() {
      _isLoading = true;
      _lastQuery = query;
    });

    final results = await context.read<FriendState>().searchUsers(query);
    if (!mounted) return;

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }

  Future<void> _sendRequest(String recipientId) async {
    setState(() => _sendingRequests.add(recipientId));
    try {
      await context.read<FriendState>().sendFriendRequest(recipientId);
      // The stream provided by FriendState will automatically update the UI to "Pending"
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending request: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingRequests.remove(recipientId));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendState = context.watch<FriendState>();

    UIStatus getUiStatus(String userId) {
      // Use the comprehensive list of all friendships from the state
      final friendship = friendState.allFriendships.firstWhere( // Use allFriendships here
        (f) => f.users.contains(userId),
        orElse: () => Friendship(uid: '', users: [], requesterId: '', status: FriendshipStatus.declined, createdAt: Timestamp.now()), // Return a default non-functional friendship
      );

      switch (friendship.status) {
        case FriendshipStatus.accepted:
          return UIStatus.friend;
        case FriendshipStatus.pending:
          return UIStatus.pending;
        case FriendshipStatus.blocked:
          return UIStatus.blocked;
        default:
          return UIStatus.none;
      }
    }

    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Add Friends', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildResultsList(getUiStatus),
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
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: IconButton(
            icon: const Icon(Icons.send, color: Colors.white70),
            onPressed: _searchUsers,
          ),
        ),
        onSubmitted: (_) => _searchUsers(),
      ),
    );
  }

  Widget _buildResultsList(UIStatus Function(String) getUiStatus) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          _lastQuery.isEmpty ? 'Search for users to add.' : 'No users found.',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final status = getUiStatus(user.uid);
        final bool isSending = _sendingRequests.contains(user.uid);

        Widget trailing;
        if (isSending) {
          trailing = const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          );
        } else {
          switch (status) {
            case UIStatus.friend:
              trailing = const Text('Friend', style: TextStyle(color: Colors.white54));
              break;
            case UIStatus.pending:
              trailing = const Text('Pending', style: TextStyle(color: Colors.grey));
              break;
            case UIStatus.blocked:
              trailing = const Text('Blocked', style: TextStyle(color: Colors.redAccent));
              break;
            case UIStatus.none:
              trailing = ElevatedButton(
                onPressed: () => _sendRequest(user.uid),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Add'),
              );
              break;
          }
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.photoURL.isNotEmpty ? NetworkImage(user.photoURL) : null,
            backgroundColor: Colors.white24,
            child: user.photoURL.isEmpty ? const Icon(Icons.person, color: Colors.white70) : null,
          ),
          title: Text(
            '${user.firstName} ${user.lastName}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '@${user.username}',
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: trailing,
          ),
        );
      },
    );
  }
}
