import 'package:flutter/material.dart';

class GradientText extends StatelessWidget {

  const GradientText(
    this.text, {
    required this.gradient, super.key,
    this.style,
    this.textAlign,
  });
  final String text;
  final Gradient gradient;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        textAlign: textAlign,
      ),
    );
  }
}
