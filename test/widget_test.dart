import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuims_unofficial2/main.dart';

void main() {
  testWidgets('App smoke test initializes LoginScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CuimsApp(),
      ),
    );

    // Verify CUIMS Portal text is present
    expect(find.text('CUIMS Portal'), findsOneWidget);
  });
}
