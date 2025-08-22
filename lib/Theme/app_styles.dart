import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';

// Base style configuration that can be extended for different themes
abstract class AppStyleConfig {
  // Colors
  Color get primaryColor;
  Color get backgroundColor;
  Color get accentColor;
  Color get surfaceColor;
  Color get onSurfaceColor;
  Color get borderColor;
  Color get errorColor;
  Color get warningColor;
  Color get successColor;
  
  // Text Styles
  TextStyle get headingStyle;
  TextStyle get subheadingStyle; 
  TextStyle get bodyStyle;
  TextStyle get captionStyle;
  TextStyle get buttonStyle;
  
  // Container Decorations
  BoxDecoration dialogDecoration();
  BoxDecoration cardDecoration();
  BoxDecoration containerDecoration();
  
  // Effects
  Widget Function(Widget child)? get backgroundEffect;
  double get borderRadius;
  double get elevation;
}

// Glassmorphism style (current default)
class GlassmorphismStyleConfig extends AppStyleConfig {
  @override
  Color get primaryColor => const Color.fromARGB(255, 115, 182, 221);
  
  @override
  Color get backgroundColor => const Color(0xFFF0F2F5);
  
  @override
  Color get accentColor => const Color.fromARGB(255, 174, 136, 244);
  
  @override
  Color get surfaceColor => const Color(0xFF2D3748);
  
  @override
  Color get onSurfaceColor => Colors.white;
  
  @override
  Color get borderColor => Colors.white30;
  
  @override
  Color get errorColor => Colors.red.shade300;
  
  @override
  Color get warningColor => Colors.orange.shade300;
  
  @override
  Color get successColor => Colors.green.shade300;
  
  @override
  TextStyle get headingStyle => GoogleFonts.inter(
    color: onSurfaceColor,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );
  
  @override
  TextStyle get subheadingStyle => GoogleFonts.inter(
    color: onSurfaceColor.withValues(alpha: 0.8),
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  
  @override
  TextStyle get bodyStyle => GoogleFonts.inter(
    color: onSurfaceColor.withValues(alpha: 0.7),
    fontSize: 14,
  );
  
  @override
  TextStyle get captionStyle => GoogleFonts.inter(
    color: onSurfaceColor.withValues(alpha: 0.6),
    fontSize: 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );
  
  @override
  TextStyle get buttonStyle => GoogleFonts.inter(
    color: onSurfaceColor,
    fontWeight: FontWeight.bold,
  );
  
  @override
  BoxDecoration dialogDecoration() => BoxDecoration(
    color: surfaceColor.withValues(alpha: 0.95),
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(color: borderColor),
  );
  
  @override
  BoxDecoration cardDecoration() => BoxDecoration(
    color: onSurfaceColor.withValues(alpha: 0.2),
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(color: borderColor),
  );
  
  @override
  BoxDecoration containerDecoration() => BoxDecoration(
    color: onSurfaceColor.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(color: borderColor),
  );
  
  @override
  Widget Function(Widget child)? get backgroundEffect => (child) => BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
    child: child,
  );
  
  @override
  double get borderRadius => 20.0;
  
  @override
  double get elevation => 8.0;
}

// Style provider for easy access throughout the app
class AppStyleProvider extends ChangeNotifier {
  AppStyleConfig _currentStyle = GlassmorphismStyleConfig();
  
  AppStyleConfig get currentStyle => _currentStyle;
  
  // Future: This will allow users to switch styles
  void updateStyle(AppStyleConfig newStyle) {
    _currentStyle = newStyle;
    notifyListeners();
  }
}

// Extension for easy context access
extension StyleContext on BuildContext {
  AppStyleConfig get appStyle => AppStyleProvider().currentStyle;
}