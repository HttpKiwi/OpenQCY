import 'package:flutter/material.dart';

import '../core/qcy/anc.dart';

class AncSelector extends StatelessWidget {
  const AncSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.busy = false,
  });

  final AncMode? selected;
  final ValueChanged<AncMode> onSelected;
  final bool busy;

  static const _modes = AncMode.values;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: busy
          ? const Padding(
              key: ValueKey('busy'),
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Wrap(
              key: ValueKey(selected),
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final mode in _modes)
                  FilterChip(
                    selected: selected == mode,
                    showCheckmark: true,
                    avatar: Icon(_iconFor(mode), size: 18),
                    label: Text(mode.label),
                    onSelected: busy ? null : (_) => onSelected(mode),
                    selectedColor: scheme.primaryContainer,
                    checkmarkColor: scheme.onPrimaryContainer,
                  ),
              ],
            ),
    );
  }

  IconData _iconFor(AncMode mode) => switch (mode) {
        AncMode.off => Icons.hearing_disabled,
        AncMode.indoor => Icons.noise_aware,
        AncMode.commuting => Icons.directions_transit,
        AncMode.transparency => Icons.hearing,
        AncMode.adaptive => Icons.auto_mode,
        AncMode.noisy => Icons.volume_up,
        AncMode.antiWind => Icons.air,
      };
}
