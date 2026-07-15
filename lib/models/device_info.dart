import '../core/qcy/advertisement.dart';

class BatteryLevels {
  const BatteryLevels({
    required this.left,
    required this.right,
    this.caseLevel,
    this.leftCharging = false,
    this.rightCharging = false,
    this.caseCharging = false,
  });

  final int left;
  final int right;
  final int? caseLevel;
  final bool leftCharging;
  final bool rightCharging;
  final bool caseCharging;

  bool get hasCase => caseLevel != null;

  factory BatteryLevels.fromAdvertisement(QcyAdvertisement adv) {
    return BatteryLevels(
      left: adv.leftBattery,
      right: adv.rightBattery,
      caseLevel: _validCaseLevel(adv.boxBattery),
      leftCharging: adv.leftCharging,
      rightCharging: adv.rightCharging,
      caseCharging: adv.boxCharging,
    );
  }

  static BatteryLevels fromBytes(List<int> data) {
    if (data.isEmpty) {
      return const BatteryLevels(left: 0, right: 0);
    }

    return BatteryLevels(
      left: _budLevel(data[0]),
      right: data.length > 1 ? _budLevel(data[1]) : 0,
      caseLevel: data.length > 2 ? _validCaseLevel(_budLevel(data[2])) : null,
      leftCharging: data[0] & 0x80 != 0,
      rightCharging: data.length > 1 && data[1] & 0x80 != 0,
      caseCharging: data.length > 2 && data[2] & 0x80 != 0,
    );
  }

  /// Prefer live GATT/notify levels but keep case % from scan when the device
  /// omits it (common on MeloBuds Pro when buds are out of the case).
  BatteryLevels mergedWith(
    QcyAdvertisement adv, {
    BatteryLevels? keepCaseFrom,
  }) {
    final mergedCase =
        caseLevel ?? keepCaseFrom?.caseLevel ?? _validCaseLevel(adv.boxBattery);
    final caseFromAdv = mergedCase == _validCaseLevel(adv.boxBattery);

    return BatteryLevels(
      left: left,
      right: right,
      caseLevel: mergedCase,
      leftCharging: leftCharging,
      rightCharging: rightCharging,
      caseCharging: caseCharging || (caseFromAdv && adv.boxCharging),
    );
  }

  static int _budLevel(int byte) => byte & 0x7F;

  static int? _validCaseLevel(int raw) {
    if (raw <= 0 || raw > 100) return null;
    return raw;
  }
}

class FirmwareVersion {
  const FirmwareVersion({required this.left, this.right});

  final String left;
  final String? right;

  static FirmwareVersion fromBytes(List<int> data) {
    String fmt(int a, int b, int c) => '$a.$b.$c';
    if (data.length == 3) {
      return FirmwareVersion(left: fmt(data[0], data[1], data[2]));
    }
    if (data.length >= 6) {
      return FirmwareVersion(
        left: fmt(data[0], data[1], data[2]),
        right: fmt(data[3], data[4], data[5]),
      );
    }
    return const FirmwareVersion(left: 'Unknown');
  }
}
