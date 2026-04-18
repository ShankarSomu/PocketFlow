import 'package:flutter/material.dart';

class ProfileTileRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  
  const ProfileTileRow({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<ProfileTileRow> createState() => _ProfileTileRowState();
}

class _ProfileTileRowState extends State<ProfileTileRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.color.withOpacity(_isPressed ? 0.25 : 0.15),
                    widget.color.withOpacity(_isPressed ? 0.15 : 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.color.withOpacity(0.2), width: 1),
              ),
              child: Icon(widget.icon, size: 16, color: widget.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface)),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
