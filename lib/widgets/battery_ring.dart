import 'package:flutter/material.dart';

class BatteryRing extends StatelessWidget {
  const BatteryRing({
    super.key,
    required this.label,
    required this.level,
    this.charging = false,
    this.icon = Icons.headphones,
  });

  final String label;
  final int level;
  final bool charging;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = (level.clamp(0, 100)) / 100.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                color: _batteryColor(scheme, level),
              ),
              Icon(
                charging ? Icons.bolt : icon,
                color: scheme.onSurface,
                size: 28,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(
          '$level%',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Color _batteryColor(ColorScheme scheme, int level) {
    if (level <= 15) return scheme.error;
    if (level <= 30) return Colors.orange;
    return scheme.primary;
  }
}
