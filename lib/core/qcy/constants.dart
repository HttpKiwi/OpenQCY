/// QCY BLE GATT UUIDs (from Quicky docs).
abstract final class QcyUuids {
  static const service = '0000a001-0000-1000-8000-00805f9b34fb';
  static const command = '00001001-0000-1000-8000-00805f9b34fb';
  static const notify = '00001002-0000-1000-8000-00805f9b34fb';
  static const battery = '00000008-0000-1000-8000-00805f9b34fb';
  static const version = '00000007-0000-1000-8000-00805f9b34fb';
  static const eq = '0000000b-0000-1000-8000-00805f9b34fb';
  static const keyFunction = '0000000d-0000-1000-8000-00805f9b34fb';
}

/// QCY manufacturer data company ID.
const qcyCompanyId = 0x521c;

/// MeloBuds Pro vendor id from products.json.
const meloBudsProVendorId = 19786;
