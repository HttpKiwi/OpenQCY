import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/qcy/advertisement.dart';
import '../models/session.dart';

class SavedDevice {
  const SavedDevice({
    required this.id,
    required this.name,
    required this.vendorId,
    required this.controlMac,
    required this.leftBattery,
    required this.rightBattery,
    required this.boxBattery,
  });

  final String id;
  final String name;
  final int vendorId;
  final String controlMac;
  final int leftBattery;
  final int rightBattery;
  final int boxBattery;

  factory SavedDevice.fromDiscovered(DiscoveredDevice d) {
    return SavedDevice(
      id: d.id,
      name: d.displayName,
      vendorId: d.advertisement.vendorId,
      controlMac: d.advertisement.controlMac,
      leftBattery: d.advertisement.leftBattery,
      rightBattery: d.advertisement.rightBattery,
      boxBattery: d.advertisement.boxBattery,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'vendorId': vendorId,
        'controlMac': controlMac,
        'leftBattery': leftBattery,
        'rightBattery': rightBattery,
        'boxBattery': boxBattery,
      };

  factory SavedDevice.fromJson(Map<String, dynamic> json) {
    return SavedDevice(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      vendorId: json['vendorId'] as int? ?? 0,
      controlMac: json['controlMac'] as String? ?? '',
      leftBattery: json['leftBattery'] as int? ?? 0,
      rightBattery: json['rightBattery'] as int? ?? 0,
      boxBattery: json['boxBattery'] as int? ?? 0,
    );
  }
}

class DevicePrefs {
  DevicePrefs(this._prefs);

  final SharedPreferences _prefs;

  static const _lastDeviceKey = 'last_device';
  static const _autoReconnectKey = 'auto_reconnect';

  SavedDevice? get lastDevice {
    final raw = _prefs.getString(_lastDeviceKey);
    if (raw == null) return null;
    return SavedDevice.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  bool get autoReconnect => _prefs.getBool(_autoReconnectKey) ?? true;

  Future<void> saveLastDevice(SavedDevice device) async {
    await _prefs.setString(_lastDeviceKey, jsonEncode(device.toJson()));
  }

  Future<void> setAutoReconnect(bool value) async {
    await _prefs.setBool(_autoReconnectKey, value);
  }

  Future<void> clearLastDevice() async {
    await _prefs.remove(_lastDeviceKey);
  }

  static Future<DevicePrefs> load() async {
    return DevicePrefs(await SharedPreferences.getInstance());
  }
}

DiscoveredDevice mergeSavedWithScan(
  SavedDevice saved,
  BluetoothDevice bleDevice,
  QcyAdvertisement? adv,
) {
  final advertisement = adv ??
      QcyAdvertisement(
        vendorId: saved.vendorId,
        leftBattery: saved.leftBattery,
        rightBattery: saved.rightBattery,
        boxBattery: saved.boxBattery,
        leftCharging: false,
        rightCharging: false,
        boxCharging: false,
        controlMac: saved.controlMac,
      );
  return DiscoveredDevice(
    bleDevice: bleDevice,
    id: bleDevice.remoteId.str,
    name: saved.name,
    rssi: -55,
    advertisement: advertisement,
  );
}
