import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.watch(bleControllerProvider);
    final saved = ble.lastDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Auto-reconnect'),
            subtitle: const Text('Offer quick reconnect to last device'),
            value: ble.autoReconnect,
            onChanged: (v) => ble.setAutoReconnect(v),
          ),
          if (saved != null)
            ListTile(
              title: Text('Saved device: ${saved.name}'),
              subtitle: Text(saved.id),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ble.clearSavedDevice();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved device cleared')),
                    );
                  }
                },
              ),
            ),
          const Divider(),
          ListTile(
            title: const Text('About OpenQCY'),
            subtitle: const Text(
              'Unofficial QCY earbud controller via BLE GATT.\n'
              'Based on the Quicky protocol.\n'
              'com.httpkiwi.melocontrol · v1.0.0',
            ),
          ),
        ],
      ),
    );
  }
}
