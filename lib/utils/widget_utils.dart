import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Common widget utilities and builders
class WidgetUtils {
  
  /// Creates a consistent divider with opacity
  static Widget buildDivider({
    double height = 24,
    Color color = Colors.white30,
  }) {
    return Divider(height: height, color: color);
  }
  
  /// Creates a consistent spacer
  static Widget buildSpacer({double height = 16}) {
    return SizedBox(height: height);
  }
  
  /// Creates a horizontal spacer
  static Widget buildHorizontalSpacer({double width = 16}) {
    return SizedBox(width: width);
  }
  
  /// Builds a consistent section header with optional action
  static Widget buildSectionHeader(
    String title, {
    VoidCallback? onActionPressed,
    String actionText = 'View All',
    TextStyle? titleStyle,
    TextStyle? actionStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: titleStyle ?? GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onActionPressed != null)
            TextButton(
              onPressed: onActionPressed,
              child: Text(
                actionText,
                style: actionStyle ?? GoogleFonts.inter(
                  color: Colors.blue.shade300,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Creates a loading indicator with optional message
  static Widget buildLoadingIndicator({
    String? message,
    Color color = Colors.white,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: color),
          if (message != null) ...[
            buildSpacer(height: 12),
            Text(
              message,
              style: GoogleFonts.inter(color: color.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
  
  /// Creates an empty state widget
  static Widget buildEmptyState({
    required String message,
    IconData? icon,
    String? actionText,
    VoidCallback? onActionPressed,
    Color textColor = Colors.white70,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 64, color: textColor.withValues(alpha: 0.5)),
              buildSpacer(height: 16),
            ],
            Text(
              message,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onActionPressed != null) ...[
              buildSpacer(height: 16),
              TextButton(
                onPressed: onActionPressed,
                child: Text(
                  actionText,
                  style: GoogleFonts.inter(color: Colors.blue.shade300),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// Creates a badge widget
  static Widget buildBadge({
    required Widget child,
    required String text,
    Color backgroundColor = Colors.red,
    Color textColor = Colors.white,
    bool showBadge = true,
  }) {
    if (!showBadge) return child;
    
    return Badge(
      label: Text(text),
      backgroundColor: backgroundColor,
      textColor: textColor,
      child: child,
    );
  }
  
  /// Creates a shimmer loading effect placeholder
  static Widget buildShimmerPlaceholder({
    double? width,
    double? height = 20,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
    );
  }
  
  /// Creates a consistent app bar
  static AppBar buildAppBar({
    required String title,
    List<Widget>? actions,
    Widget? leading,
    bool automaticallyImplyLeading = false,
    bool centerTitle = true,
    Color backgroundColor = Colors.transparent,
    double elevation = 0,
    TextStyle? titleStyle,
  }) {
    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      title: Text(
        title,
        style: titleStyle ?? GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      elevation: elevation,
      actions: actions,
    );
  }
  
  /// Creates a scroll behavior without scrollbar
  static ScrollBehavior noScrollbarBehavior() {
    return _NoScrollbarBehavior();
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}