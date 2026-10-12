import 'package:flutter/material.dart';
import 'package:animori/bean/widget/animori_design.dart';
import 'package:animori/modules/my/watch_stats.dart';

enum MyDestination {
  theme,
  player,
  danmaku,
  rules,
  history,
  downloads,
  sync,
  storage,
  about,
}

class MySpaceView extends StatelessWidget {
  const MySpaceView({super.key, required this.stats, required this.onOpen});
  final WatchStats stats;
  final ValueChanged<MyDestination> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final wide = constraints.maxWidth >= 720;
      final tools = <(MyDestination, IconData, String, String)>[
        (MyDestination.history, Icons.history_rounded, '继续观看', '回到上一次的故事'),
        (
          MyDestination.downloads,
          Icons.download_outlined,
          '离线内容',
          '${stats.downloadTaskCount} 个下载任务',
        ),
        (MyDestination.rules, Icons.hub_outlined, '播放来源', '管理规则，发现更多画质'),
        (
          MyDestination.player,
          Icons.high_quality_outlined,
          '播放偏好',
          '解码、渲染与观看体验',
        ),
        (MyDestination.danmaku, Icons.subtitles_outlined, '弹幕', '让屏幕上的声音更自在'),
        (MyDestination.theme, Icons.blur_on_rounded, '外观', '你的专属观影空间'),
        (MyDestination.sync, Icons.cloud_sync_outlined, '同步', '把观看记录带到其他设备'),
        (MyDestination.storage, Icons.folder_outlined, '存储', '缓存与日志管理'),
        (
          MyDestination.about,
          Icons.info_outline_rounded,
          '关于 Animori',
          '版本与开源信息',
        ),
      ];
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AnimoriHeading(
                  eyebrow: 'YOUR SPACE',
                  title: '故事在这里，继续。',
                  description: '收藏你的喜爱，让每一次观看都如你所愿。',
                ),
                const SizedBox(height: 24),
                AnimoriPanel(
                  child: Wrap(
                    spacing: 48,
                    runSpacing: 24,
                    children: [
                      _stat(context, '${stats.watchedBangumiCount}', '部作品留下足迹'),
                      _stat(context, '${stats.watchedEpisodeCount}', '集已观看'),
                      _stat(context, '${stats.downloadTaskCount}', '个离线任务'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                for (var row = 0; row < tools.length; row += wide ? 3 : 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var i = row;
                          i < row + (wide ? 3 : 1) && i < tools.length;
                          i++
                        )
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: wide && i % 3 != 2 ? 12 : 0,
                              ),
                              child: AnimoriPanel(
                                padding: EdgeInsets.zero,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(28),
                                  onTap: () => onOpen(tools[i].$1),
                                  child: Padding(
                                    padding: const EdgeInsets.all(22),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              tools[i].$2,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const Spacer(),
                                            Icon(
                                              Icons.arrow_outward_rounded,
                                              size: 18,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 22),
                                        Text(
                                          tools[i].$3,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          tools[i].$4,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                height: 1.5,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _stat(BuildContext context, String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class MySettingsButton extends StatelessWidget {
  const MySettingsButton({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.tune_rounded, size: 18),
    label: const Text('设置'),
  );
}
