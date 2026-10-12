import 'dart:io';

import 'package:animori/bean/dialog/dialog_helper.dart';
import 'package:animori/services/player/external_player.dart';

class ExternalPlaybackLauncher {
  final String Function() videoUrl;
  final String Function() referer;

  ExternalPlaybackLauncher({
    required this.videoUrl,
    required this.referer,
  });

  Future<void> launch() async {
    final currentVideoUrl = videoUrl();
    final currentReferer = referer();
    if ((Platform.isAndroid || Platform.isWindows) && currentReferer.isEmpty) {
      if (await ExternalPlayer.launchUrlWithMime(
          currentVideoUrl, 'video/mp4')) {
        AnimoriDialog.showToast(
          message: '尝试唤起外部播放器',
        );
      } else {
        AnimoriDialog.showToast(
          message: '唤起外部播放器失败',
        );
      }
    } else if (Platform.isMacOS || Platform.isIOS) {
      if (await ExternalPlayer.launchUrlWithReferer(
          currentVideoUrl, currentReferer)) {
        AnimoriDialog.showToast(
          message: '尝试唤起外部播放器',
        );
      } else {
        AnimoriDialog.showToast(
          message: '唤起外部播放器失败',
        );
      }
    } else if (Platform.isLinux && currentReferer.isEmpty) {
      final result =
          await ExternalPlayer.launchLinuxDesktopPlayer(currentVideoUrl);
      switch (result) {
        case LinuxExternalPlayerResult.launched:
          AnimoriDialog.showToast(message: '尝试唤起外部播放器');
        case LinuxExternalPlayerResult.cancelled:
          break;
        case LinuxExternalPlayerResult.unavailable:
          AnimoriDialog.showToast(message: '系统应用选择器不可用');
        case LinuxExternalPlayerResult.failed:
          AnimoriDialog.showToast(message: '唤起外部播放器失败');
      }
    } else {
      if (currentReferer.isEmpty) {
        AnimoriDialog.showToast(
          message: '暂不支持该设备',
        );
      } else {
        AnimoriDialog.showToast(
          message: '暂不支持该规则',
        );
      }
    }
  }
}
