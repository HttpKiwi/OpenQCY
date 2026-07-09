import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'constants.dart';

/// QCY GATT UUIDs as [Guid] for reliable comparison (16-bit vs 128-bit).
abstract final class QcyGuids {
  static final service = Guid(QcyUuids.service);
  static final command = Guid(QcyUuids.command);
  static final notify = Guid(QcyUuids.notify);
  static final battery = Guid(QcyUuids.battery);
  static final version = Guid(QcyUuids.version);
  static final eq = Guid(QcyUuids.eq);
  static final keyFunction = Guid(QcyUuids.keyFunction);
}

bool isQcyService(Guid uuid) =>
    uuid == QcyGuids.service || uuid.str128.contains('0000a001');

bool guidMatches(Guid uuid, Guid expected) => uuid == expected;
