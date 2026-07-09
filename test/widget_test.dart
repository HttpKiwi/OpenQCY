import 'package:flutter_test/flutter_test.dart';
import 'package:melo_control/core/qcy/anc.dart';

void main() {
  test('AncMode indoor packed value', () {
    expect(AncMode.indoor.packed, 65794);
  });
}
