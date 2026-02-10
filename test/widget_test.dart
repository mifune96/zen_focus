import 'package:flutter_test/flutter_test.dart';
import 'package:zen_focus/main.dart';
import 'package:zen_focus/services/settings_service.dart';

void main() {
  testWidgets('Zen Focus app renders', (WidgetTester tester) async {
    final settings = SettingsService();
    await settings.init();
    await tester.pumpWidget(ZenFocusApp(settingsService: settings));
    expect(find.text('READY TO FOCUS'), findsOneWidget);
  });
}
