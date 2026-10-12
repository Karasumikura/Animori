import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animori/services/clarity/clarity_models.dart';
import 'package:animori/services/clarity/mp4_atom_reader.dart';
import 'package:animori/services/clarity/stream_throughput_probe.dart';
import 'package:animori/utils/m3u8_parser.dart';

// ---- 合成 MP4 的辅助 ----

Uint8List _atom(String type, List<int> body) {
  final size = 8 + body.length;
  return (BytesBuilder()
        ..add([(size >> 24) & 255, (size >> 16) & 255, (size >> 8) & 255, size & 255])
        ..add(type.codeUnits)
        ..add(body))
      .takeBytes();
}

Uint8List _u32(int value) =>
    Uint8List.fromList([(value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, value & 255]);

Uint8List _movieBytes({int seconds = 100, int width = 1920, int height = 1080}) {
  const timescale = 1000;
  final mvhd = _atom('mvhd', <int>[
    0, 0, 0, 0,
    ..._u32(0), ..._u32(0),
    ..._u32(timescale), ..._u32(seconds * timescale),
  ]);
  final tkhd = _atom('tkhd', <int>[
    0, 0, 0, 0,
    ..._u32(0), ..._u32(0), ..._u32(1), ..._u32(0), ..._u32(0),
    ...List<int>.filled(8, 0),
    ...List<int>.filled(8, 0),
    ...List<int>.filled(36, 0),
    ..._u32(width << 16), ..._u32(height << 16),
  ]);
  final moov = _atom('moov', <int>[...mvhd, ..._atom('trak', tkhd)]);
  return Uint8List.fromList(<int>[..._atom('ftyp', 'isom'.codeUnits), ...moov]);
}

// ---- 内存 MediaFetcher ----

class _MemoryFetcher implements MediaFetcher {
  _MemoryFetcher({this.segmentBytes = 250000, this.mp4Total = 10000000});

  final int segmentBytes;
  final int mp4Total;

  static const String _master = '#EXTM3U\n'
      '#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1920x1080\n'
      'media.m3u8\n';

  static String _media(int segments) {
    final b = StringBuffer('#EXTM3U\n');
    for (var i = 0; i < segments; i++) {
      b.write('#EXTINF:10,\nseg$i.ts\n');
    }
    b.write('#EXT-X-ENDLIST\n');
    return b.toString();
  }

  @override
  Future<String> readText(
    String url,
    Map<String, String> headers, {
    CancelToken? cancel,
    int? capBytes,
  }) async {
    if (url.endsWith('media.m3u8')) return _media(12);
    return _master;
  }

  @override
  Future<ByteWindow> readWindow(
    String url,
    Map<String, String> headers, {
    String? range,
    required int maxBytes,
    CancelToken? cancel,
  }) async {
    if (url.contains('.ts')) {
      return ByteWindow(
        bytes: Uint8List(segmentBytes),
        contentLength: segmentBytes,
      );
    }
    // MP4 地址：返回合成头，contentLength 为声明的总大小。
    return ByteWindow(bytes: _movieBytes(), contentLength: mp4Total);
  }
}

void main() {
  group('Mp4AtomReader', () {
    test('reads duration and frame size from synthetic moov', () {
      final basics = Mp4AtomReader.read(_movieBytes(seconds: 1234, width: 1920, height: 804));
      expect(basics.duration!.inSeconds, 1234);
      expect(basics.width, 1920);
      expect(basics.height, 804);
    });

    test('moovBeyondGap returns the offset after a huge mdat', () {
      final ftyp = _atom('ftyp', 'isom'.codeUnits);
      final mdat = (BytesBuilder()
            ..add(_u32(5000000))
            ..add('mdat'.codeUnits)
            ..add(<int>[0, 0, 0, 0]))
          .takeBytes();
      final head = Uint8List.fromList(<int>[...ftyp, ...mdat]);
      expect(Mp4AtomReader.moovBeyondGap(head), ftyp.length + 5000000);
    });

    test('random bytes produce empty basics', () {
      final basics = Mp4AtomReader.read(Uint8List(256));
      expect(basics.hasDuration, false);
      expect(basics.hasFrameSize, false);
    });
  });

  group('StreamThroughputProbe pure helpers', () {
    test('kbpsFrom converts bytes over seconds', () {
      // 250000 bytes in 10 s -> 200 kbps
      expect(StreamThroughputProbe.kbpsFrom(250000, 10), 200);
    });

    test('parseFrameSize reads WxH', () {
      expect(StreamThroughputProbe.parseFrameSize('1920x1080'), (1920, 1080));
      expect(StreamThroughputProbe.parseFrameSize('garbage'), isNull);
    });

    test('pickMiddleSegments stays within the middle band', () {
      final segs = List.generate(
        20,
        (i) => M3u8Segment(uri: 'seg$i', duration: 10, discontinuityGroup: 0),
      );
      final picked = StreamThroughputProbe.pickMiddleSegments(segs, 3);
      expect(picked.length, 3);
      for (final s in picked) {
        final i = int.parse(s.uri.substring(3));
        expect(i >= 6 && i <= 14, isTrue);
      }
    });

    test('hasPlaylistMarker tolerates BOM and whitespace', () {
      expect(
        StreamThroughputProbe.hasPlaylistMarker(Uint8List.fromList('#EXTM3U'.codeUnits)),
        isTrue,
      );
      final bom = Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...'\n #EXTM3U'.codeUnits]);
      expect(StreamThroughputProbe.hasPlaylistMarker(bom), isTrue);
      expect(StreamThroughputProbe.hasPlaylistMarker(Uint8List.fromList('notm3u'.codeUnits)), isFalse);
    });
  });

  group('StreamThroughputProbe end to end', () {
    test('HLS: master -> media -> sampled segments gives bitrate and frame', () async {
      final probe = StreamThroughputProbe(fetcher: _MemoryFetcher(segmentBytes: 250000));
      final reading = await probe.measure('https://x/v.m3u8', const {});
      expect(reading.kind, ClarityKind.hls);
      expect(reading.bitrateKbps, 200);
      expect(reading.videoWidth, 1920);
      expect(reading.videoHeight, 1080);
    });

    test('MP4: total size over moov duration gives bitrate', () async {
      final probe = StreamThroughputProbe(fetcher: _MemoryFetcher(mp4Total: 10000000));
      final reading = await probe.measure('https://x/movie', const {});
      expect(reading.kind, ClarityKind.mp4);
      // 10,000,000 bytes / 100 s -> 800 kbps
      expect(reading.bitrateKbps, 800);
    });
  });

  group('ClarityBoard', () {
    ClarityBoard build() => ClarityBoard(
          bangumiKey: 1,
          episodeIndex: 1,
          measuredAt: DateTime(2026),
          grades: const <ClarityGrade>[
            ClarityGrade(sourceName: 'A', bitrateKbps: 3000),
            ClarityGrade(sourceName: 'B', bitrateKbps: 1000),
            ClarityGrade(sourceName: 'C', failure: '失败'),
          ],
        );

    test('ranked sorts by bitrate descending', () {
      final ranked = build().ranked.map((g) => g.sourceName).toList();
      expect(ranked, ['A', 'B']);
    });

    test('placementOf is 1-based and null when missing', () {
      final board = build();
      expect(board.placementOf('B'), 2);
      expect(board.placementOf('C'), isNull);
    });

    test('arrange tiers ranked, failed, then untouched', () {
      expect(build().arrange(const ['C', 'B', 'A', 'X']), ['A', 'B', 'C', 'X']);
    });

    test('json round trip preserves grades', () {
      final decoded = ClarityBoard.fromJson(build().toJson());
      expect(decoded.bangumiKey, 1);
      expect(decoded.ranked.map((g) => g.sourceName), ['A', 'B']);
      expect(decoded.byName['C']!.failure, '失败');
    });
  });
}
