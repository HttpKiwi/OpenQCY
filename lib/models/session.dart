import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/qcy/advertisement.dart';
import '../core/qcy/anc.dart';
import '../core/qcy/eq.dart';
import 'device_info.dart';

class DiscoveredDevice {
  const DiscoveredDevice({
    required this.bleDevice,
    required this.id,
    required this.name,
    required this.rssi,
    required this.advertisement,
  });

  final BluetoothDevice bleDevice;
  final String id;
  final String name;
  final int rssi;
  final QcyAdvertisement advertisement;

  String get modelName => productTitleForVendor(advertisement.vendorId);

  String get displayName =>
      name.isNotEmpty && name != id ? name : modelName;

  int get vendorId => advertisement.vendorId;
}

enum ConnectionPhase {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class DeviceSettings {
  const DeviceSettings({
    this.gameMode = false,
    this.ldac = false,
    this.sleepMode = false,
    this.spatialAudio = false,
    this.inEarDetection = true,
    this.dualDevice = false,
    this.volumeLeft = 80,
    this.volumeRight = 80,
    this.soundBalance = 50,
    this.eqPresetIndex,
    this.eqParams,
    this.autoOffMinutes,
    this.keyFunctions = const {},
  });

  final bool gameMode;
  final bool ldac;
  final bool sleepMode;
  final bool spatialAudio;
  final bool inEarDetection;
  final bool dualDevice;
  final int volumeLeft;
  final int volumeRight;
  final int soundBalance;
  final int? eqPresetIndex;
  final EqParams? eqParams;
  final int? autoOffMinutes;
  final Map<int, int> keyFunctions;

  DeviceSettings copyWith({
    bool? gameMode,
    bool? ldac,
    bool? sleepMode,
    bool? spatialAudio,
    bool? inEarDetection,
    bool? dualDevice,
    int? volumeLeft,
    int? volumeRight,
    int? soundBalance,
    int? eqPresetIndex,
    EqParams? eqParams,
    int? autoOffMinutes,
    Map<int, int>? keyFunctions,
    bool clearEqPreset = false,
    bool clearEqParams = false,
    bool clearAutoOff = false,
  }) {
    return DeviceSettings(
      gameMode: gameMode ?? this.gameMode,
      ldac: ldac ?? this.ldac,
      sleepMode: sleepMode ?? this.sleepMode,
      spatialAudio: spatialAudio ?? this.spatialAudio,
      inEarDetection: inEarDetection ?? this.inEarDetection,
      dualDevice: dualDevice ?? this.dualDevice,
      volumeLeft: volumeLeft ?? this.volumeLeft,
      volumeRight: volumeRight ?? this.volumeRight,
      soundBalance: soundBalance ?? this.soundBalance,
      eqPresetIndex:
          clearEqPreset ? null : (eqPresetIndex ?? this.eqPresetIndex),
      eqParams: clearEqParams ? null : (eqParams ?? this.eqParams),
      autoOffMinutes:
          clearAutoOff ? null : (autoOffMinutes ?? this.autoOffMinutes),
      keyFunctions: keyFunctions ?? this.keyFunctions,
    );
  }
}

class DeviceSession {
  const DeviceSession({
    required this.device,
    this.phase = ConnectionPhase.disconnected,
    this.battery,
    this.firmware,
    this.ancMode,
    this.settings = const DeviceSettings(),
    this.errorMessage,
    this.statusMessage,
  });

  final DiscoveredDevice device;
  final ConnectionPhase phase;
  final BatteryLevels? battery;
  final FirmwareVersion? firmware;
  final AncMode? ancMode;
  final DeviceSettings settings;
  final String? errorMessage;
  final String? statusMessage;

  DeviceSettings get s => settings;

  bool get isBusy =>
      phase == ConnectionPhase.connecting ||
      phase == ConnectionPhase.reconnecting;

  DeviceSession copyWith({
    DiscoveredDevice? device,
    ConnectionPhase? phase,
    BatteryLevels? battery,
    FirmwareVersion? firmware,
    AncMode? ancMode,
    DeviceSettings? settings,
    String? errorMessage,
    String? statusMessage,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return DeviceSession(
      device: device ?? this.device,
      phase: phase ?? this.phase,
      battery: battery ?? this.battery,
      firmware: firmware ?? this.firmware,
      ancMode: ancMode ?? this.ancMode,
      settings: settings ?? this.settings,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusMessage:
          clearStatus ? null : (statusMessage ?? this.statusMessage),
    );
  }
}
