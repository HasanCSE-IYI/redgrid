import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redgrid/core/strings_bn.dart';
import 'package:redgrid/ui/about_dialog.dart';

void main() {
  testWidgets('AboutAppDialog shows developer, phone, support info and NO licenses', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AboutAppDialog.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify Developer Info
    expect(find.text(Strings.developedBy), findsOneWidget);

    // Verify Phone & Sadaqah Jariyah Support
    expect(find.text(Strings.devPhone), findsOneWidget);
    expect(find.text(Strings.sadaqahSupportTitle), findsOneWidget);
    expect(find.text(Strings.sadaqahSupportDesc), findsOneWidget);

    // Verify Badges
    expect(find.text('WhatsApp'), findsNWidgets(2)); // Badge and Button
    expect(find.text('বিকাশ (bKash)'), findsOneWidget);
    expect(find.text('নগদ (Nagad)'), findsOneWidget);

    // Verify that NO license buttons or text exist
    expect(find.text('VIEW LICENSES'), findsNothing);
    expect(find.text('লাইসেন্স'), findsNothing);
    expect(find.text('View licenses'), findsNothing);

    // Tap Close button
    await tester.tap(find.text('বন্ধ করুন'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed
    expect(find.text(Strings.developedBy), findsNothing);
  });
}
