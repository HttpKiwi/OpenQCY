import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/qcy/anc.dart';
import '../../core/qcy/product_features.dart';
import '../../models/device_info.dart';
import '../../models/session.dart';
import '../../providers/providers.dart';
import '../../widgets/anc_selector.dart';
import '../../widgets/auto_off_selector.dart';
import '../../widgets/battery_ring.dart';
import '../../widgets/eq_preset_selector.dart';
import '../../widgets/settings_ui.dart';

class DeviceScreen extends ConsumerStatefulWidget {
  const DeviceScreen({super.key});

  @override
  ConsumerState<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ConsumerState<DeviceScreen> {
  bool _ancBusy = false;

  Future<void> _run(Future<void> Function() action, String label) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label failed: $e')),
        );
      }
    }
  }

  Future<void> _setAnc(AncMode mode) async {
    if (_ancBusy) return;
    setState(() => _ancBusy = true);
    HapticFeedback.lightImpact();
    await _run(() => ref.read(bleControllerProvider).setAncMode(mode), 'ANC');
    if (mounted) setState(() => _ancBusy = false);
  }

  Future<void> _renameDevice() async {
    final session = ref.read(bleControllerProvider).session;
    if (session == null) return;
    final controller = TextEditingController(text: session.device.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename device'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Device name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _run(
      () => ref.read(bleControllerProvider).setDeviceName(name),
      'Rename',
    );
  }

  Future<void> _showFindEarbuds() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Find earbuds',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Plays a locating tone on the earbuds. Stop when you find them.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _run(
                    () => ref.read(bleControllerProvider).setFindEarbuds(true),
                    'Find',
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start locating'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _run(
                    () => ref.read(bleControllerProvider).setFindEarbuds(false),
                    'Stop find',
                  ),
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _goBack() async {
    await ref.read(bleControllerProvider).softDisconnect();
    if (mounted) context.pop();
  }

  Future<void> _disconnect() async {
    await ref.read(bleControllerProvider).disconnect();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ble = ref.watch(bleControllerProvider);
    final session = ble.session;
    final scheme = Theme.of(context).colorScheme;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Device')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Back to scan'),
          ),
        ),
      );
    }

    final connected = session.phase == ConnectionPhase.connected;
    final interactive = connected && !session.isBusy;
    final features = featuresForVendor(session.device.vendorId);
    final s = session.settings;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(bleControllerProvider).softDisconnect();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(session.device.displayName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          IconButton(
            onPressed: interactive ? () => ble.refreshStatus() : null,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            onPressed: connected ? _disconnect : null,
            icon: const Icon(Icons.link_off),
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _StatusBanner(session: session),
          const SizedBox(height: 20),
          _BatteryCard(battery: session.battery),
          if (session.firmware != null) ...[
            const SizedBox(height: 8),
            Text(
              'Firmware L ${session.firmware!.left}'
              '${session.firmware!.right != null ? ' · R ${session.firmware!.right}' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Noise control',
            subtitle: 'You should hear the voice prompt on change.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AncSelector(
                selected: session.ancMode,
                busy: _ancBusy || !interactive,
                onSelected: _setAnc,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Equalizer'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: EqPresetSelector(
                presets: features.eqPresets,
                selectedIndex: s.eqPresetIndex,
                enabled: interactive,
                onSelected: (i) => _run(
                  () => ref.read(bleControllerProvider).setEqPreset(i),
                  'EQ',
                ),
              ),
            ),
          ),
          if (features.eq != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: interactive
                    ? () => context.push('/device/eq')
                    : null,
                icon: const Icon(Icons.tune),
                label: const Text('Customize bands'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const SectionHeader(title: 'Audio'),
          SettingsCard(
            children: [
              ListTile(
                title: const Text('Volume'),
                subtitle: Text('L ${s.volumeLeft}% · R ${s.volumeRight}%'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: s.volumeLeft.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: 'L ${s.volumeLeft}',
                        onChanged: interactive
                            ? (v) => ref
                                .read(bleControllerProvider)
                                .setVolume(v.round(), s.volumeRight)
                            : null,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: s.volumeRight.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: 'R ${s.volumeRight}',
                        onChanged: interactive
                            ? (v) => ref
                                .read(bleControllerProvider)
                                .setVolume(s.volumeLeft, v.round())
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (features.channelBalance)
                ListTile(
                  title: const Text('Channel balance'),
                  subtitle: Slider(
                    value: s.soundBalance.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: s.soundBalance == 50
                        ? 'Center'
                        : s.soundBalance < 50
                            ? 'Left'
                            : 'Right',
                    onChanged: interactive
                        ? (v) => ref
                            .read(bleControllerProvider)
                            .setSoundBalance(v.round())
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (features.hasKeyFunctions) ...[
            const SectionHeader(
              title: 'Controls',
              subtitle: 'Customize touch gestures per earbud.',
            ),
            SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.touch_app_outlined),
                  title: const Text('Touch controls'),
                  subtitle: const Text('Single, double, and triple tap'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: interactive
                      ? () => context.push('/device/keys')
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          if (features.autoOffTimer != null) ...[
            const SectionHeader(
              title: 'Power',
              subtitle: 'Auto power-off when idle.',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AutoOffSelector(
                  selectedMinutes: s.autoOffMinutes,
                  disabledMinutes: features.autoOffTimer!.disabledMinutes,
                  enabled: interactive,
                  onSelected: (m) => _run(
                    () => ref.read(bleControllerProvider).setAutoOffMinutes(m),
                    'Auto power-off',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          const SectionHeader(title: 'Features'),
          SettingsCard(
            children: [
              SwitchListTile(
                title: const Text('Gaming mode'),
                subtitle: const Text('Low latency'),
                value: s.gameMode,
                onChanged: interactive
                    ? (v) => _run(
                          () => ref.read(bleControllerProvider).setGameMode(v),
                          'Game mode',
                        )
                    : null,
              ),
              if (features.ldac)
                SwitchListTile(
                  title: const Text('LDAC'),
                  subtitle: const Text('High quality codec'),
                  value: s.ldac,
                  onChanged: interactive
                      ? (v) => _run(
                            () => ref.read(bleControllerProvider).setLdac(v),
                            'LDAC',
                          )
                      : null,
                ),
              if (features.sleepMode)
                SwitchListTile(
                  title: const Text('Sleep mode'),
                  value: s.sleepMode,
                  onChanged: interactive
                      ? (v) => _run(
                            () =>
                                ref.read(bleControllerProvider).setSleepMode(v),
                            'Sleep mode',
                          )
                      : null,
                ),
              if (features.spatialAudio)
                SwitchListTile(
                  title: const Text('Spatial audio'),
                  value: s.spatialAudio,
                  onChanged: interactive
                      ? (v) => _run(
                            () => ref
                                .read(bleControllerProvider)
                                .setSpatialAudio(v),
                            'Spatial audio',
                          )
                      : null,
                ),
              if (features.inEarDetection)
                SwitchListTile(
                  title: const Text('In-ear detection'),
                  value: s.inEarDetection,
                  onChanged: interactive
                      ? (v) => _run(
                            () => ref
                                .read(bleControllerProvider)
                                .setInEarDetection(v),
                            'In-ear detection',
                          )
                      : null,
                ),
              if (features.dualDevice)
                SwitchListTile(
                  title: const Text('Dual device connection'),
                  value: s.dualDevice,
                  onChanged: interactive
                      ? (v) => _run(
                            () =>
                                ref.read(bleControllerProvider).setDualDevice(v),
                            'Dual device',
                          )
                      : null,
                ),
              if (features.findEarphone)
                ListTile(
                  leading: const Icon(Icons.location_searching),
                  title: const Text('Find earbuds'),
                  onTap: interactive ? _showFindEarbuds : null,
                ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Device'),
          SettingsCard(
            children: [
              if (features.deviceRename)
                ListTile(
                  leading: const Icon(Icons.drive_file_rename_outline),
                  title: const Text('Rename'),
                  onTap: interactive ? _renameDevice : null,
                ),
              ListTile(
                leading: Icon(Icons.restart_alt, color: scheme.error),
                title: const Text('Reset to defaults'),
                onTap: interactive
                    ? () async {
                        if (await confirmAction(
                          context,
                          title: 'Reset settings?',
                          message:
                              'Restores factory default settings (not pairing).',
                        )) {
                          await _run(
                            () => ref
                                .read(bleControllerProvider)
                                .resetToDefault(),
                            'Reset',
                          );
                        }
                      }
                    : null,
              ),
              ListTile(
                leading: Icon(Icons.delete_forever, color: scheme.error),
                title: const Text('Factory reset'),
                onTap: interactive
                    ? () async {
                        if (await confirmAction(
                          context,
                          title: 'Factory reset?',
                          message:
                              'Clears all settings and pairing. This cannot be undone.',
                          confirm: 'Reset',
                          destructive: true,
                        )) {
                          await _run(
                            () => ref
                                .read(bleControllerProvider)
                                .factoryReset(),
                            'Factory reset',
                          );
                        }
                      }
                    : null,
              ),
            ],
          ),
          if (session.errorMessage != null) ...[
            const SizedBox(height: 16),
            MaterialBanner(
              content: Text(session.errorMessage!),
              actions: [
                TextButton(
                  onPressed: () => _run(
                    () => session.phase == ConnectionPhase.error
                        ? ble.retryReconnect()
                        : ble.connect(session.device),
                    'Reconnect',
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    );
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.battery});

  final BatteryLevels? battery;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: battery == null
            ? const Center(child: CircularProgressIndicator())
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  BatteryRing(
                    label: 'Left',
                    level: battery!.left,
                    charging: battery!.leftCharging,
                  ),
                  BatteryRing(
                    label: 'Right',
                    level: battery!.right,
                    charging: battery!.rightCharging,
                  ),
                  BatteryRing(
                    label: 'Case',
                    level: battery!.caseLevel,
                    charging: battery!.caseCharging,
                    icon: Icons.inventory_2_outlined,
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.session});

  final DeviceSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color, icon) = switch (session.phase) {
      ConnectionPhase.connected => (
          'Connected',
          scheme.primaryContainer,
          Icons.link,
        ),
      ConnectionPhase.connecting => (
          session.statusMessage ?? 'Connecting…',
          scheme.secondaryContainer,
          Icons.bluetooth_connected,
        ),
      ConnectionPhase.reconnecting => (
          session.statusMessage ?? 'Reconnecting…',
          scheme.secondaryContainer,
          Icons.bluetooth_searching,
        ),
      ConnectionPhase.error => (
          'Error',
          scheme.errorContainer,
          Icons.error_outline,
        ),
      ConnectionPhase.disconnected => (
          'Disconnected',
          scheme.surfaceContainerHighest,
          Icons.link_off,
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (session.phase == ConnectionPhase.reconnecting ||
              session.phase == ConnectionPhase.connecting)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onSurface,
                ),
              ),
            )
          else
            Icon(icon, color: scheme.onSurface),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Text(
            session.device.modelName,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
