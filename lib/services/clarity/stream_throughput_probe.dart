import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:animori/request/clients/download_http_client.dart';
import 'package:animori/request/core/network_exception.dart';
import 'package:animori/services/clarity/clarity_models.dart';
import 'package:animori/services/clarity/mp4_atom_reader.dart';
import 'package:animori/utils/m3u8_parser.dart';

/// 测量失败。
class ProbeException implements Exception {
  const ProbeException(this.message);
  final String message;
  @override
  String toString() => 'ProbeException: $message';
}

/// 一次字节窗口读取的结果。
class ByteWindow {
  const ByteWindow({required this.bytes, this.contentLength});
  final Uint8List bytes;

  /// 整个资源的总长度；服务端未给出时为 null。
  final int? contentLength;
}

/// 媒体字节读取的抽象，便于在测试里替换为内存实现。
abstract class MediaFetcher {
  Future<String> readText(
    String url,
    Map<String, String> headers, {
    CancelToken? cancel,
    int? capBytes,
  });

  Future<ByteWindow> readWindow(
    String url,
    Map<String, String> headers, {
    String? range,
    required int maxBytes,
    CancelToken? cancel,
  });
}

/// 一次测量的读数。
class ProbeReading {
  const ProbeReading({
    required this.bitrateKbps,
    required this.kind,
    this.videoWidth,
    this.videoHeight,
    this.throughputMbps,
  });

  final int bitrateKbps;
  final ClarityKind kind;
  final int? videoWidth;
  final int? videoHeight;
  final double? throughputMbps;
}

/// 给嗅探到的视频地址实测码率与画面尺寸。
///
/// - HLS：下载播放列表中段若干分片，字节数除以分片时长得到码率，
///   画面尺寸取主列表 RESOLUTION。
/// - MP4：Range 读文件头（必要时补读 moov 或文件尾）解析时长与尺寸，
///   总字节数除以时长得到码率。
class StreamThroughputProbe {
  StreamThroughputProbe({MediaFetcher? fetcher, this.sampleCount = 3})
      : _fetcher = fetcher ?? DownloadMediaFetcher();

  final MediaFetcher _fetcher;
  final int sampleCount;

  static const int _playlistCap = 2 * 1024 * 1024;
  static const int _sniffBytes = 4 * 1024;
  static const int _headBytes = 1024 * 1024;
  static const int _tailBytes = 4 * 1024 * 1024;
  static const int _moovBytes = 4 * 1024 * 1024;
  static const int _segmentCap = 64 * 1024 * 1024;

  Future<ProbeReading> measure(
    String url,
    Map<String, String> headers, {
    CancelToken? cancel,
  }) async {
    if (_looksLikePlaylist(url)) return _measureHls(url, headers, cancel);

    // 无扩展名地址先嗅探开头几 KB，避免把整段 mp4 当文本拉取。
    final sniff = await _fetcher.readWindow(
      url,
      headers,
      range: 'bytes=0-${_sniffBytes - 1}',
      maxBytes: _sniffBytes,
      cancel: cancel,
    );
    if (hasPlaylistMarker(sniff.bytes)) {
      return _measureHls(url, headers, cancel);
    }
    return _measureMp4(url, headers, cancel, leading: sniff);
  }

  static bool _looksLikePlaylist(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.m3u8') || path.endsWith('.m3');
  }

