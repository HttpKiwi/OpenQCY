/// Touch control key / function IDs (QCY protocol).
abstract final class QcyKeyId {
  static const leftSingle = 0x01;
  static const rightSingle = 0x02;
  static const leftDouble = 0x03;
  static const rightDouble = 0x04;
  static const leftTriple = 0x05;
  static const rightTriple = 0x06;
}

/// Function IDs match the order in MeloBuds Pro products.json key_function lists.
abstract final class QcyFuncId {
  static const none = 0x00;
  static const playPause = 0x01;
  static const previous = 0x02;
  static const next = 0x03;
  static const voiceAssistant = 0x04;
  static const volumeUp = 0x05;
  static const volumeDown = 0x06;
  static const gameMode = 0x07;
  static const ancMode = 0x08;
}

/// One configurable gesture (e.g. single tap) for left + right buds.
class KeyGestureDef {
  const KeyGestureDef({
    required this.name,
    required this.leftKeyId,
    required this.rightKeyId,
  });

  final String name;
  final int leftKeyId;
  final int rightKeyId;
}

const meloBudsProKeyGestures = [
  KeyGestureDef(
    name: 'Touch',
    leftKeyId: QcyKeyId.leftSingle,
    rightKeyId: QcyKeyId.rightSingle,
  ),
  KeyGestureDef(
    name: 'Double touch',
    leftKeyId: QcyKeyId.leftDouble,
    rightKeyId: QcyKeyId.rightDouble,
  ),
  KeyGestureDef(
    name: 'Triple touch',
    leftKeyId: QcyKeyId.leftTriple,
    rightKeyId: QcyKeyId.rightTriple,
  ),
];

const meloBudsProKeyFunctions = [
  'Not work',
  'Play/pause',
  'Previous track',
  'Next track',
  'Voice Assistant',
  'Volume up',
  'Volume down',
  'Gaming mode',
  'ANC mode',
];

int funcIdFromUiIndex(int index) => index.clamp(0, meloBudsProKeyFunctions.length - 1);

int uiIndexFromFuncId(int funcId) {
  if (funcId < 0 || funcId >= meloBudsProKeyFunctions.length) return 0;
  return funcId;
}

String labelForFuncId(int funcId) =>
    meloBudsProKeyFunctions[uiIndexFromFuncId(funcId)];

Map<int, int> parseKeyFunctionData(List<int> data) {
  final map = <int, int>{};
  for (var i = 0; i + 1 < data.length; i += 2) {
    map[data[i]] = data[i + 1];
  }
  return map;
}

List<int> serializeKeyFunctions(Map<int, int> mappings) {
  final keys = mappings.keys.toList()..sort();
  final out = <int>[];
  for (final key in keys) {
    out.addAll([key, mappings[key]!]);
  }
  return out;
}

int parsePowerOffMinutes(List<int> params) {
  if (params.length < 2) return autoOffDisabled;
  return params[0] | (params[1] << 8);
}

/// Sentinel value meaning auto power-off is disabled (from products.json).
const autoOffDisabled = 50000;

const autoOffPresetMinutes = <int>[autoOffDisabled, 30, 60, 90, 120];

String labelForAutoOffMinutes(int minutes) {
  if (minutes >= autoOffDisabled || minutes == 0) return 'Never';
  return '$minutes min';
}
