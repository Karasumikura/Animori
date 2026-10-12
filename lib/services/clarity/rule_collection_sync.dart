import 'package:animori/plugins/plugins_controller.dart';

/// 全量规则同步结果。
class RuleSyncOutcome {
  const RuleSyncOutcome({
    required this.total,
    required this.added,
    required this.updated,
    required this.failed,
    required this.wasCancelled,
  });

  final int total;
  final int added;
  final int updated;
  final int failed;
  final bool wasCancelled;

  int get changed => added + updated;
}

/// 规则集合同步器：把规则仓库里的全部规则下载到本地。
///
/// 本地缺失的安装、版本落后的更新、已最新的跳过。规则只在本地持久化一次，
/// 后续扫描直接复用，不会重复下载。
class RuleCollectionSync {
  RuleCollectionSync(this._controller);

  final PluginsController _controller;
  bool _cancelled = false;

  /// 在处理下一条规则前取消；已开始的单条下载会走完。
  void cancel() => _cancelled = true;

  Future<RuleSyncOutcome> synchronizeAll({
    void Function(int done, int total, String current)? onProgress,
  }) async {
    final catalog = await _controller.ensurePluginCatalog();

    var added = 0;
    var updated = 0;
    var failed = 0;
    var done = 0;

    for (final item in catalog) {
      if (_cancelled) break;
      final status = _controller.pluginStatus(item);
      if (status == PluginCatalogItemStatus.installed) {
        done++;
        onProgress?.call(done, catalog.length, item.name);
        continue;
      }

      onProgress?.call(done, catalog.length, item.name);
      try {
        final result = await _controller.tryUpdatePluginByName(item.name);
        if (result == PluginUpdateResult.updated) {
          if (status == PluginCatalogItemStatus.update) {
            updated++;
          } else {
            added++;
          }
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
      done++;
      onProgress?.call(done, catalog.length, item.name);
    }

    return RuleSyncOutcome(
      total: catalog.length,
      added: added,
      updated: updated,
      failed: failed,
      wasCancelled: _cancelled,
    );
  }
}