  /// 开头是否为 `#EXTM3U`（容忍 BOM 与空白）。
  static bool hasPlaylistMarker(Uint8List bytes) {
    var start = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      start = 3;
    }
    while (start < bytes.length &&
        const [0x20, 0x0A, 0x0D, 0x09].contains(bytes[start])) {
      start++;
    }
    const marker = [0x23, 0x45, 0x58, 0x54, 0x4D, 0x33, 0x55]; // #EXTM3U
    if (bytes.length - start < marker.length) return false;
    for (var i = 0; i < marker.length; i++) {
      if (bytes[start + i] != marker[i]) return false;
    }
    return true;
  }

  Future<String> _readPlaylist(
    String url,
    Map<String, String> headers,
    CancelToken? cancel,
  ) async {
    String content;
    try {
      content =
          await _fetcher.readText(url, headers, cancel: cancel, capBytes: _playlistCap);
    } on NetworkException catch (error) {
      if (error.type == NetworkExceptionType.cancel &&
          !(cancel?.isCancelled ?? false)) {
        throw const ProbeException('播放列表过大，不是 m3u8');
      }
      rethrow;
    }
    if (!content.trimLeft().startsWith('#EXTM3U')) {
      throw const ProbeException('返回内容不是 m3u8 播放列表');
    }
    return content;
  }

  Future<ProbeReading> _measureHls(
    String url,
    Map<String, String> headers,
    CancelToken? cancel,
  ) async {
    var playlistUrl = url;
    var content = await _readPlaylist(playlistUrl, headers, cancel);
    int? width;
    int? height;

    if (M3u8Parser.detectType(content) == M3u8Type.master) {
      final master = M3u8Parser.parseMasterPlaylist(content, playlistUrl);
      if (master.variants.isEmpty) {
        throw const ProbeException('主列表没有可用清晰度');
      }
      final variant = master.bestVariant;
      final frame = parseFrameSize(variant.resolution);
      width = frame?.$1;
      height = frame?.$2;
      playlistUrl = variant.uri;
      content = await _readPlaylist(playlistUrl, headers, cancel);
    }

    final media = M3u8Parser.parseMediaPlaylist(content, playlistUrl);
    final segments = await M3u8Parser.resolveNestedSegments(
      media.segments,
      (nested) => _readPlaylist(nested, headers, cancel),
    );
    if (segments.isEmpty) throw const ProbeException('播放列表没有分片');

    final picked = pickMiddleSegments(segments, sampleCount);
    var totalBytes = 0;
    var totalSeconds = 0.0;
    final clock = Stopwatch()..start();
    for (final segment in picked) {
      _ensureActive(cancel);
      final window = await _fetcher.readWindow(
        segment.uri,
        headers,
        maxBytes: _segmentCap,
        cancel: cancel,
      );
      totalBytes += window.bytes.length;
      totalSeconds += segment.duration;
    }
    clock.stop();

    if (totalSeconds <= 0) throw const ProbeException('分片没有时长信息');
    if (totalBytes <= 0) throw const ProbeException('分片下载为空');

    return ProbeReading(
      bitrateKbps: kbpsFrom(totalBytes, totalSeconds),
      kind: ClarityKind.hls,
      videoWidth: width,
      videoHeight: height,
      throughputMbps: mbpsFrom(totalBytes, clock.elapsedMilliseconds),
    );
  }

  Future<ProbeReading> _measureMp4(
    String url,
    Map<String, String> headers,
    CancelToken? cancel, {
    ByteWindow? leading,
  }) async {
    final clock = Stopwatch()..start();
    final head = leading ??
        await _fetcher.readWindow(
          url,
          headers,
          range: 'bytes=0-${_headBytes - 1}',
          maxBytes: _headBytes,
          cancel: cancel,
        );
    clock.stop();

    var basics = Mp4AtomReader.read(head.bytes);
    final total = head.contentLength;
    if (total == null || total <= 0) {
      throw const ProbeException('服务端未给出文件大小');
    }

    // moov 常落在巨大 mdat 之后：按顶层 atom 推算其位置再精准拉取。
    if (!basics.hasDuration) {
      final moovOffset = Mp4AtomReader.moovBeyondGap(head.bytes);
      if (moovOffset != null &&
          moovOffset >= head.bytes.length &&
          moovOffset < total) {
        _ensureActive(cancel);
        final end = (moovOffset + _moovBytes - 1).clamp(moovOffset, total - 1);
        final window = await _fetcher.readWindow(
          url,
          headers,
          range: 'bytes=$moovOffset-$end',
          maxBytes: _moovBytes,
          cancel: cancel,
        );
        basics = basics.merge(Mp4AtomReader.read(window.bytes));
      }
    }

    if (!basics.hasDuration && total > head.bytes.length) {
      _ensureActive(cancel);
      final tailStart =
          total > _tailBytes ? total - _tailBytes : head.bytes.length;
      final window = await _fetcher.readWindow(
        url,
        headers,
        range: 'bytes=$tailStart-${total - 1}',
        maxBytes: _tailBytes,
        cancel: cancel,
      );
      basics = basics.merge(Mp4AtomReader.read(window.bytes));
    }

    if (!basics.hasDuration) throw const ProbeException('无法读取 mp4 时长');

    return ProbeReading(
      bitrateKbps: kbpsFrom(total, basics.duration!.inMicroseconds / 1e6),
      kind: ClarityKind.mp4,
      videoWidth: basics.width,
      videoHeight: basics.height,
      throughputMbps: mbpsFrom(head.bytes.length, clock.elapsedMilliseconds),
    );
  }

  static void _ensureActive(CancelToken? cancel) {
    if (cancel?.isCancelled ?? false) throw const ProbeException('已取消');
  }

  // ---- 纯函数，便于单测 ----

  static int kbpsFrom(int bytes, double seconds) {
    if (seconds <= 0) return 0;
    return (bytes * 8 / seconds / 1000).round();
  }

  static double? mbpsFrom(int bytes, int elapsedMs) {
    if (elapsedMs <= 0) return null;
    final value = bytes * 8 / (elapsedMs / 1000) / 1e6;
    return (value * 10).round() / 10;
  }

  static (int, int)? parseFrameSize(String? text) {
    if (text == null) return null;
    final match = RegExp(r'(\d+)x(\d+)').firstMatch(text.trim());
    if (match == null) return null;
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  /// 从列表 30%–70% 区间均匀取 [count] 个分片，避开片头片尾。
  static List<M3u8Segment> pickMiddleSegments(
    List<M3u8Segment> segments,
    int count,
  ) {
    if (segments.isEmpty || count <= 0) return const [];
    if (segments.length <= count) return List.of(segments);
    final n = segments.length;
    final start = (n * 0.3).floor().clamp(0, n - 1);
    final end = (n * 0.7).ceil().clamp(start + 1, n);
    final span = end - start;
    final picked = <M3u8Segment>[];
    for (var i = 0; i < count; i++) {
      final denom = (count - 1).clamp(1, count);
      final index = start + ((span - 1) * i / denom).round();
      picked.add(segments[index.clamp(start, end - 1)]);
    }
    return picked;
  }
}

