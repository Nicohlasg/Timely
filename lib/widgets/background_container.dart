import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/profile_state.dart';

class BackgroundImageContainer extends StatelessWidget {
  final Widget child;

  const BackgroundImageContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Watch ProfileState for changes to the background image
    final profileState = context.watch<ProfileState>();
    final userProfile = profileState.userProfile;

    // Determine the image path. Use default if profile is null or background is not set.
    final String imagePath = userProfile?.backgroundImage ?? 'assets/img/background.jpg';

    // Decide if it's a network image (from Firebase Storage) or a local asset
    final bool isNetworkImage = imagePath.startsWith('http');

    final imageProvider = isNetworkImage
        ? NetworkImage(imagePath)
        : AssetImage(imagePath);

    return Stack(
      children: [
        // The background image itself
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: imageProvider as ImageProvider,
              fit: BoxFit.cover,
              onError: (exception, stackTrace) {
                print('Error loading background image: $exception');
                // You could show a fallback color or image here
              },
            ),
          ),
        ),
        // The blur effect
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withValues(alpha: 0.1)),
        ),
        // The actual page content provided as a child
        child,
      ],
    );
  }
}