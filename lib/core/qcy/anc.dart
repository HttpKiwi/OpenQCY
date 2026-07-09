import 'packet.dart';

/// MeloBuds Pro ANC modes using QCY packed cmdids (command 0x17).
enum AncMode {
  off,
  indoor,
  commuting,
  noisy,
  antiWind,
  adaptive,
  transparency;

  String get label => switch (this) {
        AncMode.off => 'Off',
        AncMode.indoor => 'ANC',
        AncMode.commuting => 'Outdoor',
        AncMode.noisy => 'Noisy',
        AncMode.antiWind => 'Wind',
        AncMode.adaptive => 'Adaptive',
        AncMode.transparency => 'Transparency',
      };

  int get packed => switch (this) {
        AncMode.off => 131072,
        AncMode.indoor => 65794,
        AncMode.commuting => 66050,
        AncMode.noisy => 66306,
        AncMode.antiWind => 66560,
        AncMode.adaptive => 66816,
        AncMode.transparency => 196868,
      };

  /// Decode mode/sub/noise from a 0x17 notification ack.
  static AncMode? fromAck(int mode, int subScene, int noise) {
    for (final m in AncMode.values) {
      final (mMode, mSub, mNoise) = unpackPacked(m.packed);
      if (mMode == mode && mSub == subScene && mNoise == noise) {
        return m;
      }
    }
    // Transparency ack sometimes reports sub=1.
    if (mode == 3 && (subScene == 1 || subScene == 2)) {
      return AncMode.transparency;
    }
    if (mode == 2 && subScene == 0 && noise == 0) return AncMode.off;
    if (mode == 1 && subScene == 1) return AncMode.indoor;
    if (mode == 1 && subScene == 2) return AncMode.commuting;
    if (mode == 1 && subScene == 5) return AncMode.adaptive;
    return null;
  }
}

(int mode, int subScene, int noise) unpackPacked(int packed) {
  return (
    (packed >> 16) & 0xFF,
    (packed >> 8) & 0xFF,
    packed & 0xFF,
  );
}

List<int> buildAncCommand(AncMode mode) {
  var (m, sub, noise) = unpackPacked(mode.packed);
  // Official app remaps transparency (3,1,0) → (3,2,0).
  if (m == 3 && sub == 1 && noise == 0) {
    sub = 2;
  }
  return packCommand(0x17, [m, sub, noise]);
}
