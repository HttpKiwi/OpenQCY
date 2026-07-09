import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/session.dart';
import '../../providers/providers.dart';
import '../../widgets/pulse_bluetooth.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await _requestPermissions();
    final ble = ref.read(bleControllerProvider);
    await ble.initPrefs();
    await _scan();
    if (ble.autoReconnect && ble.lastDevice != null && mounted) {
      setState(() {});
    }
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    final denied = statuses.entries.where((e) => !e.value.isGranted);
    if (denied.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth permissions are required to control earbuds'),
        ),
      );
    }
  }

  Future<void> _scan() async {
    final ble = ref.read(bleControllerProvider);
    try {
      await ble.startScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    }
  }

  Future<void> _connect(DiscoveredDevice device) async {
    if (_connecting) return;
    setState(() => _connecting = true);
    final ble = ref.read(bleControllerProvider);
    try {
      await ble.connect(device);
      if (mounted) context.push('/device');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connect failed: $e'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _reconnectSaved() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      await ref.read(bleControllerProvider).reconnectSaved();
      if (mounted) context.push('/device');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reconnect failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble = ref.watch(bleControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final saved = ble.lastDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Melo Control'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            onPressed: ble.scanning || _connecting ? null : _scan,
            icon: const Icon(Icons.refresh),
            tooltip: 'Scan again',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _scan,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (saved != null && ble.autoReconnect)
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: scheme.primaryContainer,
                child: ListTile(
                  leading: Icon(Icons.history, color: scheme.onPrimaryContainer),
                  title: Text(
                    'Reconnect to ${saved.name}',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                  subtitle: Text(
                    saved.id,
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                  trailing: _connecting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : FilledButton(
                          onPressed: _reconnectSaved,
                          child: const Text('Connect'),
                        ),
                ),
              ),
            Center(
              child: Column(
                children: [
                  PulseBluetoothIcon(active: ble.scanning || _connecting),
                  const SizedBox(height: 16),
                  Text(
                    ble.scanning
                        ? 'Scanning for QCY earbuds…'
                        : 'Pull down or tap refresh to scan',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Works while music is playing. Keep buds out or case open.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (_connecting) const LinearProgressIndicator(minHeight: 3),
            if (ble.devices.isEmpty && !ble.scanning)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No QCY devices found yet.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ...ble.devices.asMap().entries.map((entry) {
              final index = entry.key;
              final device = entry.value;
              return TweenAnimationBuilder<double>(
                key: ValueKey(device.id),
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 320 + index * 60),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 16),
                      child: child,
                    ),
                  );
                },
                child: _DeviceCard(
                  device: device,
                  onTap: _connecting ? null : () => _connect(device),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, this.onTap});

  final DiscoveredDevice device;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final adv = device.advertisement;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.headphones, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      device.modelName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'L ${adv.leftBattery}% · R ${adv.rightBattery}% · Case ${adv.boxBattery}%',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(Icons.chevron_right, color: scheme.outline),
                  Text(
                    '${device.rssi} dBm',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
