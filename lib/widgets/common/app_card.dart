import 'package:flutter/material.dart';
import '../../Theme/app_styles.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;
  final AppStyleConfig? customStyle;
  
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 4),
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    this.customStyle,
  });

  @override
  Widget build(BuildContext context) {
    final style = customStyle ?? context.appStyle;
    
    Widget cardWidget = Container(
      margin: margin,
      padding: padding,
      decoration: style.cardDecoration().copyWith(
        border: Border.all(
          color: borderColor ?? style.borderColor,
        ),
        color: backgroundColor ?? style.cardDecoration().color,
      ),
      child: child,
    );
    
    if (onTap != null) {
      cardWidget = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(style.borderRadius),
        child: cardWidget,
      );
    }
    
    return cardWidget;
  }
}

class EventCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? timeText;
  final Color accentColor;
  final List<Widget>? tags;
  final List<Widget>? actions;
  final VoidCallback? onTap;
  final AppStyleConfig? customStyle;
  
  const EventCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.timeText,
    required this.accentColor,
    this.tags,
    this.actions,
    this.onTap,
    this.customStyle,
  });

  @override
  Widget build(BuildContext context) {
    final style = customStyle ?? context.appStyle;
    
    return AppCard(
      onTap: onTap,
      customStyle: style,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 8,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tags != null) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: tags!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    title,
                    style: style.headingStyle.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: style.bodyStyle),
                  if (timeText != null) ...[
                    const SizedBox(height: 4),
                    Text(timeText!, style: style.bodyStyle),
                  ],
                  if (actions != null) ...[
                    const Divider(height: 24, color: Colors.white30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final String title;
  final String? description;
  final bool isCompleted;
  final VoidCallback? onToggle;
  final Widget? trailingWidget;
  final AppStyleConfig? customStyle;
  
  const TaskCard({
    super.key,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.onToggle,
    this.trailingWidget,
    this.customStyle,
  });

  @override
  Widget build(BuildContext context) {
    final style = customStyle ?? context.appStyle;
    
    return AppCard(
      customStyle: style,
      child: Row(
        children: [
          Transform.scale(
            scale: 1.2,
            child: Checkbox(
              value: isCompleted,
              onChanged: onToggle != null ? (val) => onToggle!() : null,
              shape: const CircleBorder(),
              activeColor: style.primaryColor,
              checkColor: Colors.black,
              side: BorderSide(color: style.onSurfaceColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: style.subheadingStyle.copyWith(
                    color: isCompleted 
                      ? style.onSurfaceColor.withValues(alpha: 0.5)
                      : style.onSurfaceColor,
                    decoration: isCompleted 
                      ? TextDecoration.lineThrough 
                      : TextDecoration.none,
                  ),
                ),
                if (description != null && description!.isNotEmpty)
                  Text(
                    description!,
                    style: style.bodyStyle,
                  ),
              ],
            ),
          ),
          if (trailingWidget != null) trailingWidget!,
        ],
      ),
    );
  }
}