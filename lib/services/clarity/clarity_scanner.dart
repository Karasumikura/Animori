import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:animori/modules/search/plugin_search_module.dart';
import 'package:animori/plugins/plugins.dart';
import 'package:animori/request/core/network_exception.dart';
import 'package:animori/services/clarity/clarity_models.dart';
import 'package:animori/services/clarity/stream_throughput_probe.dart';
import 'package:animori/services/logging/logger.dart';
import 'package:animori/services/video_source/video_source_resolver_pool.dart';
import 'package:animori/services/video_source/video_source_service.dart';

/// 待扫描的目标：规则与其在本番剧下的首个搜索结果。
class ScanTarget {
  const ScanTarget({required this.plugin, required this.hit});
  final Plugin plugin;
  final SearchItem hit;
}

enum ScanStage { queued, fetchingRoads, resolvingStream, sampling, finished, failed }

/// 单个来源的扫描进度，供界面刷新。
class ScanProgress {
  const ScanProgress({required this.sourceName, required this.stage, this.grade});

  final String sourceName;
  final ScanStage stage;
  final ClarityGrade? grade;

  bool get isDone =>
      stage == ScanStage.finished || stage == ScanStage.failed;

  String get stageLabel => switch (stage) {
        ScanStage.queued => '等待中',
        ScanStage.fetchingRoads => '获取播放列表',
        ScanStage.resolvingStream => '解析视频地址',
        ScanStage.sampling => '测量码率',
        ScanStage.finished => grade?.headline ?? '完成',
        ScanStage.failed => grade?.failure ?? '失败',
      };

  ScanProgress copyWith({ScanStage? stage, ClarityGrade? grade}) =>
      ScanProgress(
        sourceName: sourceName,
        stage: stage ?? this.stage,
        grade: grade ?? this.grade,
      );
}

/// 对一部番剧的所有来源并发嗅探视频地址并实测码率。
class ClarityScanner {
  ClarityScanner({
    required this.bangumiKey,
    this.episodeIndex = 1,
    int? concurrency,
    StreamThroughputProbe? probe,
    this.resolveTimeout = const Duration(seconds: 30),
  })  : _probe = probe ?? StreamThroughputProbe(),
        concurrency = _limitConcurrency(concurrency);

  final int bangumiKey;
  final int episodeIndex;
  final int concurrency;

  final StreamThroughputProbe _probe;
  final Duration resolveTimeout;
  final VideoSourceResolverPool _pool = VideoSourceResolverPool();
  final CancelToken _cancel = CancelToken();

  final ValueNotifier<List<ScanProgress>> progress =
      ValueNotifier(const []);

  bool _busy = false;
  bool _stopped = false;
  bool _tornDown = false;

  bool get isBusy => _busy;
  bool get isStopped => _stopped;

  static int _limitConcurrency(int? requested) {
    final handheld = Platform.isAndroid || Platform.isIOS;
    final ceiling = handheld ? 2 : 5;
    return (requested ?? (handheld ? 2 : 3)).clamp(1, ceiling);
  }

  /// 扫描 [targets]，返回可持久化的排行榜；被取消返回 null。
  Future<ClarityBoard?> scan(List<ScanTarget> targets) async {
    if (_busy || _tornDown || _stopped) {
      throw StateError('ClarityScanner is busy or finished');
    }
    _busy = true;
    progress.value = [
      for (final target in targets)
        ScanProgress(sourceName: target.plugin.name, stage: ScanStage.queued),
    ];

    _pool.resize(concurrency);
    final queue = List<ScanTarget>.of(targets);
    final workers = List.generate(
      concurrency.clamp(1, targets.isEmpty ? 1 : targets.length),
      (_) => _drain(queue),
    );
    try {
      await Future.wait(workers);
    } finally {
      _busy = false;
    }
    if (_stopped) return null;
    return _assemble();
  }

  /// 只重扫一个来源，其余结果保留，返回合并后的排行榜。
  Future<ClarityBoard?> rescan(ScanTarget target) async {
    if (_tornDown || _stopped) return null;
    if (_busy) throw StateError('ClarityScanner is busy');
    _busy = true;
    _setStage(target.plugin.name, ScanStage.queued);
    try {
      await _runTarget(target);
    } finally {
      _busy = false;
    }
    if (_stopped) return null;
    return _assemble();
  }

  ClarityBoard _assemble() => ClarityBoard(
        bangumiKey: bangumiKey,
        episodeIndex: episodeIndex,
        measuredAt: DateTime.now(),
        grades: [
          for (final item in progress.value)
            item.grade ??
                ClarityGrade(sourceName: item.sourceName, failure: '未完成'),
        ],
      );

  Future<void> _drain(List<ScanTarget> queue) async {
    while (queue.isNotEmpty && !_stopped) {
      await _runTarget(queue.removeAt(0));
    }
  }

