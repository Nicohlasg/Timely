import 'package:flutter/material.dart';
import '../../Theme/app_styles.dart';

class AppTag extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final AppStyleConfig? customStyle;
  
  const AppTag({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.customStyle,
  });

  @override
  Widget build(BuildContext context) {
    final style = customStyle ?? context.appStyle;
    
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.blue.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: style.captionStyle.copyWith(
          fontSize: 10,
          color: textColor ?? Colors.black.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// Preset tag types for common use cases
class PriorityTag extends AppTag {
  PriorityTag.high({super.key, AppStyleConfig? customStyle}) 
    : super(
        text: 'HIGH',
        backgroundColor: Colors.red.shade100,
        customStyle: customStyle,
      );
  
  PriorityTag.medium({super.key, AppStyleConfig? customStyle}) 
    : super(
        text: 'MEDIUM', 
        backgroundColor: Colors.orange.shade100,
        customStyle: customStyle,
      );
  
  PriorityTag.low({super.key, AppStyleConfig? customStyle}) 
    : super(
        text: 'LOW',
        backgroundColor: Colors.green.shade100,
        customStyle: customStyle,
      );
}

class DurationTag extends AppTag {
  DurationTag({
    super.key,
    required Duration duration,
    AppStyleConfig? customStyle,
  }) : super(
        text: _formatDuration(duration),
        backgroundColor: Colors.orange.shade100,
        customStyle: customStyle,
      );
  
  static String _formatDuration(Duration duration) {
    if (duration.inHours >= 1) {
      return "${duration.inHours} HOURS";
    } else {
      return "${duration.inMinutes} MINS";
    }
  }
}

class LocationTag extends AppTag {
  LocationTag({
    super.key,
    AppStyleConfig? customStyle,
  }) : super(
        text: 'IN-PERSON',
        backgroundColor: Colors.blue.shade100,
        customStyle: customStyle,
      );
}

class StatusTag extends AppTag {
  StatusTag.poll({super.key, AppStyleConfig? customStyle}) 
    : super(
        text: 'POLL',
        backgroundColor: Colors.cyan.shade100,
        customStyle: customStyle,
      );
  
  StatusTag.now({super.key, AppStyleConfig? customStyle}) 
    : super(
        text: 'NOW',
        backgroundColor: Colors.purple.shade100,
        customStyle: customStyle,
      );
}