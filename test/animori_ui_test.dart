import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animori/bean/widget/animori_design.dart';
import 'package:animori/modules/my/watch_stats.dart';
import 'package:animori/pages/menu/animori_navigation.dart';
import 'package:animori/pages/my/my_space_view.dart';
import 'package:animori/pages/popular/discovery_hero.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('MI_Sans_Regular')
      ..addFont(rootBundle.load('assets/fonts/MiSans-Regular.ttf'));
    await font.load();
  });
  for (final size in [const Size(390, 844), const Size(1280, 860)]) {
    for (final brightness in Brightness.values) {
      testWidgets('Glass discovery at $size, $brightness', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var destination = -1;
        var searched = false;
        final key = GlobalKey();
        final wide = size.width >= 900;
        final content = SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AnimoriHeading(
                eyebrow: 'ANIMORI / DISCOVER',
                title: '发现你的下一部心动',
                description: '好故事，值得以更清晰的方式相遇。',
              ),
              const SizedBox(height: 24),
              AnimoriDiscoveryHero(onSearch: () => searched = true),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                children: [
                  for (final name in ['为你发现', '日常', '科幻', '冒险'])
                    ChoiceChip(
                      label: Text(name),
                      selected: name == '为你发现',
                      onSelected: (_) {},
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                '此刻热门',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              AnimoriPanel(
                child: Row(
                  children: [
                    const Icon(Icons.movie_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '探索作品，自动比较可用来源的清晰度与码率。',
                        style: TextStyle(
                          color: brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAnimoriTheme(
              brightness: brightness,
              fontFamily: 'MI_Sans_Regular',
            ),
            home: RepaintBoundary(
              key: key,
              child: AnimoriBackdrop(
                child: Scaffold(
                  body: wide
                      ? Row(
                          children: [
                            SizedBox(
                              width: 228,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: AnimoriNavigation(
                                  vertical: true,
                                  selectedIndex: 0,
                                  onSelect: (i) => destination = i,
                                  onSearch: () => searched = true,
                                ),
                              ),
                            ),
                            Expanded(child: content),
                          ],
                        )
                      : content,
                  bottomNavigationBar: wide
                      ? null
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: AnimoriNavigation(
                            selectedIndex: 0,
                            onSelect: (i) => destination = i,
                            onSearch: () => searched = true,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('资料库'));
        expect(destination, 2);
        await tester.tap(find.text('寻找想看的番剧'));
        expect(searched, isTrue);
        await tester.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = Directory('build/ui-preview')
          ..createSync(recursive: true);
        File(
          '${output.path}/discovery-${wide ? 'desktop' : 'mobile'}-${brightness.name}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  }

  testWidgets('Personal space handles large text and routes tools', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    MyDestination? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAnimoriTheme(brightness: Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.6),
          ),
          child: AnimoriBackdrop(
            child: Scaffold(
              body: MySpaceView(
                stats: const WatchStats(
                  watchedBangumiCount: 12,
                  watchedEpisodeCount: 120,
                ),
                onOpen: (value) => selected = value,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('播放来源'));
    await tester.tap(find.text('播放来源'));
    expect(selected, MyDestination.rules);
  });
}
