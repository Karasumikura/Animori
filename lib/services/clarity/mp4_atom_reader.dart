import 'dart:typed_data';

/// 从 MP4（ISO-BMFF）字节片段里提取的基础媒体信息。
class Mp4Basics {
  const Mp4Basics({this.duration, this.width, this.height});

  final Duration? duration;
  final int? width;
  final int? height;

  bool get hasDuration => duration != null && duration!.inMicroseconds > 0;
  bool get hasFrameSize => width != null && height != null;

  Mp4Basics merge(Mp4Basics other) => Mp4Basics(
        duration: duration ?? other.duration,
        width: width ?? other.width,
        height: height ?? other.height,
      );
}

/// 只扫描 `mvhd` / `tkhd` 两类 atom 的轻量读取器。
///
/// 不重建完整 box 树，因此 moov 位于文件头或文件尾的点播文件都能覆盖；
/// 对无法判断的内容返回空结果而不是抛异常。
class Mp4AtomReader {
  Mp4AtomReader._();

  // FourCC 拼成 32 位整数，避免逐字节比对。
  static const int _fourccMvhd = 0x6D766864; // 'mvhd'
  static const int _fourccTkhd = 0x746B6864; // 'tkhd'
  static const int _fourccMoov = 0x6D6F6F76; // 'moov'

  static const Duration _maxPlausible = Duration(hours: 24);

  static Mp4Basics read(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var result = const Mp4Basics();

    for (final pos in _scanFourcc(bytes, _fourccMvhd)) {
      final parsed = _readMovieHeader(data, pos + 4);
      if (parsed != null) {
        result = result.merge(Mp4Basics(duration: parsed));
        break;
      }
    }

    for (final pos in _scanFourcc(bytes, _fourccTkhd)) {
      final parsed = _readTrackHeader(data, pos + 4);
      if (parsed != null) {
        result = result.merge(Mp4Basics(width: parsed.$1, height: parsed.$2));
        break;
      }
    }

    return result;
  }

  /// 沿顶层 atom 行走，返回 moov 的起始偏移。
  ///
  /// moov 已在 [head] 内时返回其偏移；若某个 atom（通常是巨大的 mdat）
  /// 延伸到 [head] 之外，返回该 atom 的结束位置（即下一个 atom 起点），
  /// 调用方可从该处继续读取。无法判断时返回 null。
  static int? moovBeyondGap(Uint8List head) {
    final data = ByteData.sublistView(head);
    var offset = 0;
    while (offset + 8 <= head.length) {
      var size = data.getUint32(offset);
      var header = 8;
      if (size == 1) {
        if (offset + 16 > head.length) return null;
        size = data.getUint64(offset + 8);
        header = 16;
      } else if (size == 0) {
        return null;
      }
      if (size < header) return null;

      if (data.getUint32(offset + 4) == _fourccMoov) return offset;

      final next = offset + size;
      if (next > head.length) return next;
      offset = next;
    }
    return null;
  }

  static Duration? _readMovieHeader(ByteData data, int body) {
    if (body + 4 > data.lengthInBytes) return null;
    final version = data.getUint8(body);

    int timescaleOffset;
    int durationOffset;
    if (version == 0) {
      timescaleOffset = body + 12;
      durationOffset = body + 16;
      if (durationOffset + 4 > data.lengthInBytes) return null;
    } else if (version == 1) {
      timescaleOffset = body + 20;
      durationOffset = body + 24;
      if (durationOffset + 8 > data.lengthInBytes) return null;
    } else {
      return null;
    }

    final timescale = data.getUint32(timescaleOffset);
    final int units;
    if (version == 0) {
      units = data.getUint32(durationOffset);
    } else {
      units = data.getUint64(durationOffset);
    }
    if (timescale <= 0 || units <= 0) return null;

    final micros = (units * Duration.microsecondsPerSecond / timescale).round();
    final duration = Duration(microseconds: micros);
    if (duration > _maxPlausible) return null;
    return duration;
  }

  static (int, int)? _readTrackHeader(ByteData data, int body) {
    if (body + 4 > data.lengthInBytes) return null;
    final version = data.getUint8(body);

    // 到 matrix 之前固定字段的长度。
    final int prefix = version == 0
        ? 4 + 4 + 4 + 4 + 4 + 4 + 8 + 2 + 2 + 2 + 2
        : version == 1
            ? 4 + 8 + 8 + 4 + 4 + 8 + 8 + 2 + 2 + 2 + 2
            : 0;
    if (prefix == 0) return null;

    final widthPos = body + prefix + 36;
    if (widthPos + 8 > data.lengthInBytes) return null;

    final width = data.getUint32(widthPos) >> 16; // 16.16 定点
    final height = data.getUint32(widthPos + 4) >> 16;
    if (width < 16 || height < 16 || width > 16384 || height > 16384) {
      return null;
    }
    return (width, height);
  }

  static Iterable<int> _scanFourcc(Uint8List bytes, int fourcc) sync* {
    final last = bytes.length - 4;
    for (var i = 0; i <= last; i++) {
      if (bytes[i + 3] != (fourcc & 0xFF)) continue;
      if (ByteData.sublistView(bytes).getUint32(i) == fourcc) yield i;
    }
  }
}
