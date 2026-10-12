import 'package:flutter_test/flutter_test.dart';
import 'package:animori/utils/version.dart';

void main() {
  test('GitHub release tags support a v prefix', () {
    expect(needUpdate('1.0.0', 'v1.0.1'), isTrue);
    expect(needUpdate('1.0.0', 'v1.0.0'), isFalse);
    expect(needUpdate('1.1.0', 'v1.0.9'), isFalse);
    expect(needUpdate('v1.0.0', '1.1.0'), isTrue);
  });
}
