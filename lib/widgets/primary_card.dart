import 'package:flutter/material.dart';

class PrimaryCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const PrimaryCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
  });

  @override
  State<PrimaryCard> createState() => _PrimaryCardState();
}

class _PrimaryCardState extends State<PrimaryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget card = Card(
      elevation: 6,
      shadowColor: theme.colorScheme.primary.withOpacity(0.20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: widget.padding,
        child: widget.child,
      ),
    );

    if (widget.onTap == null) {
      return card;
    }

    card = AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: card,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: widget.onTap,
      onHighlightChanged: (isHighlighted) {
        if (_pressed != isHighlighted) {
          setState(() {
            _pressed = isHighlighted;
          });
        }
      },
      child: card,
    );
  }
}
