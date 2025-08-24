import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../login_page/login_page.dart';
import '../login_page/register_page.dart';
import '../widgets/background_container.dart';
import '../Theme/app_styles.dart';
import '../widgets/common/bouncy_button.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _registerData = RegisterData();
  ThemeType _selectedTheme = ThemeType.glassmorphism;
  DateTime? _dateOfBirth;
  bool _showDobPicker = false;
  String? _selectedPurpose;

  // State for animations
  bool _isWelcomeTextVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isWelcomeTextVisible = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> onboardingSteps = [
      _buildWelcomeStep(),
      _buildNameStep(),
      _buildUsernameStep(),
      _buildEmailPasswordStep(),
      _buildThemeStep(),
      _buildDobStep(),
      _buildPurposeStep(),
    ];

    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: onboardingSteps,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _skipOnboarding,
                      child: Text('Skip', style: context.appStyle.bodyStyle),
                    ),
                    BouncyButton(
                      onPressed: () {
                        if (_currentPage < onboardingSteps.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _finishOnboarding();
                        }
                      },
                      child: ElevatedButton(
                        onPressed: null, // onPressed is handled by the wrapper
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.appStyle.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                            _currentPage < onboardingSteps.length - 1
                                ? 'Next'
                                : 'Finish',
                            style: context.appStyle.buttonStyle),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _skipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  void _finishOnboarding() async {
    // Set data on the RegisterData instance
    _registerData
        .setName('${_firstNameController.text} ${_lastNameController.text}');
    _registerData.setUsername(_usernameController.text);
    _registerData.setEmail(_emailController.text);
    _registerData.setPassword(_passwordController.text);
    // For simplicity, I'll set confirmPassword to be the same.
    _registerData.setConfirmPassword(_passwordController.text);

    final String? error = await _registerData.signUp();

    if (mounted) {
      if (error == null) {
        // Success
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_completed_onboarding', true);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => const LoginPage(showTutorial: true)),
        );
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }
  }

  Widget _buildUsernameStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Choose a username.",
            style: context.appStyle.headingStyle.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            "Make it unique and memorable!",
            style: context.appStyle.bodyStyle,
          ),
          const SizedBox(height: 32),
          _buildOnboardingTextField(
            controller: _usernameController,
            label: 'Username',
          ),
        ],
      ),
    );
  }

  Widget _buildEmailPasswordStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Secure your account.",
            style: context.appStyle.headingStyle.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll use this to log you in.",
            style: context.appStyle.bodyStyle,
          ),
          const SizedBox(height: 32),
          _buildOnboardingTextField(
            controller: _emailController,
            label: 'Email Address',
          ),
          const SizedBox(height: 16),
          _buildOnboardingTextField(
            controller: _passwordController,
            label: 'Password',
          ),
        ],
      ),
    );
  }

  Widget _buildThemeStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Choose your theme.",
            style: context.appStyle.headingStyle.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            "Make the app feel like yours.",
            style: context.appStyle.bodyStyle,
          ),
          const SizedBox(height: 32),
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
    );
  }

  Widget _buildThemeChoice({
    required ThemeType type,
    required String label,
    required String imageAsset,
  }) {
    final bool isSelected = _selectedTheme == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTheme = type;
        });
        context.read<AppStyleProvider>().updateTheme(type);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? context.appStyle.primaryColor : Colors.white30,
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

  Widget _buildDobStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "When were you born?",
            style: context.appStyle.headingStyle.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            "This helps us personalize your experience (and we'll wish you a happy birthday!).",
            style: context.appStyle.bodyStyle,
          ),
          const SizedBox(height: 32),
          _buildPickerButton(
            text: _dateOfBirth == null
                ? 'Select a date'
                : DateFormat('d MMMM yyyy').format(_dateOfBirth!),
            isActive: _showDobPicker,
            onPressed: () {
              setState(() {
                _showDobPicker = !_showDobPicker;
              });
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showDobPicker
                ? _buildInlineDatePicker()
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required String text,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: isActive
            ? context.appStyle.primaryColor.withOpacity(0.8)
            : Colors.white.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        minimumSize: const Size(double.infinity, 50),
      ),
      child: Text(
        text,
        style: context.appStyle.bodyStyle.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInlineDatePicker() {
    return TableCalendar(
      firstDay: DateTime.utc(1920),
      lastDay: DateTime.now(),
      focusedDay:
          _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
      selectedDayPredicate: (day) =>
          _dateOfBirth != null ? isSameDay(day, _dateOfBirth!) : false,
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _dateOfBirth = selectedDay;
          _showDobPicker = false;
        });
      },
      calendarStyle: CalendarStyle(
        defaultTextStyle: const TextStyle(color: Colors.white),
        weekendTextStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        outsideTextStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        selectedDecoration: BoxDecoration(
          color: context.appStyle.primaryColor,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: context.appStyle.headingStyle.copyWith(fontSize: 16),
        leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
        rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: const TextStyle(color: Colors.white70),
        weekendStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildPurposeStep() {
    final List<String> purposes = [
      'School',
      'Work',
      'Personal',
      'Family & Friends'
    ];
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "How will you use Timely?",
            style: context.appStyle.headingStyle.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            "Select your primary purpose.",
            style: context.appStyle.bodyStyle,
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children: purposes.map((purpose) {
              final bool isSelected = _selectedPurpose == purpose;
              return ChoiceChip(
                label: Text(purpose),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedPurpose = purpose;
                  });
                },
                selectedColor: context.appStyle.primaryColor,
                labelStyle: context.appStyle.bodyStyle.copyWith(
                  color:
                      isSelected ? Colors.white : context.appStyle.onSurfaceColor,
                ),
                backgroundColor: Colors.white.withOpacity(0.1),
                side: const BorderSide(color: Colors.white30),
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedOpacity(
            opacity: _isWelcomeTextVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 800),
            child: Text(
              'Welcome to Timely',
              style: context.appStyle.headingStyle.copyWith(fontSize: 42),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedPadding(
            padding: EdgeInsets.only(left: _isWelcomeTextVisible ? 0 : 40),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _isWelcomeTextVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              child: Text(
                'Your personal, intelligent calendar designed to bring order to your life.',
                style: context.appStyle.subheadingStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What should we call you?",
            style: context.appStyle.headingStyle.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            "Don't worry, your details are safe with us.",
            style: context.appStyle.bodyStyle,
          ),
          const SizedBox(height: 32),
          _buildOnboardingTextField(
            controller: _firstNameController,
            label: 'First Name',
          ),
          const SizedBox(height: 16),
          _buildOnboardingTextField(
            controller: _lastNameController,
            label: 'Last Name',
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      style: context.appStyle.bodyStyle.copyWith(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.appStyle.bodyStyle.copyWith(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
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
          borderSide: BorderSide(color: context.appStyle.primaryColor),
        ),
      ),
    );
  }

  Widget _buildStepPlaceholder(
      {required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.appStyle.headingStyle.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: context.appStyle.subheadingStyle,
          ),
        ],
      ),
    );
  }
}