  Future<void> _runTarget(ScanTarget target) async {
    final plugin = target.plugin;
    final name = plugin.name;
    try {
      final episodeUrl = await _roadsFor(target, name);
      final videoUrl = await _streamFor(plugin, name, episodeUrl);
      await _gradeFor(target, name, videoUrl);
    } catch (error) {
      if (_stopped) return;
      final reason = _explain(error);
      AnimoriLogger().w('ClarityScanner: $name failed: $reason');
      _setGrade(
        name,
        ScanStage.failed,
        ClarityGrade(
          sourceName: name,
          hitName: target.hit.name,
          hitSrc: target.hit.src,
          failure: reason,
        ),
      );
    }
  }

  Future<String> _roadsFor(ScanTarget target, String name) async {
    final plugin = target.plugin;
    _setStage(name, ScanStage.fetchingRoads);
    final roads = await plugin.queryChapterRoads(
      target.hit.src,
      cancelToken: _cancel,
    );
    _assertLive();
    final road = roads.where((item) => item.data.isNotEmpty).firstOrNull;
    if (road == null) throw const ProbeException('没有可用线路');

    final index = (episodeIndex - 1).clamp(0, road.data.length - 1);
    final episodeUrl = plugin.buildFullUrl(road.data[index]);
    if (episodeUrl.isEmpty) throw const ProbeException('播放页地址为空');
    return episodeUrl;
  }

  Future<String> _streamFor(
    Plugin plugin,
    String name,
    String episodeUrl,
  ) async {
    _setStage(name, ScanStage.resolvingStream);
    final key = 'clarity:$bangumiKey:$name';
    VideoSourceResolverLease? lease;
    while (lease == null) {
      _assertLive();
      lease = _pool.tryAcquire(key);
      lease ??= await Future<void>.delayed(const Duration(milliseconds: 200))
          .then((_) => _pool.tryAcquire(key));
    }
    try {
      final source = await lease.resolve(
        episodeUrl,
        useLegacyParser: plugin.useLegacyParser,
        timeout: resolveTimeout,
      );
      if (source.url.isEmpty) throw const ProbeException('没有嗅探到视频地址');
      return source.url;
    } on VideoSourceTimeoutException {
      throw const ProbeException('嗅探超时');
    } on VideoSourceNotFoundException {
      throw const ProbeException('没有嗅探到视频地址');
    } catch (error) {
      if (error is VideoSourceCancelledException) rethrow;
      lease.retire();
      rethrow;
    } finally {
      _pool.release(lease);
    }
  }

  Future<void> _gradeFor(ScanTarget target, String name, String videoUrl) async {
    _setStage(name, ScanStage.sampling);
    final reading = await _probe.measure(
      videoUrl,
      target.plugin.buildHttpHeaders(),
      cancel: _cancel,
    );
    _assertLive();
    _setGrade(
      name,
      ScanStage.finished,
      ClarityGrade(
        sourceName: name,
        hitName: target.hit.name,
        hitSrc: target.hit.src,
        bitrateKbps: reading.bitrateKbps,
        videoWidth: reading.videoWidth,
        videoHeight: reading.videoHeight,
        throughputMbps: reading.throughputMbps,
        kind: reading.kind,
        mediaHost: Uri.tryParse(videoUrl)?.host ?? '',
      ),
    );
    AnimoriLogger().i(
      'ClarityScanner: $name ${reading.bitrateKbps}kbps $videoUrl',
    );
  }

  void _setStage(String name, ScanStage stage) => _mutate(
        name,
        (current) => current.copyWith(stage: stage),
      );

  void _setGrade(String name, ScanStage stage, ClarityGrade grade) =>
      _mutate(name, (current) => ScanProgress(sourceName: name, stage: stage, grade: grade));

  void _mutate(
    String name,
    ScanProgress Function(ScanProgress) transform,
  ) {
    if (_tornDown) return;
    progress.value = [
      for (final item in progress.value)
        item.sourceName == name ? transform(item) : item,
    ];
  }

  void _assertLive() {
    if (_stopped) throw const VideoSourceCancelledException();
  }

  static String _explain(Object error) {
    if (error is ProbeException) return error.message;
    if (error is ChapterErrorException) return '获取播放列表失败';
    if (error is NetworkException) {
      return switch (error.type) {
        NetworkExceptionType.connectionTimeout ||
        NetworkExceptionType.receiveTimeout ||
        NetworkExceptionType.sendTimeout =>
          '网络超时',
        NetworkExceptionType.badResponse =>
          '服务端返回 ${error.statusCode ?? '错误'}',
        NetworkExceptionType.cancel => '请求被取消',
        _ => '网络错误',
      };
    }
    if (error is DioException) return '网络错误';
    final text = error.toString();
    return text.length > 40 ? '${text.substring(0, 40)}…' : text;
  }

  void stop() {
    if (_stopped) return;
    _stopped = true;
    _cancel.cancel('scan stopped');
    _pool.cancelAll();
  }

  Future<void> dispose() async {
    if (_tornDown) return;
    _tornDown = true;
    stop();
    await _pool.dispose();
    progress.dispose();
  }
}
