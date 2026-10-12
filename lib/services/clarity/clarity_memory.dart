import 'dart:convert';

import 'package:animori/services/clarity/clarity_models.dart';
import 'package:animori/services/logging/logger.dart';
import 'package:animori/services/storage/storage.dart';

/// 清晰度排行榜的本地缓存，按番剧 key 存一条 JSON。
class ClarityMemory {
  const ClarityMemory();

  String _boxKey(int bangumiKey) => 'bangumi:$bangumiKey';

  ClarityBoard? read(int bangumiKey) {
    final raw = GStorage.clarityBoards.get(_boxKey(bangumiKey));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ClarityBoard.fromJson(Map<String, dynamic>.from(decoded));
    } catch (error) {
      AnimoriLogger().w(
        'ClarityMemory: drop corrupted board for $bangumiKey',
        error: error,
      );
      return null;
    }
  }

  Future<void> write(ClarityBoard board) async {
    await GStorage.clarityBoards.put(
      _boxKey(board.bangumiKey),
      jsonEncode(board.toJson()),
    );
    await GStorage.clarityBoards.flush();
  }

  Future<void> erase(int bangumiKey) async {
    await GStorage.clarityBoards.delete(_boxKey(bangumiKey));
    await GStorage.clarityBoards.flush();
  }
}
