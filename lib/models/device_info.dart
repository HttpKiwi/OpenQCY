class BatteryLevels {
  const BatteryLevels({
    required this.left,
    required this.right,
    required this.caseLevel,
    this.leftCharging = false,
    this.rightCharging = false,
    this.caseCharging = false,
  });

  final int left;
  final int right;
  final int caseLevel;
  final bool leftCharging;
  final bool rightCharging;
  final bool caseCharging;

  static BatteryLevels fromBytes(List<int> data) {
    if (data.length < 3) {
      return const BatteryLevels(left: 0, right: 0, caseLevel: 0);
    }
    return BatteryLevels(
      left: data[0] & 0x7F,
      right: data[1] & 0x7F,
      caseLevel: data[2] & 0x7F,
      leftCharging: data[0] & 0x80 != 0,
      rightCharging: data[1] & 0x80 != 0,
      caseCharging: data[2] & 0x80 != 0,
    );
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
