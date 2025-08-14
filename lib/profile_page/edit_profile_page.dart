import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_profile_data.dart';
import '../state/profile_state.dart';
import '../widgets/background_container.dart';

class EditProfilePage extends StatefulWidget {
  final UserProfileData userProfile;

  const EditProfilePage({super.key, required this.userProfile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _usernameController;
  late TextEditingController _occupationController;
  late TextEditingController _locationController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.userProfile.firstName,
    );
    _lastNameController = TextEditingController(
      text: widget.userProfile.lastName,
    );
    _usernameController = TextEditingController(
      text: widget.userProfile.username,
    );
    _occupationController = TextEditingController(
      text: widget.userProfile.occupation,
    );
    _locationController = TextEditingController(
      text: widget.userProfile.location,
    );
    _phoneController = TextEditingController(
      text: widget.userProfile.phoneNumber,
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _occupationController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final updatedProfile = UserProfileData(
      uid: widget.userProfile.uid,
      email: widget.userProfile.email,
      photoURL: widget.userProfile.photoURL,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      username: _usernameController.text,
      occupation: _occupationController.text,
      location: _locationController.text,
      phoneNumber: _phoneController.text,
    );

    context.read<ProfileState>().updateProfile(updatedProfile);

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Edit Profile',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: _saveProfile,
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: <Widget>[
              const SizedBox(height: 24),
              _buildInputField(
                label: 'First Name',
                controller: _firstNameController,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                label: 'Last Name',
                controller: _lastNameController,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                label: 'Username',
                controller: _usernameController,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                label: 'Occupation',
                controller: _occupationController,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                label: 'Location',
                controller: _locationController,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                label: 'Phone Number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
        ),
      ],
    );
  }
}
