import 'constants.dart';

class QcyAdvertisement {
  const QcyAdvertisement({
    required this.vendorId,
    required this.leftBattery,
    required this.rightBattery,
    required this.boxBattery,
    required this.leftCharging,
    required this.rightCharging,
    required this.boxCharging,
    required this.controlMac,
  });

  final int vendorId;
  final int leftBattery;
  final int rightBattery;
  final int boxBattery;
  final bool leftCharging;
  final bool rightCharging;
  final bool boxCharging;
  final String controlMac;

  static QcyAdvertisement? parse(List<int> data) {
    if (data.length < 20) return null;

    final vendorId = (data[0] << 8) | data[1];
    final left = data[5];
    final right = data[6];
    final box = data[7];

    String controlMac = '';
    if (data.length >= 17) {
      controlMac = _formatMac([
        data[12],
        data[11],
        data[13],
        data[16],
        data[15],
        data[14],
      ]);
    }

    return QcyAdvertisement(
      vendorId: vendorId,
      leftBattery: left & 0x7F,
      rightBattery: right & 0x7F,
      boxBattery: box & 0x7F,
      leftCharging: left & 0x80 != 0,
      rightCharging: right & 0x80 != 0,
      boxCharging: box & 0x80 != 0,
      controlMac: controlMac,
    );
  }

  static String _formatMac(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
  }

  static QcyAdvertisement? fromManufacturerMap(Map<int, List<int>> data) {
    final payload = data[qcyCompanyId];
    if (payload == null) return null;
    return parse(payload);
  }
}

String productTitleForVendor(int vendorId) {
  return _knownProducts[vendorId] ?? 'QCY Device ($vendorId)';
}

const _knownProducts = <int, String>{
  meloBudsProVendorId: 'QCY MeloBuds Pro',
  23155: 'QCY MeloBuds Neo',
  21020: 'QCY MeloBuds',
};
