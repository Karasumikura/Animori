import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:animori/bean/widget/bangumi_mirror_error_widget.dart';
import 'package:animori/bean/widget/animori_design.dart';
import 'package:animori/pages/popular/discovery_hero.dart';
import 'package:animori/pages/popular/popular_controller.dart';
import 'package:animori/bean/card/bangumi_card.dart';
import 'package:animori/utils/constants.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:window_manager/window_manager.dart';
import 'package:animori/services/logging/logger.dart';
import 'package:animori/services/platform/desktop_window_config.dart';
import 'package:animori/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:animori/utils/device.dart';

class PopularPage extends StatefulWidget {
  const PopularPage({super.key, required this.controller});

  final PopularController controller;

  @override
  State<PopularPage> createState() => _PopularPageState();
}

class _PopularPageState extends State<PopularPage> {
  late final ScrollController scrollController;
  PopularController get popularController => widget.controller;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController(
      initialScrollOffset: popularController.scrollOffset,
    );
    scrollController.addListener(scrollListener);
    if (popularController.trendList.isEmpty) {
      popularController.queryBangumiByTrend();
    }
  }

  @override
  void dispose() {
    scrollController.removeListener(scrollListener);
    scrollController.dispose();
    super.dispose();
  }

  void scrollListener() {
    popularController.scrollOffset = scrollController.offset;
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !popularController.isLoadingMore) {
      AnimoriLogger().i(
        'PopularPageController: Fetching next recommendation batch',
      );
      if (popularController.currentTag != '') {
        popularController.queryBangumiByTag();
      } else {
        popularController.queryBangumiByTrend();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  dtb.DragToMoveArea(
                    child: AnimoriHeading(
                      eyebrow: 'ANIMORI / DISCOVER',
                      title: '发现你的下一部心动',
                      description: '好故事，值得以更清晰的方式相遇。',
                      action: Wrap(children: buildActions()),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const AnimoriDiscoveryHero(),
                  const SizedBox(height: 24),
                  Observer(
                    builder: (_) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final tag in ['', ...defaultAnimeTags])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(tag.isEmpty ? '为你发现' : tag),
                                selected: popularController.currentTag == tag,
                                onSelected: (_) => _selectTag(tag),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Observer(
                    builder: (_) => Row(
                      children: [
                        Expanded(
                          child: Text(
                            popularController.currentTag.isEmpty
                                ? '此刻热门'
                                : popularController.currentTag,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              context.pushNamed('/settings/history/'),
                          icon: const Icon(Icons.history_rounded, size: 18),
                          label: const Text('继续观看'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Observer(
            builder: (_) {
              if (popularController.isTimeOut) {
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 360,
                    child: BangumiMirrorErrorWidget(
                      onRetry: () => popularController.currentTag.isEmpty
                          ? popularController.queryBangumiByTrend(type: 'init')
                          : popularController.queryBangumiByTag(type: 'init'),
                      onSettingsReturned: () {
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                );
              }
              final items = popularController.currentTag.isEmpty
                  ? popularController.trendList
                  : popularController.bangumiList;
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final count = (constraints.crossAxisExtent / 170)
                        .floor()
                        .clamp(2, 7);
                    final cardWidth =
                        (constraints.crossAxisExtent - (count - 1) * 16) /
                        count;
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: count,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 24,
                        mainAxisExtent:
                            cardWidth / 0.68 +
                            MediaQuery.textScalerOf(context).scale(64),
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            BangumiCardV(bangumiItem: items[index]),
                        childCount: items.length,
                      ),
                    );
                  },
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Observer(
              builder: (_) => popularController.isLoadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox(height: 24),
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> buildActions() => [
    IconButton(
      tooltip: '搜索番剧',
      onPressed: () => context.pushNamed('/search/'),
      icon: const Icon(Icons.search_rounded),
    ),
    if (isDesktop() && !DesktopWindowConfig.showWindowButton)
      IconButton(
        tooltip: '关闭窗口',
        onPressed: () => windowManager.close(),
        icon: const Icon(Icons.close_rounded),
      ),
  ];

  Future<void> _selectTag(String selected) async {
    if (!mounted || selected == popularController.currentTag) return;
    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    popularController.setCurrentTag(selected);
    if (selected.isEmpty) {
      popularController.clearBangumiList();
      if (popularController.trendList.isEmpty) {
        await popularController.queryBangumiByTrend();
      }
    } else {
      await popularController.queryBangumiByTag(type: 'init');
    }
  }
}
