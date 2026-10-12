import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:animori/bean/widget/liquid_glass.dart';
import 'package:animori/modules/search/plugin_search_module.dart';
import 'package:animori/pages/info/info_controller.dart';
import 'package:animori/plugins/plugins.dart';
import 'package:animori/plugins/plugins_controller.dart';
import 'package:animori/services/clarity/clarity_auto_play.dart';
import 'package:animori/services/clarity/clarity_models.dart';
import 'package:animori/services/clarity/clarity_scanner.dart';

/// 自动选择最高清晰度的液态玻璃面板。
///
/// 返回 [LaunchPick] 时由调用方进入播放器；返回 null 表示放弃。
class ClarityScanSheet extends StatefulWidget {
  const ClarityScanSheet({super.key, required this.infoController, this.episodeIndex = 1});

  final InfoController infoController;
  final int episodeIndex;

  @override
  State<ClarityScanSheet> createState() => _ClarityScanSheetState();
}

class _ClarityScanSheetState extends State<ClarityScanSheet> {
  final PluginsController _plugins = inject<PluginsController>();
  late ClarityAutoPlay _coordinator;

  LaunchPick? _top;
  int _countdown = 3;
  Timer? _timer;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _coordinator = ClarityAutoPlay(
      infoController: widget.infoController,
      episodeIndex: widget.episodeIndex,
      pluginsController: _plugins,
    );
    unawaited(_run(autoRules: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _coordinator.dispose();
    super.dispose();
  }

  Future<void> _run({required bool autoRules}) async {
    _timer?.cancel();
    setState(() {
      _top = null;
      _starting = false;
    });
    final pick = await _coordinator.prepare(synchronizeRules: autoRules);
    if (!mounted) return;

    if (pick == null) {
      setState(() {});
      return;
    }
    if (_coordinator.usedCache) {
      // 快路径：已有排名，直接播放最高，几乎无感。
      Navigator.of(context).pop(pick);
      return;
    }
    // 首次扫描完成：展示排名，倒计时自动播放最高。
    setState(() => _top = pick);
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _countdown = 3;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdown--;
      if (_countdown <= 0) {
        timer.cancel();
        _launch(_top);
      } else {
        setState(() {});
      }
    });
  }

  void _launch(LaunchPick? pick) {
    if (pick == null || _starting) return;
    _starting = true;
    _timer?.cancel();
    Navigator.of(context).pop(pick);
  }

  LaunchPick? _pickForGrade(ClarityGrade grade) {
    Plugin? plugin;
    for (final candidate in _plugins.pluginList) {
      if (candidate.name == grade.sourceName) {
        plugin = candidate;
        break;
      }
    }
    if (plugin == null) return null;
    return LaunchPick(
      plugin: plugin,
      hit: SearchItem(name: grade.hitName, src: grade.hitSrc),
    );
  }

  String get _subtitle {
    switch (_coordinator.stage.value) {
      case AutoStage.readyingRules:
        final r = _coordinator.ruleProgress.value;
        return '同步全部规则 ${r.$1}/${r.$2}${r.$3.isEmpty ? '' : ' · ${r.$3}'}';
      case AutoStage.searching:
        return '正在检索所有来源';
      case AutoStage.probing:
        final list = _coordinator.scanner?.progress.value ?? const [];
        final done = list.where((item) => item.isDone).length;
        return '逐个嗅探并实测码率 $done/${list.length}';
      case AutoStage.ready:
        return '已按清晰度排序，最高在最上';
      case AutoStage.empty:
        return '没有来源检索到这部番剧';
      case AutoStage.cancelled:
        return '已取消';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LiquidGlass(
            radius: 32,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _header(),
                Expanded(child: _body()),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return ValueListenableBuilder<AutoStage>(
      valueListenable: _coordinator.stage,
      builder: (context, _, _) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('选择最高清晰度',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(_subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: '关闭',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return ValueListenableBuilder<AutoStage>(
      valueListenable: _coordinator.stage,
      builder: (context, stage, _) {
        switch (stage) {
          case AutoStage.readyingRules:
            return _rulesView();
          case AutoStage.searching:
            return const _CenteredHint(icon: Icons.search_rounded, text: '正在检索所有规则…');
          case AutoStage.probing:
            return _scanList();
          case AutoStage.ready:
            return _rankedList();
          case AutoStage.empty:
            return const _CenteredHint(
                icon: Icons.search_off_rounded, text: '没有来源检索到这部番剧，可修改关键词后重试。');
          case AutoStage.cancelled:
            return const _CenteredHint(icon: Icons.block_rounded, text: '操作已取消。');
        }
      },
    );
  }

  Widget _rulesView() {
    return ValueListenableBuilder<(int, int, String)>(
      valueListenable: _coordinator.ruleProgress,
      builder: (context, value, _) {
        final total = value.$2 == 0 ? 1 : value.$2;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value.$1 / total,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 14),
                Text('下载并安装全部规则 ${value.$1}/${value.$2}',
                    style: Theme.of(context).textTheme.bodyMedium),
                if (value.$3.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(value.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scanList() {
    final scanner = _coordinator.scanner;
    if (scanner == null) return const SizedBox.shrink();
    return ValueListenableBuilder<List<ScanProgress>>(
      valueListenable: scanner.progress,
      builder: (context, list, _) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _scanRow(list[index]),
      ),
    );
  }

  Widget _scanRow(ScanProgress state) {
    final colors = Theme.of(context).colorScheme;
    final finished = state.isDone;
    final ok = state.grade?.hasBitrate ?? false;
    return _rowShell(
      leading: SizedBox(
        width: 22,
        child: finished
            ? Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 20, color: ok ? colors.primary : colors.error)
            : const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      title: state.sourceName,
      detail: state.stageLabel,
      detailColor: ok ? colors.primary : colors.onSurfaceVariant,
    );
  }

  Widget _rankedList() {
    final board = _coordinator.board;
    if (board == null) return const SizedBox.shrink();

    final ranked = board.ranked;
    final rankedNames = ranked.map((g) => g.sourceName).toSet();
    final rest = board.grades.where((g) => !rankedNames.contains(g.sourceName));
    final ordered = [...ranked, ...rest];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
      itemCount: ordered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final grade = ordered[index];
        final placement = board.placementOf(grade.sourceName);
        final isTop = placement == 1;
        final colors = Theme.of(context).colorScheme;
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _launch(_pickForGrade(grade)),
          child: _rowShell(
            leading: SizedBox(
              width: 26,
              child: placement != null
                  ? Text('#$placement',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isTop ? colors.primary : colors.onSurfaceVariant,
                          fontWeight: isTop ? FontWeight.w700 : null))
                  : Icon(Icons.error_outline_rounded,
                      size: 20, color: colors.error),
            ),
            title: grade.sourceName + (isTop ? '  · 最高' : ''),
            sub: [
              if (grade.mediaHost.isNotEmpty) grade.mediaHost,
              if (grade.throughputMbps != null)
                '下载 ${grade.throughputMbps} Mbps',
            ].join(' · '),
            detail: grade.headline,
            detailColor: grade.hasBitrate ? colors.primary : colors.error,
            highlight: isTop,
          ),
        );
      },
    );
  }

  Widget _rowShell({
    required Widget leading,
    required String title,
    String sub = '',
    required String detail,
    required Color detailColor,
    bool highlight = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? colors.primary.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge),
                if (sub.isNotEmpty)
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(detail,
              textAlign: TextAlign.right,
              maxLines: 2,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: detailColor, fontWeight: highlight ? FontWeight.w700 : null)),
        ],
      ),
    );
  }

  Widget _footer() {
    return ValueListenableBuilder<AutoStage>(
      valueListenable: _coordinator.stage,
      builder: (context, stage, _) {
        final isReady = stage == AutoStage.ready && _top != null;
        final showRetry = stage == AutoStage.empty || stage == AutoStage.cancelled;
        if (!isReady && !showRetry) {
          return const SizedBox(height: 12);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
          child: Row(
            children: [
              if (showRetry)
                Expanded(
                  child: LiquidGlassButton(
                    label: '重新扫描',
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      _coordinator.dispose();
                      setState(() {
                        _coordinator = ClarityAutoPlay(
                          infoController: widget.infoController,
                          episodeIndex: widget.episodeIndex,
                          pluginsController: _plugins,
                        );
                      });
                      unawaited(_run(autoRules: false));
                    },
                  ),
                ),
              if (isReady) ...[
                Expanded(
                  child: LiquidGlassButton(
                    label: '播放最高清晰度',
                    icon: Icons.play_arrow_rounded,
                    tone: Theme.of(context).colorScheme.primary,
                    onPressed: () => _launch(_top),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 44,
                  child: Text('${_countdown}s',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
