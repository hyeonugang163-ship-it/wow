// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:voyage/app/main.dart';
import 'package:voyage/features/ptt/data/ptt_prefs.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    // Build our app under a ProviderScope, mirroring production bootstrap.
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
        child: const VoyageApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 간단히 루트 위젯이 존재하는지만 확인.
    expect(find.byType(VoyageApp), findsOneWidget);
  });
}
