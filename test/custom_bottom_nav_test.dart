import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuims_unofficial2/ui/common/custom_bottom_nav.dart';

void main() {
  testWidgets('CustomBottomNav renders and handles taps correctly in light theme', (tester) async {
    int selectedIndex = 1;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: const Center(child: Text('Content')),
          bottomNavigationBar: StatefulBuilder(
            builder: (context, setState) {
              return CustomBottomNav(
                currentIndex: selectedIndex,
                onTabSelected: (index) {
                  setState(() {
                    selectedIndex = index;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(CustomBottomNav), findsOneWidget);
    expect(find.text('My Courses'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);

    // Tap My Courses (index 0)
    await tester.tap(find.text('My Courses'));
    await tester.pumpAndSettle();
    expect(selectedIndex, 0);

    // Tap Dashboard center button (index 1) by tapping the top edge of the circle
    final fabFinder = find.byIcon(Icons.dashboard_rounded);
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();
    expect(selectedIndex, 1);

    // Tap Settings (index 2)
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(selectedIndex, 2);
  });

  testWidgets('CustomBottomNav renders correctly in dark theme', (tester) async {
    int selectedIndex = 1;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: const Center(child: Text('Dark Content')),
          bottomNavigationBar: CustomBottomNav(
            currentIndex: selectedIndex,
            onTabSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    expect(find.byType(CustomBottomNav), findsOneWidget);
    expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
  });

  test('CustomBottomNav buttonDiameter is enlarged for enhanced center presence', () {
    expect(CustomBottomNav.buttonDiameter, 62.0);
    expect(CustomBottomNav.topProtrusion, 26.0);
  });
}
