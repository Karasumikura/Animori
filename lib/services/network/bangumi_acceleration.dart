import 'package:animori/services/storage/storage.dart';
import 'package:animori/request/config/api_endpoints.dart';

enum BangumiAcceleration {
  direct,
  ech,
  mirror;

  static BangumiAcceleration get current =>
      switch (GStorage.getSetting(SettingsKeys.bangumiAcceleration)) {
        'direct' => direct,
        'ech' => ech,
        'mirror' => ApiEndpoints.hasBangumiMirror ? mirror : direct,
        _ =>
          ApiEndpoints.hasBangumiMirror &&
                  GStorage.getSetting(SettingsKeys.enableBangumiProxy)
              ? mirror
              : direct,
      };

  String get label => switch (this) {
    direct => '直连',
    ech => 'ECH',
    mirror => '镜像',
  };
}
