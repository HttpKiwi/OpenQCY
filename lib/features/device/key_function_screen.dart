import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/qcy/key_function.dart';
import '../../core/qcy/product_features.dart';
import '../../models/session.dart';
import '../../providers/providers.dart';
import '../../widgets/settings_ui.dart';

class KeyFunctionScreen extends ConsumerStatefulWidget {
  const KeyFunctionScreen({super.key});

  @override
  ConsumerState<KeyFunctionScreen> createState() => _KeyFunctionScreenState();
}

class _KeyFunctionScreenState extends ConsumerState<KeyFunctionScreen> {
  late Map<int, int> _draft;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _draft = {};
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final ble = ref.read(bleControllerProvider);
    final session = ble.session;
    if (session == null) return;

    try {
      final fromDevice = await ble.readKeyFunctions();
      if (mounted) {
        setState(() {
          _draft = Map.of(fromDevice.isNotEmpty
              ? fromDevice
              : session.settings.keyFunctions);
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _draft = Map.of(session.settings.keyFunctions);
          _loaded = true;
        });
      }
    }
  }

  ProductFeatures get _features {
    final vendorId = ref.read(bleControllerProvider).session?.device.vendorId;
    return featuresForVendor(vendorId ?? 0);
  }

  List<String> get _labels =>
      _features.keyFunctionLabels.isNotEmpty
          ? _features.keyFunctionLabels
          : meloBudsProKeyFunctions;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(bleControllerProvider).writeKeyFunctions(_draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Touch controls saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setMapping(int keyId, int funcId) {
    setState(() => _draft[keyId] = funcId);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(bleControllerProvider).session;
    final interactive =
        session?.phase == ConnectionPhase.connected && !session!.isBusy;
    final gestures = _features.keyGestures;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Touch controls'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: interactive && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Assign actions for each earbud gesture.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                for (final gesture in gestures) ...[
                  SectionHeader(title: gesture.name),
                  SettingsCard(
                    children: [
                      _KeyRow(
                        label: 'Left',
                        value: _draft[gesture.leftKeyId] ?? QcyFuncId.none,
                        options: _labels,
                        enabled: interactive,
                        onChanged: (v) => _setMapping(gesture.leftKeyId, v),
                      ),
                      const Divider(height: 1),
                      _KeyRow(
                        label: 'Right',
                        value: _draft[gesture.rightKeyId] ?? QcyFuncId.none,
                        options: _labels,
                        enabled: interactive,
                        onChanged: (v) => _setMapping(gesture.rightKeyId, v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.label,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<String> options;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: DropdownButton<int>(
        value: uiIndexFromFuncId(value).clamp(0, options.length - 1),
        items: [
          for (var i = 0; i < options.length; i++)
            DropdownMenuItem(value: i, child: Text(options[i])),
        ],
        onChanged: enabled ? (i) => onChanged(funcIdFromUiIndex(i ?? 0)) : null,
      ),
    );
  }
}
