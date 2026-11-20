import 'package:cinema_app/core/ui/breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TC6: ScreenSize.fromWidth maps widths to breakpoints', () {
    expect(ScreenSize.fromWidth(0), ScreenSize.mobile);
    expect(ScreenSize.fromWidth(599.9), ScreenSize.mobile);
    expect(ScreenSize.fromWidth(600), ScreenSize.tablet);
    expect(ScreenSize.fromWidth(1023.9), ScreenSize.tablet);
    expect(ScreenSize.fromWidth(1024), ScreenSize.desktop);
    expect(ScreenSize.fromWidth(1920), ScreenSize.desktop);
  });
}
