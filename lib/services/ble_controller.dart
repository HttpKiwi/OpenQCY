import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/qcy/advertisement.dart';
import '../core/qcy/anc.dart';
import '../core/qcy/commands.dart';
import '../core/qcy/eq.dart';
import '../core/qcy/guids.dart';
import '../core/qcy/key_function.dart';
import '../core/qcy/packet.dart';
import '../models/device_info.dart';
import '../models/session.dart';
import 'device_prefs.dart';

/// Opcodes that reboot the earbuds — auto-reconnect after disconnect.
const _rebootOpcodes = {0x23, 0x24};

class BleController extends ChangeNotifier {
  BleController();

  final List<DiscoveredDevice> _devices = [];
  List<DiscoveredDevice> get devices => List.unmodifiable(_devices);

  bool _scanning = false;
  bool get scanning => _scanning;

  DeviceSession? _session;
  DeviceSession? get session => _session;

  DevicePrefs? _prefs;

  BluetoothDevice? _connected;
  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _batteryChar;
  BluetoothCharacteristic? _versionChar;
  BluetoothCharacteristic? _eqChar;
  BluetoothCharacteristic? _keyFuncChar;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;

  bool _pendingReconnect = false;
  bool _reconnectLoopRunning = false;
  Completer<EqParams?>? _eqReadCompleter;

  SavedDevice? get lastDevice => _prefs?.lastDevice;
  bool get autoReconnect => _prefs?.autoReconnect ?? true;

  Future<void> initPrefs() async {
    _prefs ??= await DevicePrefs.load();
  }

  Future<void> setAutoReconnect(bool value) async {
    await initPrefs();
    await _prefs!.setAutoReconnect(value);
    notifyListeners();
  }

