import 'package:flutter/material.dart';
import '../../Theme/app_styles.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonType type;
  final Color? customColor;
  final EdgeInsetsGeometry? padding;
  final AppStyleConfig? customStyle;
  
  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.type = AppButtonType.primary,
    this.customColor,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
    this.customStyle,
  });

  @override
  Widget build(BuildContext context) {
    final style = customStyle ?? context.appStyle;
    
    Widget button;
    
    switch (type) {
      case AppButtonType.primary:
        button = _buildElevatedButton(style);
        break;
      case AppButtonType.secondary:
        button = _buildTextButton(style);
        break;
      case AppButtonType.outlined:
        button = _buildOutlinedButton(style);
        break;
    }
    
    return button;
  }
  
  Widget _buildElevatedButton(AppStyleConfig style) {
    if (icon != null) {
      return ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(text),
        onPressed: onPressed,
        style: _getElevatedButtonStyle(style),
      );
    }
    
    return ElevatedButton(
      onPressed: onPressed,
      style: _getElevatedButtonStyle(style),
      child: Text(text, style: style.buttonStyle),
    );
  }
  
  Widget _buildTextButton(AppStyleConfig style) {
    if (icon != null) {
      return TextButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(text),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: style.onSurfaceColor,
          padding: padding,
        ),
      );
    }
    
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: style.onSurfaceColor,
        padding: padding,
      ),
      child: Text(text, style: style.bodyStyle),
    );
  }
  
  Widget _buildOutlinedButton(AppStyleConfig style) {
    if (icon != null) {
      return OutlinedButton.icon(
        icon: Icon(icon),
        label: Text(text),
        onPressed: onPressed,
        style: _getOutlinedButtonStyle(style),
      );
    }
    
    return OutlinedButton(
      onPressed: onPressed,
      style: _getOutlinedButtonStyle(style),
      child: Text(text, style: style.buttonStyle),
    );
  }
  
  ButtonStyle _getElevatedButtonStyle(AppStyleConfig style) {
    return ElevatedButton.styleFrom(
      foregroundColor: style.onSurfaceColor,
      backgroundColor: customColor ?? style.primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: padding,
    );
  }
  
  ButtonStyle _getOutlinedButtonStyle(AppStyleConfig style) {
    return OutlinedButton.styleFrom(
      foregroundColor: customColor ?? style.primaryColor,
      side: BorderSide(color: customColor ?? style.primaryColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: padding,
    );
  }
}

enum AppButtonType { primary, secondary, outlined }

// Specialized button widgets for common use cases
class EditButton extends AppButton {
  EditButton({
    super.key,
    required super.onPressed,
    AppStyleConfig? customStyle,
  }) : super(
        text: 'Edit',
        icon: Icons.edit_outlined,
        type: AppButtonType.secondary,
        customStyle: customStyle,
      );
}

class DeleteButton extends AppButton {
  DeleteButton({
    super.key,
    required super.onPressed,
    AppStyleConfig? customStyle,
  }) : super(
        text: 'Delete',
        icon: Icons.delete_outline,
        type: AppButtonType.secondary,
        customStyle: customStyle,
        customColor: (customStyle ?? GlassmorphismStyleConfig()).errorColor,
      );
}