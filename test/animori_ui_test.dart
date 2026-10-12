import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animori/bean/widget/animori_design.dart';
import 'package:animori/modules/my/watch_stats.dart';
import 'package:animori/pages/menu/animori_navigation.dart';
import 'package:animori/pages/my/my_space_view.dart';
import 'package:animori/pages/popular/popular_page.dart';
import 'package:animori/pages/popular/popular_controller.dart';
import 'package:mobx/mobx.dart';
import 'package:hive_ce/hive.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:file/local.dart';
import 'package:animori/services/storage/storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:animori/modules/bangumi/bangumi_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storage;
  late PathProviderPlatform originalPaths;
  setUpAll(() async {
    storage = await Directory.systemTemp.createTemp('animori_ui_test_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(storage.path);
    Hive.init(storage.path);
    await GStorage.init();
    CachedNetworkImageProvider.defaultCacheManager = _FixtureCache();
    final font = FontLoader('MI_Sans_Regular')
      ..addFont(rootBundle.load('assets/fonts/MiSans-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    await storage.delete(recursive: true);
  });
  final snapshot =
      (jsonDecode(
                File(
                  'test/fixtures/discovery/subjects.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>()
          .map(BangumiItem.fromJson)
          .toList();
  for (final size in [const Size(390, 1100), const Size(1280, 1000)]) {
    for (final brightness in Brightness.values) {
      testWidgets('Glass discovery at $size, $brightness', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var destination = -1;

        final key = GlobalKey();
        final wide = size.width >= 900;
        final controller = PopularController();
        controller.trendList.addAll(snapshot);
        final content = PopularPage(controller: controller);
        await tester.runAsync(() async {
          final extent = size.width - (wide ? 228 : 0) - 48;
          final columns = (extent / 170).floor().clamp(2, 7);
          final width = ((extent - (columns - 1) * 16) / columns).round();
          for (final item in snapshot) {
            final provider = ResizeImage(
              CachedNetworkImageProvider(item.images['large']!),
              width: width,
            );
            final ready = Completer<void>();
            final stream = provider.resolve(ImageConfiguration.empty);
            final listener = ImageStreamListener(
              (_, _) => ready.complete(),
              onError: (Object error, StackTrace? stack) =>
                  ready.completeError(error, stack),
            );
            stream.addListener(listener);
            await ready.future;
            stream.removeListener(listener);
          }
        });
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
                                  onSearch: () {},
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
                            onSearch: () {},
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Let local fixture reads and image decoding finish outside fake time.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<RawImage>(
                find.descendant(
                  of: find.byType(CachedNetworkImage),
                  matching: find.byType(RawImage),
                ),
              )
              .where(
                (image) =>
                    image.image != null &&
                    image.image!.height > image.image!.width,
              ),
          isNotEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('资料库'));
        expect(destination, 2);

        await tester.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = Directory('build/ui-preview')
            ..createSync(recursive: true);
          File(
            '${output.path}/discovery-${wide ? 'desktop' : 'mobile'}-${brightness.name}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
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

  testWidgets('discovery renders trending items after the initial request', (
    tester,
  ) async {
    final request = Completer<void>();
    final controller = _DelayedPopularController(request.future);
    final first = BangumiItem(
      id: 900001,
      type: 2,
      name: 'Daily Popular',
      nameCn: '今日热门测试条目',
      summary: '',
      airDate: '2026-10-12',
      airWeekday: 1,
      rank: 1,
      images: const {},
      tags: const [],
      alias: const [],
      ratingScore: 8.8,
      votes: 100,
      votesCount: const [],
      info: '',
    );
    controller.result = first;
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAnimoriTheme(brightness: Brightness.light),
        home: PopularPage(controller: controller),
      ),
    );
    await tester.pump();
    expect(find.text('今日热门测试条目'), findsNothing);
    request.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('今日热门测试条目'), findsOneWidget);
  });
}

class _DelayedPopularController extends PopularController {
  _DelayedPopularController(this.response);
  final Future<void> response;
  late BangumiItem result;
  @override
  Future<void> queryBangumiByTrend({String type = 'add'}) async {
    runInAction(() => isLoadingMore = true);
    await response;
    runInAction(() {
      trendList.add(result);
      isLoadingMore = false;
    });
  }
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

// Serve the exact downloaded trending snapshot without network or disk cache plugins.
class _FixtureCache implements BaseCacheManager {
  final subjects =
      (jsonDecode(
                File(
                  'test/fixtures/discovery/subjects.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>()
          .map(BangumiItem.fromJson)
          .toList();
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    final item = subjects.firstWhere((item) => item.images['large'] == url);
    yield FileInfo(
      const LocalFileSystem().file('test/fixtures/discovery/${item.id}.jpg'),
      FileSource.Cache,
      DateTime(2100),
      url,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