  Future<void> clearSavedDevice() async {
    await initPrefs();
    await _prefs!.clearLastDevice();
    notifyListeners();
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 12)}) async {
    await _ensureAdapterOn();
    _devices.clear();
    _scanning = true;
    notifyListeners();

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.onScanResults.listen(_onScanResults);

    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: false,
      withMsd: [MsdFilter(0x521c)],
    );

    _scanning = false;
    notifyListeners();
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanning = false;
    notifyListeners();
  }

  DiscoveredDevice? findDeviceForSaved(SavedDevice saved) {
    final id = saved.id.toUpperCase();
    final ctrl = saved.controlMac.toUpperCase();
    for (final d in _devices) {
      if (d.id.toUpperCase() == id ||
          d.advertisement.controlMac.toUpperCase() == ctrl) {
        return d;
      }
    }
    return null;
  }

  Future<void> reconnectSaved() async {
    await initPrefs();
    final saved = _prefs?.lastDevice;
    if (saved == null) return;

    final scanned = findDeviceForSaved(saved);
    if (scanned != null) {
      await connect(scanned);
      return;
    }

    await connect(
      DiscoveredDevice(
        bleDevice: BluetoothDevice.fromId(saved.id),
        id: saved.id,
        name: saved.name,
        rssi: -55,
        advertisement: QcyAdvertisement(
          vendorId: saved.vendorId,
          leftBattery: saved.leftBattery,
          rightBattery: saved.rightBattery,
          boxBattery: saved.boxBattery,
          leftCharging: false,
          rightCharging: false,
          boxCharging: false,
          controlMac: saved.controlMac,
        ),
      ),
    );
  }

  void _onScanResults(List<ScanResult> results) {
    var changed = false;
    for (final result in results) {
      final adv = QcyAdvertisement.fromManufacturerMap(
        result.advertisementData.manufacturerData,
      );
      if (adv == null) continue;

      final device = DiscoveredDevice(
        bleDevice: result.device,
        id: result.device.remoteId.str,
        name: result.advertisementData.advName.isNotEmpty
            ? result.advertisementData.advName
            : result.device.platformName,
        rssi: result.rssi,
        advertisement: adv,
      );

      final idx = _devices.indexWhere((d) => d.id == device.id);
      if (idx >= 0) {
        _devices[idx] = device;
      } else {
        _devices.add(device);
      }
      changed = true;
    }
    if (changed) {
      _devices.sort((a, b) => b.rssi.compareTo(a.rssi));
      notifyListeners();
    }
  }

  Future<void> connect(DiscoveredDevice device) async {
    await stopScan();
    await _tearDownLink();

    _pendingReconnect = false;
    _session = DeviceSession(
      device: device,
      phase: ConnectionPhase.connecting,
      battery: BatteryLevels.fromAdvertisement(device.advertisement),
      statusMessage: 'Connecting…',
    );
    notifyListeners();

    try {
      await _establishLink(device);
      await initPrefs();
      await _prefs!.saveLastDevice(SavedDevice.fromDiscovered(device));

      _session = _session!.copyWith(
        phase: ConnectionPhase.connected,
        clearError: true,
        clearStatus: true,
      );
      notifyListeners();
    } catch (e) {
      _session = _session?.copyWith(
        phase: ConnectionPhase.error,
        errorMessage: e.toString(),
        clearStatus: true,
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _establishLink(DiscoveredDevice device) async {
    await _ensureAdapterOn();
    final bleDevice = await _resolveConnectTarget(device);

    await bleDevice.connect(timeout: const Duration(seconds: 25));
    await bleDevice.connectionState
        .where((s) => s == BluetoothConnectionState.connected)
        .first
        .timeout(const Duration(seconds: 25));

    _connected = bleDevice;

    if (!kIsWeb && Platform.isAndroid) {
      await _androidBondIfNeeded(bleDevice);
    }

    await _setupGatt(bleDevice);
    await _subscribeNotifications();

    final battery = await readBattery();
    final firmware = await readFirmware();
    _session = _session?.copyWith(battery: battery, firmware: firmware);

    await syncSettingsFromDevice();

    await _connSub?.cancel();
    _connSub = bleDevice.connectionState.listen(_onConnectionStateChanged);
  }

  void _onConnectionStateChanged(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.disconnected) {
      if (_pendingReconnect) {
        unawaited(_reconnectAfterRestart());
      } else {
        _session = _session?.copyWith(
          phase: ConnectionPhase.disconnected,
          errorMessage: 'Device disconnected',
          clearStatus: true,
        );
        notifyListeners();
      }
    }
  }

  Future<void> _reconnectAfterRestart() async {
    if (_reconnectLoopRunning) return;
    _reconnectLoopRunning = true;

    final device = _session?.device;
    if (device == null) {
      _reconnectLoopRunning = false;
      _pendingReconnect = false;
      return;
    }

    _session = _session!.copyWith(
      phase: ConnectionPhase.reconnecting,
      statusMessage: 'Earbuds restarting — reconnecting…',
      clearError: true,
    );
    notifyListeners();

    await _tearDownLink();

    try {
      for (var attempt = 0; attempt < 24; attempt++) {
        _session = _session!.copyWith(
          statusMessage:
              'Earbuds restarting — reconnecting (${attempt + 1}/24)…',
        );
        notifyListeners();

        await Future<void>.delayed(
          Duration(milliseconds: 1800 + attempt * 250),
        );

        try {
          await _establishLink(device);
          _pendingReconnect = false;
          _session = _session!.copyWith(
            phase: ConnectionPhase.connected,
            clearError: true,
            clearStatus: true,
          );
          notifyListeners();
          return;
        } catch (e) {
          debugPrint('Reconnect attempt ${attempt + 1}: $e');
        }
      }

      _pendingReconnect = false;
      _session = _session?.copyWith(
        phase: ConnectionPhase.error,
        errorMessage:
            'Could not reconnect after restart. Tap Retry or go back and scan.',
        clearStatus: true,
      );
      notifyListeners();
    } finally {
      _reconnectLoopRunning = false;
    }
  }

  Future<void> retryReconnect() async {
    final device = _session?.device;
    if (device == null) return;
    _pendingReconnect = true;
    await _reconnectAfterRestart();
  }

  Future<BluetoothDevice> _resolveConnectTarget(DiscoveredDevice device) async {
    if (kIsWeb) return device.bleDevice;

    try {
      final system = await FlutterBluePlus.systemDevices([QcyGuids.service]);
      if (system.isNotEmpty) {
        final controlMac = device.advertisement.controlMac.toUpperCase();
        for (final d in system) {
          final id = d.remoteId.str.toUpperCase();
          final name = d.platformName.toLowerCase();
          if (id == device.id.toUpperCase() ||
              id == controlMac ||
              name.contains('melo') ||
              name.contains('qcy')) {
            return d;
          }
        }
        if (system.length == 1) return system.first;
      }
    } catch (e) {
      debugPrint('systemDevices lookup failed: $e');
    }

    return device.bleDevice;
  }

  Future<void> _androidBondIfNeeded(BluetoothDevice device) async {
    try {
      if (device.prevBondState != BluetoothBondState.bonded) {
        await device.createBond(timeout: 30);
      }
    } catch (e) {
      debugPrint('Bond skipped/failed: $e');
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Future<void> _setupGatt(BluetoothDevice device) async {
    BluetoothService? qcyService;
    List<BluetoothService> lastServices = [];

    for (var attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }
      lastServices = await device.discoverServices(timeout: 20);
      qcyService = _findQcyService(lastServices);
      if (qcyService != null) break;
    }

    if (qcyService == null) {
      final found = lastServices.map((s) => s.uuid.str128).join(', ');
      throw StateError(
        'QCY GATT service not found. Found: ${found.isEmpty ? "(none)" : found}',
      );
    }

    BluetoothCharacteristic? find(Guid expected) {
      for (final c in qcyService!.characteristics) {
        if (guidMatches(c.uuid, expected)) return c;
      }
      return null;
    }

    _commandChar = find(QcyGuids.command);
    _notifyChar = find(QcyGuids.notify);
    _batteryChar = find(QcyGuids.battery);
    _versionChar = find(QcyGuids.version);
    _eqChar = find(QcyGuids.eq);
    _keyFuncChar = find(QcyGuids.keyFunction);

    if (_commandChar == null || _notifyChar == null) {
      throw StateError('Required GATT characteristics missing on QCY service');
    }
  }

  BluetoothService? _findQcyService(List<BluetoothService> services) {
    for (final s in services) {
      if (isQcyService(s.uuid)) return s;
    }
    return null;
  }

  Future<void> _subscribeNotifications() async {
    await _notifySub?.cancel();
    final notify = _notifyChar!;
    await notify.setNotifyValue(true);
    _notifySub = notify.lastValueStream.listen(_onNotify);
  }

  void _onNotify(List<int> data) {
    if (_session == null) return;
    var settings = _session!.settings;
    AncMode? anc = _session!.ancMode;
    BatteryLevels? battery = _session!.battery;

    for (final cmd in parsePacket(data)) {
      if (cmd.opcode == 0x17 && cmd.params.length >= 3) {
        anc = AncMode.fromAck(cmd.params[0], cmd.params[1], cmd.params[2]);
      } else if (cmd.opcode == 0x0c && cmd.params.isNotEmpty) {
        anc = _ancFromSimpleMode(cmd.params[0]);
      } else if (cmd.opcode == 0x09 && cmd.params.isNotEmpty) {
        settings =
            settings.copyWith(gameMode: toggleValueFromByte(cmd.params[0]));
      } else if (cmd.opcode == 0x23 && cmd.params.isNotEmpty) {
        settings = settings.copyWith(ldac: toggleValueFromByte(cmd.params[0]));
      } else if (cmd.opcode == 0x10 && cmd.params.isNotEmpty) {
        settings =
            settings.copyWith(sleepMode: toggleValueFromByte(cmd.params[0]));
      } else if (cmd.opcode == 0x2d && cmd.params.isNotEmpty) {
        settings = settings.copyWith(
          spatialAudio: toggleValueFromByte(cmd.params[0]),
        );
      } else if (cmd.opcode == 0x06 && cmd.params.isNotEmpty) {
        settings = settings.copyWith(
          inEarDetection: toggleValueFromByte(cmd.params[0]),
        );
      } else if (cmd.opcode == 0x24 && cmd.params.isNotEmpty) {
        settings = settings.copyWith(
          dualDevice: toggleValueFromByte(cmd.params[0]),
        );
      } else if (cmd.opcode == 0x08 && cmd.params.length >= 2) {
        settings = settings.copyWith(
          volumeLeft: cmd.params[0],
          volumeRight: cmd.params[1],
        );
      } else if (cmd.opcode == 0x16 && cmd.params.isNotEmpty) {
        settings = settings.copyWith(soundBalance: cmd.params[0]);
      } else if (cmd.opcode == 0x20 && cmd.params.isNotEmpty) {
        final parsed = parseEqV1Params(cmd.params);
        if (parsed != null) {
          settings = settings.copyWith(
            eqPresetIndex: parsed.presetIndex,
            eqParams: parsed,
          );
          _completeEqRead(parsed);
        }
      } else if (cmd.opcode == 0x22 && cmd.params.isNotEmpty) {
        final parsed = parseEqV2Params(cmd.params);
        if (parsed != null) {
          settings = settings.copyWith(
            eqPresetIndex: parsed.presetIndex,
            eqParams: parsed,
          );
          _completeEqRead(parsed);
        } else {
          settings = settings.copyWith(eqPresetIndex: cmd.params[0]);
        }
      } else if (cmd.opcode == 0x14 && cmd.params.length >= 2) {
        settings = settings.copyWith(
          autoOffMinutes: parsePowerOffMinutes(cmd.params),
        );
      } else if (cmd.opcode == 0x2b && cmd.params.length >= 2) {
        settings = settings.copyWith(
          keyFunctions: parseKeyFunctionData(cmd.params),
        );
      } else if (cmd.opcode == 0x2f && cmd.params.isNotEmpty) {
        final incoming = BatteryLevels.fromBytes(cmd.params);
        battery = incoming.mergedWith(
          _session!.device.advertisement,
          keepCaseFrom: battery,
        );
      }
    }

    _session = _session!.copyWith(
      ancMode: anc,
      settings: settings,
      battery: battery,
    );
    notifyListeners();
  }

  AncMode? _ancFromSimpleMode(int mode) {
    return switch (mode) {
      0 => AncMode.off,
      1 => AncMode.indoor,
      2 => AncMode.commuting,
      3 => AncMode.transparency,
      _ => null,
    };
  }

  Future<void> syncSettingsFromDevice() async {
    await syncKeyFunctionsFromDevice();

    const opcodes = [
      0x2f, 0x09, 0x10, 0x06, 0x23, 0x24, 0x2d, 0x08, 0x16, 0x17, 0x0c, 0x14,
      0x2b,
    ];
    for (final op in opcodes) {
      try {
        await _send(buildRequestDataCommand(op));
        await Future<void>.delayed(const Duration(milliseconds: 70));
      } catch (_) {}
    }

    final eq = await _fetchEqParams();
    if (eq != null && _session != null) {
      _session = _session!.copyWith(
        settings: _session!.settings.copyWith(
          eqPresetIndex: eq.presetIndex,
          eqParams: eq,
        ),
      );
      notifyListeners();
    }

    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  Future<void> syncKeyFunctionsFromDevice() async {
    final char = _keyFuncChar;
    if (char == null) return;
    try {
      final data = await char.read();
      if (data.isNotEmpty && _session != null) {
        _session = _session!.copyWith(
          settings: _session!.settings.copyWith(
            keyFunctions: parseKeyFunctionData(data),
          ),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('read key functions failed: $e');
    }
  }

  Future<Map<int, int>> readKeyFunctions() async {
    final char = _keyFuncChar;
    if (char == null) throw StateError('Key function characteristic unavailable');
    final data = await char.read();
    return parseKeyFunctionData(data);
  }

  Future<void> writeKeyFunctions(Map<int, int> mappings) async {
    final char = _keyFuncChar;
    if (char == null) throw StateError('Key function characteristic unavailable');
    await char.write(serializeKeyFunctions(mappings), withoutResponse: true);
    _session = _session?.copyWith(
      settings: _session!.settings.copyWith(keyFunctions: Map.of(mappings)),
    );
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      await _send(buildRequestDataCommand(0x2b));
    } catch (_) {}
  }

  Future<void> setAutoOffMinutes(int minutes) async {
    await _send(buildPowerManagerCommand(minutes));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      await _send(buildRequestDataCommand(0x14));
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<void> _send(List<int> packet) async {
    final cmd = _commandChar;
    if (cmd == null) throw StateError('Not connected');
    await cmd.write(packet, withoutResponse: true);
  }

  Future<void> _sendAndRefresh(int opcode, List<int> packet) async {
    await _send(packet);
    if (_rebootOpcodes.contains(opcode)) {
      _pendingReconnect = true;
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      await _send(buildRequestDataCommand(opcode));
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<BatteryLevels?> readBattery() async {
    final char = _batteryChar;
    final adv = _session?.device.advertisement;
    if (char == null) {
      return adv != null ? BatteryLevels.fromAdvertisement(adv) : null;
    }
    final data = await char.read();
    final parsed = BatteryLevels.fromBytes(data);
    if (adv == null) return parsed;
    return parsed.mergedWith(adv, keepCaseFrom: _session?.battery);
  }

  Future<FirmwareVersion?> readFirmware() async {
    final char = _versionChar;
    if (char == null) return null;
    final data = await char.read();
    return FirmwareVersion.fromBytes(data);
  }

  Future<void> setAncMode(AncMode mode) async {
    await _send(buildAncCommand(mode));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _send(buildRequestDataCommand(0x17));
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<void> setGameMode(bool enabled) async {
    await _sendAndRefresh(0x09, buildLowLatencyCommand(enabled));
  }

  Future<void> setLdac(bool enabled) async {
    await _sendAndRefresh(0x23, buildLdacCommand(enabled));
  }

  Future<void> setSleepMode(bool enabled) async {
    await _sendAndRefresh(0x10, buildSleepModeCommand(enabled));
  }

  Future<void> setSpatialAudio(bool enabled) async {
    await _sendAndRefresh(0x2d, buildSpatialAudioCommand(enabled));
  }

  Future<void> setInEarDetection(bool enabled) async {
    await _sendAndRefresh(0x06, buildInEarDetectionCommand(enabled));
  }

  Future<void> setDualDevice(bool enabled) async {
    await _sendAndRefresh(0x24, buildDualDeviceCommand(enabled));
  }

  Future<void> setVolume(int left, int right) async {
    await _sendAndRefresh(0x08, buildVolumeCommand(left, right));
  }

  Future<void> setSoundBalance(int value) async {
    await _sendAndRefresh(0x16, buildSoundBalanceCommand(value));
  }

  Future<void> setEqPreset(int index) async {
    final params = await _applyEqPreset(index);
    if (params == null && _session != null) {
      _session = _session!.copyWith(
        settings: _session!.settings.copyWith(eqPresetIndex: index),
      );
      notifyListeners();
    }
  }

  /// Switches preset and reads back full band data when the device provides it.
  Future<EqParams?> applyEqPreset(int index) => _applyEqPreset(index);

  Future<EqParams?> _applyEqPreset(int index) async {
    final eq = _eqChar;
    if (eq != null) {
      try {
        await eq.write(buildEqDirectPreset(index), withoutResponse: true);
      } catch (_) {
        await _send(buildEqPresetSelectCommand(index));
      }
    } else {
      await _send(buildEqPresetSelectCommand(index));
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    final params = await _fetchEqParams();
    if (params != null && _session != null) {
      _session = _session!.copyWith(
        settings: _session!.settings.copyWith(
          eqPresetIndex: params.presetIndex,
          eqParams: params,
        ),
      );
      notifyListeners();
    }
    return params;
  }

  Future<EqParams?> _fetchEqParams({int expectedBands = 10}) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: 120 + attempt * 100),
        );
      }

      final fromChar = await _readEqCharacteristic();
      if (_isFullEq(fromChar, expectedBands)) {
        return fromChar;
      }

      final fromNotify = await _requestEqViaNotify();
      if (_isFullEq(fromNotify, expectedBands)) {
        return fromNotify;
      }
    }
    return null;
  }

  bool _isFullEq(EqParams? params, int expectedBands) {
    return params != null && params.bands.length >= expectedBands;
  }

  Future<EqParams?> _readEqCharacteristic() async {
    final char = _eqChar;
    if (char == null) return null;
    try {
      final data = await char.read();
      if (data.isEmpty) return null;
      return parseEqData(data);
    } catch (e) {
      debugPrint('EQ characteristic read failed: $e');
      return null;
    }
  }

  Future<EqParams?> _requestEqViaNotify() async {
    for (final opcode in [0x22, 0x20]) {
      final pending = _eqReadCompleter;
      if (pending != null && !pending.isCompleted) {
        pending.complete(null);
      }

      final completer = Completer<EqParams?>();
      _eqReadCompleter = completer;
      try {
        await _send(buildRequestDataCommand(opcode));
        final result = await completer.future.timeout(
          const Duration(milliseconds: 700),
          onTimeout: () => null,
        );
        if (_isFullEq(result, 10)) {
          return result;
        }
      } catch (e) {
        debugPrint('EQ request 0x${opcode.toRadixString(16)} failed: $e');
      } finally {
        if (identical(_eqReadCompleter, completer)) {
          _eqReadCompleter = null;
        }
      }
    }
    return null;
  }

  void _completeEqRead(EqParams params) {
    final completer = _eqReadCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(params);
    }
  }

  Future<void> setEqParams(EqParams params) async {
    await _send(buildEqV2Command(params));
    _session = _session?.copyWith(
      settings: _session!.settings.copyWith(
        eqPresetIndex: params.presetIndex,
        eqParams: params,
      ),
    );
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      await _send(buildRequestDataCommand(0x22));
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<void> setDeviceName(String name) async {
    await _send(buildRenameCommand(name));
  }

  Future<void> resetToDefault() async {
    await _send(buildResetDefaultCommand());
    _pendingReconnect = true;
  }

  Future<void> factoryReset() async {
    await _send(buildFactoryResetCommand());
    _pendingReconnect = true;
  }

  Future<void> setFindEarbuds(bool enabled) async {
    await _send(buildLightFlashCommand(enabled));
  }

  Future<void> refreshStatus() async {
    final battery = await readBattery();
    final firmware = await readFirmware();
    _session = _session?.copyWith(
      battery: battery,
      firmware: firmware,
    );
    notifyListeners();
    await syncSettingsFromDevice();
  }

  Future<void> _tearDownLink() async {
    await _notifySub?.cancel();
    await _connSub?.cancel();
    _notifySub = null;
    _connSub = null;
    _commandChar = null;
    _notifyChar = null;
    _batteryChar = null;
    _versionChar = null;
    _eqChar = null;
    _keyFuncChar = null;

    if (_connected != null) {
      try {
        await _connected!.disconnect();
      } catch (_) {}
    }
    _connected = null;
  }

  /// Disconnect and clear session (explicit user action).
  Future<void> disconnect() async {
    _pendingReconnect = false;
    _reconnectLoopRunning = false;
    await _tearDownLink();

    if (_session != null) {
      _session = _session!.copyWith(
        phase: ConnectionPhase.disconnected,
        clearStatus: true,
      );
    }
    notifyListeners();
  }

  /// Drop BLE link but keep session (navigate back to scan while connected).
  Future<void> softDisconnect() async {
    _pendingReconnect = false;
    await _tearDownLink();
    if (_session != null) {
      _session = _session!.copyWith(
        phase: ConnectionPhase.disconnected,
        clearStatus: true,
      );
    }
    notifyListeners();
  }

  Future<void> _ensureAdapterOn() async {
    if (await FlutterBluePlus.isSupported == false) {
      throw StateError('Bluetooth not supported on this platform');
    }
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
      await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 8));
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _notifySub?.cancel();
    _connSub?.cancel();
    disconnect();
    super.dispose();
  }
}
