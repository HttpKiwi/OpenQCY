import 'package:flutter_test/flutter_test.dart';
import 'package:melo_control/core/qcy/anc.dart';
import 'package:melo_control/core/qcy/packet.dart';

void main() {
  test('buildAncCommand packs transparency default', () {
    final packet = buildAncCommand(AncMode.transparency);
    expect(packet[0], 0xFF);
    expect(packet[2], 0x17);
    expect(packet[4], 0x03);
    expect(packet[5], 0x01);
    expect(packet[6], 0x04);
  });

  test('buildAncCommand indoor uses product default', () {
    final packet = buildAncCommand(AncMode.indoor);
    expect(packet[4], 0x01);
    expect(packet[5], 0x01);
    expect(packet[6], 0x02);
  });

  test('parsePacket reads 0x17 ack', () {
    final cmds = parsePacket([0xFF, 0x05, 0x17, 0x03, 0x01, 0x01, 0x02]);
    expect(cmds.length, 1);
    expect(cmds.first.opcode, 0x17);
    expect(AncMode.fromAck(1, 1, 2), AncMode.indoor);
  });
}
