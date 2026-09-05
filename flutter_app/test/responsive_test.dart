import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matka_management/core/widgets/responsive.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    double width,
    ValueChanged<ScreenClass> capture,
  ) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capture(Responsive.classOf(context));
            return const SizedBox();
          },
        ),
      ),
    );
  }

  testWidgets('responsive utility classifies mobile, tablet, and desktop',
      (tester) async {
    final captured = <ScreenClass>[];
    await pumpAt(tester, 500, captured.add);
    await pumpAt(tester, 850, captured.add);
    await pumpAt(tester, 1300, captured.add);
    expect(captured, containsAll(ScreenClass.values));
  });
}

