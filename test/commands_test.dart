import 'package:flutter_test/flutter_test.dart';
import 'package:melo_control/core/qcy/commands.dart';

void main() {
  test('buildToggleCommand uses 01/02', () {
    final on = buildLdacCommand(true);
    expect(on[2], 0x23);
    expect(on[4], 0x01);
    final off = buildLdacCommand(false);
    expect(off[4], 0x02);
  });

  test('buildVolumeCommand clamps', () {
    final p = buildVolumeCommand(120, -5);
    expect(p[4], 100);
    expect(p[5], 0);
  });
}
