/// Builds QCY 0xFF-framed command packets for characteristic 00001001.
List<int> packCommand(int opcode, List<int> parameters) {
  final body = <int>[opcode, parameters.length, ...parameters];
  return <int>[0xFF, body.length, ...body];
}

/// Parses one or more commands from a notification payload.
List<({int opcode, List<int> params})> parsePacket(List<int> packet) {
  if (packet.length < 4 || packet[0] != 0xFF) {
    return const [];
  }
  final bodyLen = packet[1];
  if (bodyLen + 2 != packet.length) {
    return const [];
  }

  final commands = <({int opcode, List<int> params})>[];
  var offset = 2;
  while (offset < packet.length) {
    if (offset + 2 > packet.length) break;
    final opcode = packet[offset];
    final paramLen = packet[offset + 1];
    offset += 2;
    if (offset + paramLen > packet.length) break;
    commands.add((
      opcode: opcode,
      params: packet.sublist(offset, offset + paramLen),
    ));
    offset += paramLen;
  }
  return commands;
}

List<int> buildLowLatencyCommand(bool enabled) {
  return packCommand(0x09, [enabled ? 0x01 : 0x02]);
}

List<int> buildLightFlashCommand(bool enabled) {
  return packCommand(0x05, [enabled ? 0x01 : 0x00]);
}
