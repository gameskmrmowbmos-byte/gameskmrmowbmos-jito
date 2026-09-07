import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matka_management/features/new_entry/presentation/new_entry_page.dart';

void main() {
  testWidgets('calculator keypad writes selected value into the number field',
      (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatkaEntryTextField(
            controller: controller,
            compact: false,
            maxLength: 14,
            onChanged: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('matka_entry_keypad_trigger')));
    await tester.pumpAndSettle();

    expect(find.byType(MatkaNumberKeypadSheet), findsOneWidget);
    await tester.tap(find.text('SP'));
    await tester.pumpAndSettle();

    expect(controller.text, 'SP');
  });

  testWidgets('calculator keypad appends multiple digits and star',
      (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatkaEntryTextField(
            controller: controller,
            compact: false,
            maxLength: 14,
            onChanged: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('matka_entry_keypad_trigger')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.tap(find.text('*'));
    await tester.pump();

    expect(find.byType(MatkaNumberKeypadSheet), findsOneWidget);
    expect(controller.text, '123*');
  });

  testWidgets('calculator cross removes the last entered character',
      (tester) async {
    final controller = TextEditingController(text: '123');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatkaEntryTextField(
            controller: controller,
            compact: false,
            maxLength: 14,
            onChanged: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('matka_entry_keypad_trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(controller.text, '12');
    expect(find.byType(MatkaNumberKeypadSheet), findsOneWidget);
  });

  testWidgets('calculator Next sends following input to the amount field',
      (tester) async {
    final numberController = TextEditingController(text: '123');
    final amountController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatkaNumberKeypadSheet(
            controller: numberController,
            nextController: amountController,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.tap(find.text('5'));
    await tester.pump();

    expect(numberController.text, '123');
    expect(amountController.text, '5');
  });

  testWidgets('calculator Back sends following input to the number field',
      (tester) async {
    final numberController = TextEditingController(text: '12');
    final amountController = TextEditingController(text: '5');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatkaNumberKeypadSheet(
            controller: amountController,
            backController: numberController,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.tap(find.text('3'));

    expect(numberController.text, '123');
    expect(amountController.text, '5');
  });

  testWidgets('calculator Enter advances without closing the keypad',
      (tester) async {
    final controller = TextEditingController();
    var advanced = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatkaEntryTextField(
            controller: controller,
            compact: false,
            maxLength: 14,
            onChanged: () {},
            keypadOnEnter: () => advanced = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('matka_entry_keypad_trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter'));
    await tester.pumpAndSettle();

    expect(advanced, isTrue);
    expect(find.byType(MatkaNumberKeypadSheet), findsOneWidget);
  });

  testWidgets('calculator Enter moves number input to amount input',
      (tester) async {
    final numberController = TextEditingController(text: '123');
    final amountController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatkaNumberKeypadSheet(
            controller: numberController,
            enterController: () => amountController,
            onEnter: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Enter'));
    await tester.pump();
    await tester.tap(find.text('5'));

    expect(numberController.text, '123');
    expect(amountController.text, '5');
  });

  testWidgets('onscreen number Enter moves input into amount field',
      (tester) async {
    final numberController = TextEditingController();
    final amountController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatkaEntryTextField(
            controller: numberController,
            compact: false,
            maxLength: 14,
            onChanged: () {},
            keypadOnEnter: () {},
            nextEntryNumberController: () => amountController,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('matka_entry_keypad_trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter'));
    await tester.pump();
    await tester.tap(find.text('5'));

    expect(numberController.text, isEmpty);
    expect(amountController.text, '5');
  });

  testWidgets('calculator Enter sends following input to the next box',
      (tester) async {
    final firstController = TextEditingController(text: '123');
    final nextController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatkaNumberKeypadSheet(
            controller: firstController,
            enterController: () => nextController,
            onEnter: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Enter'));
    await tester.pump();
    await tester.tap(find.text('5'));

    expect(firstController.text, '123');
    expect(nextController.text, '5');
  });

  testWidgets('calculator Enter follows resolver targets for jackpot inputs',
      (tester) async {
    final amountController = TextEditingController(text: '10');
    final jackpotNumberController = TextEditingController();
    final jackpotAmountController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatkaNumberKeypadSheet(
            controller: amountController,
            enterTargetFor: (controller) {
              if (identical(controller, amountController)) {
                return jackpotNumberController;
              }
              if (identical(controller, jackpotNumberController)) {
                return jackpotAmountController;
              }
              return null;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Enter'));
    await tester.tap(find.text('7'));
    await tester.tap(find.text('Enter'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('5'));

    expect(amountController.text, '10');
    expect(jackpotNumberController.text, '7');
    expect(jackpotAmountController.text, '25');
  });

  testWidgets('amount Enter resolves a newly created number input',
      (tester) async {
    final amountController = TextEditingController();
    TextEditingController? newNumberController;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatkaNumberKeypadSheet(
            controller: amountController,
            onEnter: () {
              newNumberController = TextEditingController();
            },
            enterController: () => newNumberController,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Enter'));
    await tester.pump();
    await tester.tap(find.text('5'));

    expect(amountController.text, isEmpty);
    expect(newNumberController?.text, '5');
  });
}
