import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../state/profile_state.dart';
import '../widgets/background_container.dart';
import '../Theme/app_styles.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  final List<String> presetImages = [
    'assets/img/background.jpg',
    'assets/img/preset1.jpg',
    'assets/img/preset2.jpg',
    'assets/img/preset3.jpg',
  ];

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Appearance',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildAppearanceSection(context),
            const SizedBox(height: 24),
            _buildThemeSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text(
            'App Theme',
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          leading: const Icon(Icons.color_lens_outlined, color: Colors.white),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildThemeChoice(
                    type: ThemeType.glassmorphism,
                    label: 'Glassmorphism',
                    imageAsset: 'assets/img/preset1.jpg',
                  ),
                  const SizedBox(height: 16),
                  _buildThemeChoice(
                    type: ThemeType.light,
                    label: 'Light',
                    imageAsset: 'assets/img/preset2.jpg',
                  ),
                  const SizedBox(height: 16),
                  _buildThemeChoice(
                    type: ThemeType.dark,
                    label: 'Dark',
                    imageAsset: 'assets/img/preset3.jpg',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeChoice({
    required ThemeType type,
    required String label,
    required String imageAsset,
  }) {
    final styleProvider = Provider.of<AppStyleProvider>(context);
    final bool isSelected = styleProvider.currentThemeType == type;

    return GestureDetector(
      onTap: () {
        styleProvider.updateTheme(type);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? context.appStyle.primaryColor
                : Colors.white.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                imageAsset,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Text(label, style: context.appStyle.subheadingStyle),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: context.appStyle.primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    final profileState = Provider.of<ProfileState>(context);
    final currentBackground = profileState.userProfile?.backgroundImage ?? presetImages.first;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text(
            'Background Image',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          leading: CircleAvatar(
            backgroundImage: (currentBackground.startsWith('http')
                ? NetworkImage(currentBackground)
                : AssetImage(currentBackground)) as ImageProvider,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 12.0,
                runSpacing: 12.0,
                children: presetImages.map((imagePath) {
                  return GestureDetector(
                    onTap: () {
                      profileState.setPresetBackground(imagePath);
                    },
                    child: Container(
                      width: (MediaQuery.of(context).size.width - 64) / 2.2,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: AssetImage(imagePath),
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(
                          color: currentBackground == imagePath
                              ? Colors.blue
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(color: Colors.white30),
            ListTile(
              leading: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_photo_alternate_outlined, color: Colors.white),
              title: Text(
                'Choose from Library',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              onTap: _isLoading ? null : () async {
                setState(() => _isLoading = true);
                await context.read<ProfileState>().setCustomBackground();
                if(mounted) {
                  setState(() => _isLoading = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}