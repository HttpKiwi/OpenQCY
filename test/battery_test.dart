import 'package:flutter_test/flutter_test.dart';
import 'package:melo_control/core/qcy/advertisement.dart';
import 'package:melo_control/models/device_info.dart';

void main() {
  group('BatteryLevels', () {
    test('fromBytes parses buds and valid case', () {
      final b = BatteryLevels.fromBytes([0x60, 0x64, 0x55]);
      expect(b.left, 96);
      expect(b.right, 100);
      expect(b.caseLevel, 85);
      expect(b.hasCase, isTrue);
    });

    test('fromBytes treats missing case byte as unavailable', () {
      final b = BatteryLevels.fromBytes([0x60, 0x64]);
      expect(b.left, 96);
      expect(b.right, 100);
      expect(b.caseLevel, isNull);
      expect(b.hasCase, isFalse);
    });

    test('fromBytes treats zero case as unavailable', () {
      final b = BatteryLevels.fromBytes([0x60, 0x64, 0x00]);
      expect(b.caseLevel, isNull);
    });

    test('mergedWith keeps advertisement case when GATT omits it', () {
      const adv = QcyAdvertisement(
        vendorId: 19786,
        leftBattery: 90,
        rightBattery: 95,
        boxBattery: 72,
        leftCharging: false,
        rightCharging: false,
        boxCharging: false,
        controlMac: 'aa:bb:cc:dd:ee:ff',
      );

      final gatt = BatteryLevels.fromBytes([0x60, 0x64]);
      final merged = gatt.mergedWith(adv);

      expect(merged.left, 96);
      expect(merged.right, 100);
      expect(merged.caseLevel, 72);
      expect(merged.hasCase, isTrue);
    });

    test('mergedWith prefers live case over advertisement', () {
      const adv = QcyAdvertisement(
        vendorId: 19786,
        leftBattery: 90,
        rightBattery: 95,
        boxBattery: 72,
        leftCharging: false,
        rightCharging: false,
        boxCharging: false,
        controlMac: 'aa:bb:cc:dd:ee:ff',
      );

      final gatt = BatteryLevels.fromBytes([0x60, 0x64, 0x46]);
      final merged = gatt.mergedWith(adv);

      expect(merged.caseLevel, 70);
    });
  });
}