/// 基于 [DownloadHttpClient] 的默认读取实现。
class DownloadMediaFetcher implements MediaFetcher {
  @override
  Future<String> readText(
    String url,
    Map<String, String> headers, {
    CancelToken? cancel,
    int? capBytes,
  }) async {
    final token = CancelToken();
    cancel?.whenCancel.then((_) => token.cancel('cancelled'));
    return DownloadHttpClient.instance.getPlain(
      url,
      headers: headers,
      receiveTimeout: const Duration(seconds: 15),
      cancelToken: token,
      onReceiveProgress: (received, _) {
        if (capBytes != null && received > capBytes) token.cancel('too large');
      },
    );
  }

  @override
  Future<ByteWindow> readWindow(
    String url,
    Map<String, String> headers, {
    String? range,
    required int maxBytes,
    CancelToken? cancel,
  }) async {
    final requestHeaders = Map<String, String>.of(headers);
    if (range != null) requestHeaders['range'] = range;
    final response = await DownloadHttpClient.instance.getStream(
      url,
      headers: requestHeaders,
      receiveTimeout: const Duration(seconds: 30),
      cancelToken: cancel,
    );

    int? contentLength;
    final contentRange = response.headers.value('content-range');
    if (contentRange != null) {
      final match = RegExp(r'/(\d+)').firstMatch(contentRange);
      if (match != null) contentLength = int.tryParse(match.group(1)!);
    } else {
      contentLength =
          int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? '');
    }

    final builder = BytesBuilder(copy: false);
    final body = response.data;
    if (body != null) {
      await for (final chunk in body.stream) {
        builder.add(chunk);
        if (builder.length >= maxBytes) break;
        if (cancel?.isCancelled ?? false) break;
      }
    }
    final bytes = builder.takeBytes();
    return ByteWindow(
      bytes: bytes.length > maxBytes
          ? Uint8List.sublistView(bytes, 0, maxBytes)
          : bytes,
      contentLength: contentLength,
    );
  }
}
