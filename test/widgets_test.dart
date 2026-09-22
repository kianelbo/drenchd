import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drenchd/theme.dart';
import 'package:drenchd/ui/widgets.dart';

void main() {
  group('shared widgets', () {
    testWidgets('Panel renders child content with a Material theme surface', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Panel(
              child: Text('Hello panel'),
            ),
          ),
        ),
      );

      expect(find.text('Hello panel'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('SectionTitle and EmptyState render the supplied text and action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                const SectionTitle(
                  'Trends',
                  trailing: Chip(label: Text('All time')),
                ),
                const EmptyState(
                  title: 'Nothing yet',
                  message: 'Log your first intake to see activity here.',
                  action: FilledButton(
                    onPressed: null,
                    child: Text('Add first intake'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Trends'), findsOneWidget);
      expect(find.text('All time'), findsOneWidget);
      expect(find.text('Nothing yet'), findsOneWidget);
      expect(find.text('Add first intake'), findsOneWidget);
    });

    testWidgets('MetricTile and ShareBar show their values in the expected forms', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Column(
              children: [
                MetricTile(value: '42', label: 'total uses'),
                ShareBar(fraction: 1.5, color: Colors.green),
              ],
            ),
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
      expect(find.text('total uses'), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.value, 1.0);
    });

    testWidgets('confirm builds a cancel and confirm dialog flow', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    result = await confirm(
                      context,
                      title: 'Delete item',
                      message: 'This action cannot be undone.',
                    );
                  },
                  child: const Text('Open dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete item'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('showToast pushes a snackbar with the message text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => showToast(context, 'Saved!'),
                  child: const Text('Save'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Saved!'), findsOneWidget);
    });
  });
}
