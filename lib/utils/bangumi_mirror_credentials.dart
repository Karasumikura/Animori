// Bangumi mirror API credentials for the search signature flow.
// Release/PR CI injects them via --dart-define=ANIMORI_APPID / ANIMORI_KEY.
const Map<String, String> bangumiMirrorCredentials = {
  'id': String.fromEnvironment('ANIMORI_APPID'),
  'value': String.fromEnvironment('ANIMORI_KEY'),
};
