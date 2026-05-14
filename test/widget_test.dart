import 'package:flutter_test/flutter_test.dart';
import 'package:oyo_app_clean/mvp_shared.dart';

void main() {
  test('normalizes legacy request statuses', () {
    expect(MvpStatus.request('대기'), MvpStatus.open);
    expect(MvpStatus.request('requested'), MvpStatus.open);
    expect(MvpStatus.request('승인'), MvpStatus.approved);
    expect(MvpStatus.request('거절'), MvpStatus.rejected);
  });

  test('normalizes application statuses', () {
    expect(MvpStatus.application('대기'), MvpStatus.applied);
    expect(MvpStatus.application('applied'), MvpStatus.applied);
    expect(MvpStatus.application('승인'), MvpStatus.approved);
    expect(MvpStatus.application('거절'), MvpStatus.rejected);
  });
}
