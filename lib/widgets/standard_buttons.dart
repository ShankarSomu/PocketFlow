import 'package:flutter/material.dart';
import '../core/app_constants.dart';

/// Standardized button sizes
enum ButtonSize {
  small(
    height: 32.0,
    padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
    fontSize: 12.0,
    iconSize: 16.0,
  ),
  medium(
    height: 40.0,
    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
    fontSize: 14.0,
    iconSize: 18.0,
  ),
  large(
    height: 48.0,
    padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
    fontSize: 16.0,
    iconSize: 20.0,
  ),
  extraLarge(
    height: 56.0,
    padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
    fontSize: 18.0,
    iconSize: 24.0,
  );

  final double height;
  final EdgeInsets padding;
  final double fontSize;
  final double iconSize;

  const ButtonSize({
    required this.height,
    required this.padding,
    required this.fontSize,
    required this.iconSize,
  });
}

/// Primary action button
class PrimaryButton extends StatelessWidget {

  const PrimaryButton({
    required this.label, super.key,
    this.onPressed,
    this.icon,
    this.size = ButtonSize.large,
    this.isLoading = false,
    this.isFullWidth = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonSize size;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final button = icon != null
        ? ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? SizedBox(
                    width: size.iconSize,
                    height: size.iconSize,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: size.iconSize),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(0, size.height),
              padding: size.padding,
              textStyle: TextStyle(fontSize: size.fontSize),
            ),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(0, size.height),
              padding: size.padding,
              textStyle: TextStyle(fontSize: size.fontSize),
            ),
            child: isLoading
                ? SizedBox(
                    width: size.iconSize,
                    height: size.iconSize,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(label),
          );

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Secondary action button
class SecondaryButton extends StatelessWidget {

  const SecondaryButton({
    required this.label, super.key,
    this.onPressed,
    this.icon,
    this.size = ButtonSize.large,
    this.isLoading = false,
    this.isFullWidth = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonSize size;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final button = icon != null
        ? OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? SizedBox(
                    width: size.iconSize,
                    height: size.iconSize,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: size.iconSize),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, size.height),
              padding: size.padding,
              textStyle: TextStyle(fontSize: size.fontSize),
            ),
          )
        : OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, size.height),
              padding: size.padding,
              textStyle: TextStyle(fontSize: size.fontSize),
            ),
            child: isLoading
                ? SizedBox(
                    width: size.iconSize,
                    height: size.iconSize,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(label),
          );

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Text button for tertiary actions
class TertiaryButton extends StatelessWidget {

  const TertiaryButton({
    required this.label, super.key,
    this.onPressed,
    this.icon,
    this.size = ButtonSize.medium,
    this.isFullWidth = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonSize size;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final button = icon != null
        ? TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: size.iconSize),
            label: Text(label),
            style: TextButton.styleFrom(
              minimumSize: Size(0, size.height),
              padding: size.padding,
              textStyle: TextStyle(fontSize: size.fontSize),
            ),
          )
        : TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              minimumSize: Size(0, size.height),
              padding: size.padding,
              textStyle: TextStyle(fontSize: size.fontSize),
            ),
            child: Text(label),
          );

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Destructive action button (red)
class DestructiveButton extends StatelessWidget {

  const DestructiveButton({
    required this.label, super.key,
    this.onPressed,
    this.icon,
    this.size = ButtonSize.large,
    this.isLoading = false,
    this.isFullWidth = false,
    this.outlined = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (outlined) {
      final button = icon != null
          ? OutlinedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: Icon(icon, size: size.iconSize),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
                minimumSize: Size(0, size.height),
                padding: size.padding,
                textStyle: TextStyle(fontSize: size.fontSize),
              ),
            )
          : OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
                minimumSize: Size(0, size.height),
                padding: size.padding,
                textStyle: TextStyle(fontSize: size.fontSize),
              ),
              child: Text(label),
            );
      return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
    }

    final button = icon != null
        ? ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: Icon(icon, size: size.iconSize),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              minimumSize: Size(0, size.height),
              padding: size.padding,
              textStyle: TextStyle(fontSize: size.fontSize),
            ),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              minimumSize: Size(0, size.height),
              padding: size.padding,
              textStyle: TextStyle(fontSize: size.fontSize),
            ),
            child: Text(label),
          );

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Icon button with standard size
class StandardIconButton extends StatelessWidget {

  const StandardIconButton({
    required this.icon, super.key,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = 48.0,
    this.iconSize,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize ?? 24.0),
      color: color,
      iconSize: iconSize ?? 24.0,
      constraints: BoxConstraints.tightFor(
        width: size,
        height: size,
      ),
    );

    return tooltip != null
        ? Tooltip(message: tooltip, child: button)
        : button;
  }
}

/// Floating action button with standard styling
class StandardFAB extends StatelessWidget {

  const StandardFAB({
    required this.icon, super.key,
    this.onPressed,
    this.label,
    this.tooltip,
    this.extended = false,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final String? tooltip;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    if (extended && label != null) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label!),
        tooltip: tooltip,
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      child: Icon(icon),
    );
  }
}

/// Button group for multiple actions
class ButtonGroup extends StatelessWidget {

  const ButtonGroup({
    required this.buttons, super.key,
    this.direction = Axis.horizontal,
    this.spacing = LayoutConstants.paddingS,
    this.alignment = MainAxisAlignment.start,
  });
  final List<Widget> buttons;
  final Axis direction;
  final double spacing;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    if (direction == Axis.horizontal) {
      return Row(
        mainAxisAlignment: alignment,
        children: _buildChildren(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _buildChildren(),
    );
  }

  List<Widget> _buildChildren() {
    final children = <Widget>[];
    for (var i = 0; i < buttons.length; i++) {
      children.add(buttons[i]);
      if (i < buttons.length - 1) {
        children.add(SizedBox(
          width: direction == Axis.horizontal ? spacing : 0,
          height: direction == Axis.vertical ? spacing : 0,
        ));
      }
    }
    return children;
  }
}
