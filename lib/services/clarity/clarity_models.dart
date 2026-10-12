/// 视频容器类型。
enum ClarityKind {
  hls,
  mp4,
  unknown;

  String get tag => switch (this) {
        ClarityKind.hls => 'hls',
        ClarityKind.mp4 => 'mp4',
        ClarityKind.unknown => '',
      };

  static ClarityKind fromTag(String? value) => switch (value) {
        'hls' => ClarityKind.hls,
        'mp4' => ClarityKind.mp4,
        _ => ClarityKind.unknown,
      };
}

/// 单个播放来源（规则）的清晰度测量结果。
class ClarityGrade {
  const ClarityGrade({
    required this.sourceName,
    this.hitName = '',
    this.hitSrc = '',
    this.bitrateKbps,
    this.videoWidth,
    this.videoHeight,
    this.throughputMbps,
    this.kind = ClarityKind.unknown,
    this.mediaHost = '',
    this.failure,
  });

  final String sourceName;
  final String hitName;
  final String hitSrc;

  /// 实测视频码率（kbps），null 表示未测出。
  final int? bitrateKbps;
  final int? videoWidth;
  final int? videoHeight;

  /// 采样窗口内的实际下载速率（Mbps），仅作参考。
  final double? throughputMbps;
  final ClarityKind kind;

  /// 视频地址主机名，用于识别共用上游的来源。
  final String mediaHost;

  /// 失败原因；成功时为 null。
  final String? failure;

  bool get hasBitrate => bitrateKbps != null && bitrateKbps! > 0;
  bool get hasFrameSize =>
      videoWidth != null && videoHeight != null && videoHeight! > 0;
  String get frameSizeLabel =>
      hasFrameSize ? '${videoWidth}x$videoHeight' : '';

  /// 列表上展示的主文案，例如 `1140 kbps · 1920x804`。
  String get headline {
    if (!hasBitrate) return failure ?? '未探测';
    final parts = <String>['$bitrateKbps kbps'];
    if (hasFrameSize) parts.add(frameSizeLabel);
    return parts.join(' · ');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceName': sourceName,
    'hitName': hitName,
    'hitSrc': hitSrc,
    if (bitrateKbps != null) 'bitrateKbps': bitrateKbps,
    if (videoWidth != null) 'videoWidth': videoWidth,
    if (videoHeight != null) 'videoHeight': videoHeight,
    if (throughputMbps != null) 'throughputMbps': throughputMbps,
    'kind': kind.tag,
    'mediaHost': mediaHost,
    if (failure != null) 'failure': failure,
  };

  factory ClarityGrade.fromJson(Map<String, dynamic> json) {
    return ClarityGrade(
      sourceName: json['sourceName'] as String? ?? '',
      hitName: json['hitName'] as String? ?? '',
      hitSrc: json['hitSrc'] as String? ?? '',
      bitrateKbps: (json['bitrateKbps'] as num?)?.toInt(),
      videoWidth: (json['videoWidth'] as num?)?.toInt(),
      videoHeight: (json['videoHeight'] as num?)?.toInt(),
      throughputMbps: (json['throughputMbps'] as num?)?.toDouble(),
      kind: ClarityKind.fromTag(json['kind'] as String?),
      mediaHost: json['mediaHost'] as String? ?? '',
      failure: json['failure'] as String?,
    );
  }
}

/// 一部番剧某一集的来源清晰度排行榜。
class ClarityBoard {
  ClarityBoard({
    required this.bangumiKey,
    required this.episodeIndex,
    required this.measuredAt,
    required List<ClarityGrade> grades,
  }) : grades = List.unmodifiable(grades);

  final int bangumiKey;
  final int episodeIndex;
  final DateTime measuredAt;
  final List<ClarityGrade> grades;

  Map<String, ClarityGrade> get byName =>
      {for (final grade in grades) grade.sourceName: grade};

  /// 测出码率的来源，按码率从高到低。
  List<ClarityGrade> get ranked =>
      grades.where((grade) => grade.hasBitrate).toList()
        ..sort(ClarityBoard.compareByBitrate);

  bool get anyRanked => grades.any((grade) => grade.hasBitrate);

  /// 1 起的名次；未测出返回 null。
  int? placementOf(String sourceName) {
    final index = ranked.indexWhere((grade) => grade.sourceName == sourceName);
    return index < 0 ? null : index + 1;
  }

  /// 分三档重排来源名：测出码率的按码率降序；探测失败的其次；
  /// 未参与探测的最后。后两档保持传入顺序。
  List<String> arrange(Iterable<String> configured) {
    final original = configured.toList();
    final bitrate = <String, int>{
      for (final grade in ranked) grade.sourceName: grade.bitrateKbps!,
    };
    final probed = <String>{for (final grade in grades) grade.sourceName};

    int tier(String name) {
      if (bitrate.containsKey(name)) return 0;
      if (probed.contains(name)) return 1;
      return 2;
    }

    final indexed = original.asMap().entries.toList()
      ..sort((a, b) {
        final ta = tier(a.value);
        final tb = tier(b.value);
        if (ta != tb) return ta - tb;
        if (ta == 0) return bitrate[b.value]! - bitrate[a.value]!;
        return a.key - b.key;
      });
    return indexed.map((entry) => entry.value).toList();
  }

  /// 码率降序比较器（高在前）。
  static int compareByBitrate(ClarityGrade a, ClarityGrade b) =>
      (b.bitrateKbps ?? 0).compareTo(a.bitrateKbps ?? 0);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'bangumiKey': bangumiKey,
    'episodeIndex': episodeIndex,
    'measuredAt': measuredAt.toIso8601String(),
    'grades': grades.map((grade) => grade.toJson()).toList(),
  };

  factory ClarityBoard.fromJson(Map<String, dynamic> json) {
    return ClarityBoard(
      bangumiKey: (json['bangumiKey'] as num?)?.toInt() ?? 0,
      episodeIndex: (json['episodeIndex'] as num?)?.toInt() ?? 1,
      measuredAt: DateTime.tryParse(json['measuredAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      grades: ((json['grades'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => ClarityGrade.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}
