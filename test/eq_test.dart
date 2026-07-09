import 'package:flutter_test/flutter_test.dart';
import 'package:melo_control/core/qcy/commands.dart';
import 'package:melo_control/core/qcy/eq.dart';

void main() {
  test('parseEqV2Params reads bands', () {
    final body = buildEqV2Body(
      EqParams(
        presetIndex: 2,
        masterGainDb: 0,
        bands: const [
          EqBand(freqHz: 1000, gainDb: 2.5, q: 1.0, bandType: 0),
        ],
      ),
    );
    final parsed = parseEqV2Params(body);
    expect(parsed, isNotNull);
    expect(parsed!.presetIndex, 2);
    expect(parsed.bands.length, 1);
    expect(parsed.bands.first.freqHz, 1000);
    expect(parsed.bands.first.gainDb, closeTo(2.5, 0.01));
  });

  test('parseEqV2Params returns null without band data', () {
    expect(parseEqV2Params([1, 0, 0]), isNull);
  });

  test('buildEqV2Command wraps in 0xFF frame', () {
    final packet = buildEqV2Command(
      defaultEqParams(presetIndex: 1, frequencies: [62, 125]),
    );
    expect(packet[0], 0xFF);
    expect(packet[2], 0x22);
  });

  test('formatFrequency labels kilohertz', () {
    expect(formatFrequency(1000), '1k');
    expect(formatFrequency(62), '62');
  });
}
