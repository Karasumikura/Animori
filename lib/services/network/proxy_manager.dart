import 'package:cached_network_image/cached_network_image.dart';
import 'package:animori/request/core/dio_factory.dart';
import 'package:animori/services/logging/logger.dart';
import 'package:animori/services/network/proxy_aware_image_cache_manager.dart';

// WebView proxies are configured separately by their platform controllers.
class ProxyManager {
  ProxyManager._();

  static void applyProxy() {
    DioFactory.reset();
    _applyImageCacheManager();
    AnimoriLogger().i('Proxy: 网络客户端配置已刷新');
  }

  static void clearProxy() {
    DioFactory.reset();
    _applyImageCacheManager();
    AnimoriLogger().i('Proxy: 网络客户端代理已清除');
  }

  static void _applyImageCacheManager() {
    ProxyAwareImageCacheManager.instance.resetNetworkClients();
    CachedNetworkImageProvider.defaultCacheManager =
        ProxyAwareImageCacheManager.instance;
  }
}
