import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuims_unofficial2/ui/common/slide_scroll_item.dart';

void main() {
  group('SlideScrollItem Tests', () {
    testWidgets('renders child widget and animates fade and slide up', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SlideScrollItem(
              direction: SlideDirection.up,
              index: 0,
              duration: const Duration(milliseconds: 300),
              child: const Text('Test Course Card'),
            ),
          ),
        ),
      );

      // Verify widget is present in tree
      expect(find.text('Test Course Card'), findsOneWidget);

      // Initially starts animating
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Check transitions exist within SlideScrollItem
      expect(
        find.descendant(
          of: find.byType(SlideScrollItem),
          matching: find.byType(SlideTransition),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SlideScrollItem),
          matching: find.byType(FadeTransition),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SlideScrollItem),
          matching: find.byType(ScaleTransition),
        ),
        findsOneWidget,
      );

      // Finish animation
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Test Course Card'), findsOneWidget);
    });

    testWidgets('animates horizontal slide left for horizontal scrolling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  SlideScrollItem(
                    direction: SlideDirection.left,
                    index: 0,
                    duration: const Duration(milliseconds: 300),
                    child: const SizedBox(
                      width: 200,
                      child: Text('Horizontal Event Card'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Horizontal Event Card'), findsOneWidget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Horizontal Event Card'), findsOneWidget);
    });

    testWidgets('staggers entrance animation across multiple items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 4,
              itemBuilder: (context, idx) {
                return SlideScrollItem(
                  index: idx,
                  direction: SlideDirection.up,
                  duration: const Duration(milliseconds: 200),
                  child: ListTile(
                    title: Text('Item $idx'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);

      // Let animations settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });
  });
}
