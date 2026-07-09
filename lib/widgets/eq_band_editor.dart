import 'package:flutter/material.dart';

import '../core/qcy/eq.dart';

class EqBandEditor extends StatelessWidget {
  const EqBandEditor({
    super.key,
    required this.bands,
    required this.minDb,
    required this.maxDb,
    required this.enabled,
    required this.onBandChanged,
    this.onReset,
    this.horizontal = false,
  });

  final List<EqBand> bands;
  final double minDb;
  final double maxDb;
  final bool enabled;
  final void Function(int index, double gainDb) onBandChanged;
  final VoidCallback? onReset;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    if (horizontal) {
      return _HorizontalBands(
        bands: bands,
        maxDb: maxDb,
        enabled: enabled,
        onBandChanged: onBandChanged,
        onReset: onReset,
      );
    }
    return _VerticalBands(
      bands: bands,
      maxDb: maxDb,
      enabled: enabled,
      onBandChanged: onBandChanged,
      onReset: onReset,
    );
  }
}

class _VerticalBands extends StatelessWidget {
  const _VerticalBands({
    required this.bands,
    required this.maxDb,
    required this.enabled,
    required this.onBandChanged,
    this.onReset,
  });

  final List<EqBand> bands;
  final double maxDb;
  final bool enabled;
  final void Function(int index, double gainDb) onBandChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onReset != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: enabled ? onReset : null,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset to flat'),
            ),
          ),
        for (var i = 0; i < bands.length; i++)
          _BandSliderRow(
            band: bands[i],
            maxDb: maxDb,
            enabled: enabled,
            scheme: scheme,
            onChanged: (v) => onBandChanged(i, v),
          ),
      ],
    );
  }
}

class _HorizontalBands extends StatelessWidget {
  const _HorizontalBands({
    required this.bands,
    required this.maxDb,
    required this.enabled,
    required this.onBandChanged,
    this.onReset,
  });

  final List<EqBand> bands;
  final double maxDb;
  final bool enabled;
  final void Function(int index, double gainDb) onBandChanged;
  final VoidCallback? onReset;

  static const _sliderHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onReset != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: enabled ? onReset : null,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset to flat'),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < bands.length; i++)
                SizedBox(
                  width: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      children: [
                        Text(
                          '${bands[i].gainDb >= 0 ? '+' : ''}${bands[i].gainDb.toStringAsFixed(1)}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: bands[i].gainDb == 0
                                        ? scheme.onSurfaceVariant
                                        : scheme.primary,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: _sliderHeight,
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              value: bands[i].gainDb.clamp(-maxDb, maxDb),
                              min: -maxDb,
                              max: maxDb,
                              divisions: (maxDb * 2 * 2).round(),
                              label:
                                  '${bands[i].gainDb.toStringAsFixed(1)} dB',
                              onChanged: enabled
                                  ? (v) => onBandChanged(i, v)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatFrequency(bands[i].freqHz),
                          style: Theme.of(context).textTheme.labelSmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BandSliderRow extends StatelessWidget {
  const _BandSliderRow({
    required this.band,
    required this.maxDb,
    required this.enabled,
    required this.scheme,
    required this.onChanged,
  });

  final EqBand band;
  final double maxDb;
  final bool enabled;
  final ColorScheme scheme;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            formatFrequency(band.freqHz),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ),
        Expanded(
          child: Slider(
            value: band.gainDb.clamp(-maxDb, maxDb),
            min: -maxDb,
            max: maxDb,
            divisions: (maxDb * 2 * 2).round(),
            label: '${band.gainDb.toStringAsFixed(1)} dB',
            onChanged: enabled ? onChanged : null,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '${band.gainDb >= 0 ? '+' : ''}${band.gainDb.toStringAsFixed(1)}',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: band.gainDb == 0
                      ? scheme.onSurfaceVariant
                      : scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ),
      ],
    );
  }
}
