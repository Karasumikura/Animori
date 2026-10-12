# Animori 品牌与服务配置

应用使用独立标识 `io.github.karasumikura.animori`、Dart 包名 `animori`、`animori://` 规则分享格式与 `/animoriSync` WebDAV 同步目录。旧应用的安装和数据不会自动合并；规则可通过 JSON 导入。

森林与播放符号的图标源文件位于 `assets/images/logo/animori.svg`。平台图标和启动画面使用该图标的独立导出，不再包含原应用的图标或宣传截图。

更新检查仅使用本项目的 GitHub Releases。规则目录随本仓库的 `assets/rules/` 维护。

默认使用 Bangumi 官方接口，不绑定其他应用的私有镜像服务。自己的兼容镜像可通过以下构建参数配置：

| 参数 | 用途 |
| --- | --- |
| `ANIMORI_BANGUMI_MIRROR_URL` | 可选 Bangumi 镜像根地址；未配置时不提供镜像选项 |
| `ANIMORI_POPULAR_PATH` | 镜像热门列表路径，默认 `/v1/popular/subjects` |
| `ANIMORI_CALENDAR_PATH` | 镜像季度时间表路径，默认 `/v1/calendar/season` |
| `ANIMORI_RULES_MIRROR_URL` | 可选规则镜像根地址，须以 `/` 结尾 |
| `ANIMORI_APPID` / `ANIMORI_KEY` | 自有兼容镜像所需的应用凭据 |

发布流程构建 Android 通用 APK 与 Windows x64 便携 ZIP。Android 使用独立密钥，仓库 Secrets 为 `ANDROID_KEYSTORE_BASE64`、`ANDROID_STORE_PASSWORD`、`ANDROID_KEY_PASSWORD` 和 `ANDROID_KEY_ALIAS`。本地构建可在未跟踪的 `android/key.properties` 配置 `storeFile`、`storePassword`、`keyPassword`、`keyAlias`；正式版本不会回退到调试签名。后续 Android 更新必须继续使用同一密钥。

Windows ZIP 包含程序、DLL 与 data 目录，完整解压后运行 `animori.exe`，当前未配置 Windows 代码签名证书。

代码来源及第三方授权见仓库根目录的 [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md)，主项目许可证见 [LICENSE](../../LICENSE)。
