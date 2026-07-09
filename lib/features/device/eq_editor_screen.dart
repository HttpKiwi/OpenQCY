import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/qcy/eq.dart';
import '../../core/qcy/product_features.dart';
import '../../models/session.dart';
import '../../providers/providers.dart';
import '../../widgets/eq_band_editor.dart';
import '../../widgets/eq_preset_selector.dart';
import '../../widgets/settings_ui.dart';

class EqEditorScreen extends ConsumerStatefulWidget {
  const EqEditorScreen({super.key});

  @override
  ConsumerState<EqEditorScreen> createState() => _EqEditorScreenState();
}

class _EqEditorScreenState extends ConsumerState<EqEditorScreen> {
  EqParams? _draft;
  Timer? _debounce;
  bool _sending = false;
  bool _loadingPreset = false;

  EqFeature get _eqFeature {
    final vendorId = ref.read(bleControllerProvider).session?.device.vendorId;
    return featuresForVendor(vendorId ?? 0).eq ?? meloBudsProEq;
  }

  EqParams _baseline() {
    final session = ref.read(bleControllerProvider).session;
    final s = session?.settings;
    final preset = s?.eqPresetIndex ?? 1;
    return s?.eqParams ??
        defaultEqParams(
          presetIndex: preset,
          frequencies: _eqFeature.frequencies,
        );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _draft = _baseline());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleSend(EqParams params) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _send(params));
  }

  Future<void> _send(EqParams params) async {
    if (_sending || _loadingPreset) return;
    setState(() => _sending = true);
    try {
      await ref.read(bleControllerProvider).setEqParams(params);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('EQ update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _selectPreset(int index) async {
    if (_loadingPreset || _sending) return;
    _debounce?.cancel();
    setState(() => _loadingPreset = true);
    try {
      final params =
          await ref.read(bleControllerProvider).applyEqPreset(index);
      if (params != null && mounted) {
        setState(() => _draft = params);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Preset applied — band data not returned. Tap refresh or adjust manually.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preset failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPreset = false);
    }
  }

  void _updateBand(int index, double gainDb) {
    if (_loadingPreset) return;
    final current = _draft ?? _baseline();
    final bands = [...current.bands];
    bands[index] = bands[index].copyWith(gainDb: gainDb);
    final next = current.copyWith(bands: bands);
    setState(() => _draft = next);
    _scheduleSend(next);
  }

  void _resetFlat() {
    if (_loadingPreset) return;
    final current = _draft ?? _baseline();
    final next = current.copyWith(
      masterGainDb: 0,
      bands: flatEqBands(_eqFeature.frequencies),
    );
    setState(() => _draft = next);
    _scheduleSend(next);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bleControllerProvider, (_, next) {
      final params = next.session?.settings.eqParams;
      if (params != null && !_sending && mounted) {
        setState(() => _draft = params);
      }
    });

    final session = ref.watch(bleControllerProvider).session;
    final interactive =
        session?.phase == ConnectionPhase.connected && !session!.isBusy;
    final busy = _sending || _loadingPreset;
    final draft = _draft ?? _baseline();
    final features = featuresForVendor(session?.device.vendorId ?? 0);
    final selectedPreset = session?.settings.eqPresetIndex ?? draft.presetIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EQ bands'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeader(
            title: 'Presets',
            subtitle: 'Switch preset to load its curve into the bands below.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: EqPresetSelector(
                presets: features.eqPresets,
                selectedIndex: selectedPreset,
                enabled: interactive && !busy,
                onSelected: _selectPreset,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: 'Band levels',
            subtitle:
                '±${_eqFeature.maxDb.toStringAsFixed(0)} dB per band. Drag sliders to customize.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: EqBandEditor(
                bands: draft.bands,
                minDb: _eqFeature.minDb,
                maxDb: _eqFeature.maxDb,
                enabled: interactive && !busy,
                horizontal: true,
                onBandChanged: _updateBand,
                onReset: _resetFlat,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
