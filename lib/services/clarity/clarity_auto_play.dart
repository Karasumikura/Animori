import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:animori/modules/search/plugin_search_module.dart';
import 'package:animori/pages/info/info_controller.dart';
import 'package:animori/plugins/plugins.dart';
import 'package:animori/plugins/plugins_controller.dart';
import 'package:animori/services/clarity/clarity_models.dart';
import 'package:animori/services/clarity/clarity_memory.dart';
import 'package:animori/services/clarity/clarity_scanner.dart';
import 'package:animori/services/clarity/rule_collection_sync.dart';
import 'package:animori/services/plugin/plugin_search_service.dart';
import 'package:animori/services/storage/storage.dart';

/// 自动播放的阶段。
enum AutoStage { readyingRules, searching, probing, ready, empty, cancelled }

/// 已选定的播放目标。
class LaunchPick {
  const LaunchPick({required this.plugin, required this.hit});
  final Plugin plugin;
  final SearchItem hit;
}

/// 自动选最高来源的总编排：同步规则 → 检索 → 扫描码率 → 选出最高。
///
/// 有该番剧缓存排行榜时走快路径直接给出第一名；否则完整跑一遍并把结果
/// 缓存。选出 [LaunchPick] 后由界面层负责获取播放列表并进入播放器。
class ClarityAutoPlay {
  ClarityAutoPlay({
    required this.infoController,
    this.episodeIndex = 1,
    PluginsController? pluginsController,
  }) : _plugins = pluginsController ?? inject<PluginsController>();

  final InfoController infoController;
  final int episodeIndex;
  final PluginsController _plugins;
  final ClarityMemory _memory = const ClarityMemory();

  PluginSearchService? _search;
  RuleCollectionSync? _ruleSync;
  ClarityScanner? _scanner;

  final ValueNotifier<AutoStage> stage = ValueNotifier(AutoStage.readyingRules);

  /// (done, total, currentName)
  final ValueNotifier<(int, int, String)> ruleProgress =
      ValueNotifier((0, 0, ''));

  ClarityBoard? board;
  bool _usedCache = false;
  bool get usedCache => _usedCache;
  ClarityScanner? get scanner => _scanner;

  Future<LaunchPick?> prepare({bool synchronizeRules = true}) async {
    final item = infoController.bangumiItem;

    final cached = _memory.read(item.id);
    if (cached != null && cached.anyRanked) {
      board = cached;
      _usedCache = true;
      stage.value = AutoStage.ready;
      return _pickFromBoard(cached);
    }

    if (synchronizeRules) {
      stage.value = AutoStage.readyingRules;
      _ruleSync = RuleCollectionSync(_plugins);
      await _ruleSync!.synchronizeAll(
        onProgress: (done, total, current) =>
            ruleProgress.value = (done, total, current),
      );
    }

    stage.value = AutoStage.searching;
    _search = PluginSearchService(
      infoController: infoController,
      pluginsController: _plugins,
    );
    final keyword = item.nameCn.isEmpty ? item.name : item.nameCn;
    if (!_hasFreshSearch()) {
      await _search!.queryAllSource(keyword);
    }

    final targets = _buildTargets();
    if (targets.isEmpty) {
      stage.value = AutoStage.empty;
      return null;
    }

    stage.value = AutoStage.probing;
    _scanner = ClarityScanner(
      bangumiKey: item.id,
      episodeIndex: episodeIndex,
      concurrency: GStorage.getSetting(SettingsKeys.downloadParallelEpisodes),
    );
    final result = await _scanner!.scan(targets);
    if (result == null) {
      stage.value = AutoStage.cancelled;
      return null;
    }
    await _memory.write(result);
    board = result;
    stage.value = AutoStage.ready;
    return _pickFromBoard(result);
  }

  LaunchPick? _pickFromBoard(ClarityBoard value) {
    final top = value.ranked.firstOrNull;
    if (top == null) return null;
    Plugin? plugin;
    for (final candidate in _plugins.pluginList) {
      if (candidate.name == top.sourceName) {
        plugin = candidate;
        break;
      }
    }
    if (plugin == null) return null;
    return LaunchPick(
      plugin: plugin,
      hit: SearchItem(name: top.hitName, src: top.hitSrc),
    );
  }

  bool _hasFreshSearch() {
    final status = infoController.pluginSearchStatus;
    if (status.isEmpty) return false;
    for (final plugin in _plugins.pluginList) {
      final value = status[plugin.name];
      if (value == null || value == PluginSearchStatus.pending) return false;
    }
    return true;
  }

  List<ScanTarget> _buildTargets() {
    final responses = infoController.pluginSearchResponseList;
    final targets = <ScanTarget>[];
    for (final plugin in _plugins.pluginList) {
      if (infoController.pluginSearchStatus[plugin.name] !=
          PluginSearchStatus.success) {
        continue;
      }
      SearchItem? first;
      for (final response in responses) {
        if (response.pluginName == plugin.name && response.data.isNotEmpty) {
          first = response.data.first;
          break;
        }
      }
      if (first != null) {
        targets.add(ScanTarget(plugin: plugin, hit: first));
      }
    }
    return targets;
  }

  void cancel() {
    _ruleSync?.cancel();
    _scanner?.stop();
    _search?.cancel();
  }

  void dispose() {
    cancel();
    stage.dispose();
    ruleProgress.dispose();
    unawaited(_scanner?.dispose());
  }
}
