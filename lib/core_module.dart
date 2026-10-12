import 'package:flutter_modular/flutter_modular.dart';
import 'package:animori/pages/collect/collect_controller.dart';
import 'package:animori/pages/download/download_controller.dart';
import 'package:animori/pages/history/history_controller.dart';
import 'package:animori/pages/my/my_controller.dart';
import 'package:animori/plugins/plugins_controller.dart';
import 'package:animori/repositories/collect_crud_repository.dart';
import 'package:animori/repositories/collect_repository.dart';
import 'package:animori/repositories/download_repository.dart';
import 'package:animori/repositories/danmaku_shield_repository.dart';
import 'package:animori/repositories/history_repository.dart';
import 'package:animori/repositories/search_history_repository.dart';
import 'package:animori/services/download/download_manager.dart';
import 'package:animori/services/player/audio_controller.dart';
import 'package:animori/services/player/history_playback_service.dart';
import 'package:animori/services/shaders/shader_asset_service.dart';
import 'package:animori/services/sync/danmaku_shield_sync_service.dart';
import 'package:animori/services/sync/webdav.dart';

/// Root-owned application data and cross-feature coordinators.
///
/// This module intentionally has no path, so its registrations live for the
/// whole application. Page and feature-local state belongs in route `provide`
/// callbacks or path-bearing modules instead.
final coreModule = createModule(
  register: (c) {
    c
      // Repository layer.
      ..addSingleton<ICollectRepository>(CollectRepository.new)
      ..addSingleton<ISearchHistoryRepository>(SearchHistoryRepository.new)
      ..addSingleton<ICollectCrudRepository>(CollectCrudRepository.new)
      ..addSingleton<IHistoryRepository>(HistoryRepository.new)
      ..addSingleton<IDownloadRepository>(DownloadRepository.new)
      ..addSingleton<IDanmakuShieldRepository>(DanmakuShieldRepository.new)
      // Service layer.
      ..addSingleton<IDownloadManager>(DownloadManager.new)
      ..addSingleton<AudioController>(AudioController.new)
      ..addSingleton<HistoryPlaybackService>(HistoryPlaybackService.new)
      ..addSingleton<ShaderAssetService>(ShaderAssetService.new)
      ..addSingleton<WebDav>(WebDav.new)
      ..addSingleton<DanmakuShieldSyncService>(DanmakuShieldSyncService.new)
      // Cross-feature state and coordinators.
      ..addSingleton<PluginsController>(PluginsController.new)
      ..addSingleton<CollectController>(CollectController.new)
      ..addSingleton<HistoryController>(HistoryController.new)
      ..addSingleton<MyController>(MyController.new)
      ..addSingleton<DownloadController>(DownloadController.new);
  },
);
