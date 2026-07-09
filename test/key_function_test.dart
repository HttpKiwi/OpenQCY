import 'package:flutter_test/flutter_test.dart';
import 'package:melo_control/core/qcy/commands.dart';
import 'package:melo_control/core/qcy/key_function.dart';

void main() {
  test('parseKeyFunctionData reads key-value pairs', () {
    final map = parseKeyFunctionData([0x01, 0x03, 0x02, 0x01]);
    expect(map[0x01], 0x03);
    expect(map[0x02], 0x01);
  });

  test('serializeKeyFunctions sorts by key id', () {
    final bytes = serializeKeyFunctions({0x03: 0x02, 0x01: 0x01});
    expect(bytes, [0x01, 0x01, 0x03, 0x02]);
  });

  test('buildPowerManagerCommand packs little-endian minutes', () {
    final packet = buildPowerManagerCommand(60);
    expect(packet[2], 0x14);
    expect(packet[4], 60);
    expect(packet[5], 0);
  });

  test('parsePowerOffMinutes reads uint16 LE', () {
    expect(parsePowerOffMinutes([60, 0]), 60);
    expect(parsePowerOffMinutes([0x50, 0xC3]), 50000);
  });

  test('funcIdFromUiIndex maps product list order', () {
    expect(funcIdFromUiIndex(1), QcyFuncId.playPause);
    expect(funcIdFromUiIndex(8), QcyFuncId.ancMode);
  });
}
