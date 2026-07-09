import 'dart:typed_data';

/// One parametric EQ band (QCY EQ v2 format).
class EqBand {
  const EqBand({
    required this.freqHz,
    required this.gainDb,
    this.q = 1.0,
    this.bandType = 0,
  });

  final int freqHz;
  final double gainDb;
  final double q;
  final int bandType;

  EqBand copyWith({
    int? freqHz,
    double? gainDb,
    double? q,
    int? bandType,
  }) {
    return EqBand(
      freqHz: freqHz ?? this.freqHz,
      gainDb: gainDb ?? this.gainDb,
      q: q ?? this.q,
      bandType: bandType ?? this.bandType,
    );
  }
}

class EqParams {
  const EqParams({
    required this.presetIndex,
    required this.masterGainDb,
    required this.bands,
  });

  final int presetIndex;
  final double masterGainDb;
  final List<EqBand> bands;

  EqParams copyWith({
    int? presetIndex,
    double? masterGainDb,
    List<EqBand>? bands,
  }) {
    return EqParams(
      presetIndex: presetIndex ?? this.presetIndex,
      masterGainDb: masterGainDb ?? this.masterGainDb,
      bands: bands ?? this.bands,
    );
  }
}

class EqFeature {
  const EqFeature({
    required this.bandCount,
    required this.minDb,
    required this.maxDb,
    required this.frequencies,
  });

  final int bandCount;
  final double minDb;
  final double maxDb;
  final List<int> frequencies;
}

const meloBudsProEq = EqFeature(
  bandCount: 10,
  minDb: 8,
  maxDb: 8,
  frequencies: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000],
);

int _clampGainCentidb(double db, double limit) {
  final centidb = (db * 100).round().clamp(-1270, 1270);
  final max = (limit * 100).round();
  return centidb.clamp(-max, max);
}

int _readInt16Le(List<int> data, int offset) {
  final view = ByteData.sublistView(Uint8List.fromList(data));
  return view.getInt16(offset, Endian.little);
}

void _writeInt16Le(List<int> out, int value) {
  final bytes = ByteData(2)..setInt16(0, value, Endian.little);
  out.addAll(bytes.buffer.asUint8List());
}

void _writeUint16Le(List<int> out, int value) {
  final bytes = ByteData(2)..setUint16(0, value, Endian.little);
  out.addAll(bytes.buffer.asUint8List());
}

List<EqBand> flatEqBands(List<int> frequencies) {
  return [
    for (final f in frequencies)
      EqBand(freqHz: f, gainDb: 0, q: 1.0, bandType: 0),
  ];
}

EqParams defaultEqParams({
  int presetIndex = 1,
  List<int>? frequencies,
}) {
  final freqs = frequencies ?? meloBudsProEq.frequencies;
  return EqParams(
    presetIndex: presetIndex,
    masterGainDb: 0,
    bands: flatEqBands(freqs),
  );
}

/// Parse EQ v1 notify / characteristic payload (6 bytes per band).
EqParams? parseEqV1Params(List<int> params) {
  if (params.length < 3) return null;

  final presetIndex = params[0];
  final masterGainDb = _readInt16Le(params, 1) / 100.0;
  final bands = <EqBand>[];
  var offset = 3;
  while (offset + 6 <= params.length) {
    final freq = params[offset] | (params[offset + 1] << 8);
    final gainDb = _readInt16Le(params, offset + 2) / 100.0;
    final q = (params[offset + 4] | (params[offset + 5] << 8)) / 100.0;
    bands.add(EqBand(freqHz: freq, gainDb: gainDb, q: q));
    offset += 6;
  }
  if (bands.isEmpty) return null;
  return EqParams(
    presetIndex: presetIndex,
    masterGainDb: masterGainDb,
    bands: bands,
  );
}

EqParams? parseEqData(List<int> data) {
  return parseEqV2Params(data) ?? parseEqV1Params(data);
}

/// Parse EQ v2 notify / request-data payload (after opcode byte).
EqParams? parseEqV2Params(List<int> params) {
  if (params.length < 3) return null;

  final presetIndex = params[0];
  final masterGainDb = _readInt16Le(params, 1) / 100.0;
  final bands = <EqBand>[];
  var offset = 3;
  while (offset + 7 <= params.length) {
    final freq = params[offset] | (params[offset + 1] << 8);
    final gainDb = _readInt16Le(params, offset + 2) / 100.0;
    final q = (params[offset + 4] | (params[offset + 5] << 8)) / 100.0;
    bands.add(
      EqBand(
        freqHz: freq,
        gainDb: gainDb,
        q: q,
        bandType: params[offset + 6],
      ),
    );
    offset += 7;
  }

  if (bands.isEmpty) {
    return null;
  }

  return EqParams(
    presetIndex: presetIndex,
    masterGainDb: masterGainDb,
    bands: bands,
  );
}

/// Body bytes for command 0x22 (without 0xFF framing).
List<int> buildEqV2Body(EqParams params, {double gainLimitDb = 12.7}) {
  final out = <int>[params.presetIndex];
  _writeInt16Le(out, (params.masterGainDb * 100).round());
  for (final band in params.bands) {
    _writeUint16Le(out, band.freqHz);
    _writeInt16Le(out, _clampGainCentidb(band.gainDb, gainLimitDb));
    _writeUint16Le(out, (band.q * 100).round());
    out.add(band.bandType);
  }
  return out;
}

String formatFrequency(int hz) {
  if (hz >= 1000) {
    final k = hz / 1000;
    return k == k.roundToDouble() ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
  }
  return '$hz';
}
