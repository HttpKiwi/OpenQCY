import 'constants.dart';
import 'eq.dart';
import 'key_function.dart';

class AutoOffTimerFeature {
  const AutoOffTimerFeature({
    required this.cmdId,
    required this.disabledMinutes,
  });

  final int cmdId;
  final int disabledMinutes;
}

class ProductFeatures {
  const ProductFeatures({
    required this.eqPresets,
    this.eq,
    this.ldac = false,
    this.sleepMode = false,
    this.spatialAudio = false,
    this.inEarDetection = false,
    this.dualDevice = false,
    this.channelBalance = false,
    this.deviceRename = false,
    this.findEarphone = false,
    this.keyGestures = const [],
    this.keyFunctionLabels = const [],
    this.autoOffTimer,
  });

  final List<String> eqPresets;
  final EqFeature? eq;
  final bool ldac;
  final bool sleepMode;
  final bool spatialAudio;
  final bool inEarDetection;
  final bool dualDevice;
  final bool channelBalance;
  final bool deviceRename;
  final bool findEarphone;
  final List<KeyGestureDef> keyGestures;
  final List<String> keyFunctionLabels;
  final AutoOffTimerFeature? autoOffTimer;

  bool get hasKeyFunctions => keyGestures.isNotEmpty;
}

ProductFeatures featuresForVendor(int vendorId) {
  return _catalog[vendorId] ?? _defaultFeatures;
}

const _defaultFeatures = ProductFeatures(
  eqPresets: ['Default', 'Pop', 'Rock', 'Bass'],
  ldac: true,
  sleepMode: true,
  inEarDetection: true,
  findEarphone: true,
  channelBalance: true,
  deviceRename: true,
);

const _catalog = <int, ProductFeatures>{
  meloBudsProVendorId: ProductFeatures(
    eqPresets: [
      'Spatial',
      'Default',
      'Pop',
      'Heavy Bass',
      'Rock',
      'Soft',
      'Classic',
    ],
    eq: meloBudsProEq,
    ldac: true,
    sleepMode: true,
    dualDevice: true,
    inEarDetection: true,
    findEarphone: true,
    channelBalance: true,
    deviceRename: true,
    keyGestures: meloBudsProKeyGestures,
    keyFunctionLabels: meloBudsProKeyFunctions,
    autoOffTimer: AutoOffTimerFeature(
      cmdId: 0x14,
      disabledMinutes: autoOffDisabled,
    ),
  ),
};
