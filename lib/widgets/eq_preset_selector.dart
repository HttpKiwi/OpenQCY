import 'package:flutter/material.dart';

class EqPresetSelector extends StatelessWidget {
  const EqPresetSelector({
    super.key,
    required this.presets,
    required this.selectedIndex,
    required this.onSelected,
    this.enabled = true,
  });

  final List<String> presets;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < presets.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == presets.length - 1 ? 0 : 8),
              child: ChoiceChip(
                label: Text(presets[i]),
                selected: selectedIndex == i,
                onSelected: enabled ? (_) => onSelected(i) : null,
                selectedColor: scheme.primaryContainer,
                labelStyle: TextStyle(
                  color: selectedIndex == i
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
