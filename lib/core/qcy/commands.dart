import 'dart:convert';

import 'eq.dart';
import 'packet.dart';

List<int> buildToggleCommand(int opcode, bool enabled) {
  return packCommand(opcode, [enabled ? 0x01 : 0x02]);
}

List<int> buildVolumeCommand(int left, int right) {
  return packCommand(0x08, [left.clamp(0, 100), right.clamp(0, 100), 0x00]);
}

List<int> buildSoundBalanceCommand(int value) {
  return packCommand(0x16, [value.clamp(0, 100)]);
}

List<int> buildRenameCommand(String name) {
  final bytes = utf8.encode(name);
  return packCommand(0x18, bytes);
}

List<int> buildResetDefaultCommand() => packCommand(0x01, const []);

List<int> buildFactoryResetCommand() => packCommand(0x03, const []);

List<int> buildLdacCommand(bool enabled) => buildToggleCommand(0x23, enabled);

List<int> buildSleepModeCommand(bool enabled) => buildToggleCommand(0x10, enabled);

List<int> buildSpatialAudioCommand(bool enabled) => buildToggleCommand(0x2d, enabled);

List<int> buildInEarDetectionCommand(bool enabled) => buildToggleCommand(0x06, enabled);

List<int> buildDualDeviceCommand(bool enabled) => buildToggleCommand(0x24, enabled);

/// Select a built-in preset without sending custom band data (cmd 0x22).
List<int> buildEqPresetSelectCommand(int presetIndex) {
  return packCommand(0x22, [presetIndex, 0x00, 0x00]);
}

@Deprecated('Use buildEqPresetSelectCommand for preset switching')
List<int> buildEqPresetCommand(int presetIndex) =>
    buildEqPresetSelectCommand(presetIndex);

List<int> buildEqV2Command(EqParams params) {
  return packCommand(0x22, buildEqV2Body(params));
}

List<int> buildEqDirectPreset(int presetIndex) => [presetIndex];

List<int> buildRequestDataCommand(int cmdId) {
  return packCommand(0xfe, [cmdId]);
}

List<int> buildPowerManagerCommand(int minutes) {
  return packCommand(0x14, [
    minutes & 0xff,
    (minutes >> 8) & 0xff,
    0x00,
    0x00,
  ]);
}

/// QCY toggles use 0x01 = on, 0x02 (or other) = off.
bool toggleValueFromByte(int byte) => byte == 0x01;
