import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:music_stream_app/core/theme/app_theme.dart';

void main() {
  testWidgets('Тема и базовый виджет рендерятся', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Center(child: Text('Pulse Music')),
        ),
      ),
    );

    expect(find.text('Pulse Music'), findsOneWidget);
  });
}
