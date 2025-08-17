import 'package:flutter/material.dart';
import '../../Theme/app_styles.dart';

enum DialogType { info, warning, error, success, custom }

class AppDialog extends StatelessWidget {
  final String title;
  final String? content;
  final Widget? contentWidget;
  final IconData? icon;
  final DialogType type;
  final List<DialogAction> actions;
  final AppStyleConfig? customStyle;
  
  const AppDialog({
    super.key,
    required this.title,
    this.content,
    this.contentWidget,
    this.icon,
    this.type = DialogType.info,
    this.actions = const [],
    this.customStyle,
  });

  @override
  Widget build(BuildContext context) {
    final style = customStyle ?? GlassmorphismStyleConfig();
    
    return _buildWithEffect(
      style,
      AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: style.dialogDecoration(),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: _getIconColor(style),
                  size: 40,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: style.headingStyle,
              ),
              if (content != null || contentWidget != null) ...[
                const SizedBox(height: 12),
                contentWidget ?? Text(
                  content!,
                  textAlign: TextAlign.center,
                  style: style.bodyStyle,
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildActions(style),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildWithEffect(AppStyleConfig style, Widget child) {
    if (style.backgroundEffect != null) {
      return style.backgroundEffect!(child);
    }
    return child;
  }
  
  Color _getIconColor(AppStyleConfig style) {
    switch (type) {
      case DialogType.warning:
        return style.warningColor;
      case DialogType.error:
        return style.errorColor;
      case DialogType.success:
        return style.successColor;
      case DialogType.info:
      case DialogType.custom:
      default:
        return style.primaryColor;
    }
  }
  
  Widget _buildActions(AppStyleConfig style) {
    if (actions.length == 1) {
      return SizedBox(
        width: double.infinity,
        child: actions.first.build(style),
      );
    }
    
    if (actions.length == 2) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((action) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: action.build(style),
          ),
        )).toList(),
      );
    }
    
    // Multiple actions - vertical layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: actions.asMap().entries.map((entry) {
        final isLast = entry.key == actions.length - 1;
        return Column(
          children: [
            entry.value.build(style),
            if (!isLast) const SizedBox(height: 10),
          ],
        );
      }).toList(),
    );
  }
}

abstract class DialogAction {
  Widget build(AppStyleConfig style);
}

class PrimaryDialogAction extends DialogAction {
  final String text;
  final VoidCallback onPressed;
  final Color? customColor;
  
  PrimaryDialogAction({
    required this.text,
    required this.onPressed,
    this.customColor,
  });
  
  @override
  Widget build(AppStyleConfig style) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: style.onSurfaceColor,
        backgroundColor: customColor ?? style.primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(text, style: style.buttonStyle),
    );
  }
}

class SecondaryDialogAction extends DialogAction {
  final String text;
  final VoidCallback onPressed;
  
  SecondaryDialogAction({
    required this.text,
    required this.onPressed,
  });
  
  @override
  Widget build(AppStyleConfig style) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        text,
        style: style.bodyStyle,
      ),
    );
  }
}

class IconDialogAction extends DialogAction {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  
  IconDialogAction({
    required this.text,
    required this.icon,
    required this.onPressed,
    this.color,
  });
  
  @override
  Widget build(AppStyleConfig style) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(text),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: style.onSurfaceColor,
        backgroundColor: color ?? style.primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

// Utility class for showing common dialogs
class DialogHelper {
  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    DialogType type = DialogType.warning,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        content: content,
        type: type,
        icon: icon,
        actions: [
          SecondaryDialogAction(
            text: cancelText,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PrimaryDialogAction(
            text: confirmText,
            onPressed: () => Navigator.of(context).pop(true),
            customColor: type == DialogType.error 
              ? context.appStyle.errorColor 
              : null,
          ),
        ],
      ),
    );
  }
  
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String content,
    String buttonText = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        content: content,
        type: DialogType.info,
        icon: Icons.info_outline,
        actions: [
          PrimaryDialogAction(
            text: buttonText,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}