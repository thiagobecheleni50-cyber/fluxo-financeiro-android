import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluxo_financeiro/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Fluxo Financeiro renders, loads sample, adds and deletes items',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FluxoFinanceiroApp());
    await tester.pumpAndSettle();

    expect(find.text('Fluxo Financeiro'), findsOneWidget);
    expect(find.text('Entrada'), findsOneWidget);
    expect(find.text('Saída'), findsOneWidget);
    expect(find.text('Gráfico em Porcentagem'), findsOneWidget);

    // Scroll to and tap sample data button
    final scrollable = find.byType(Scrollable).first;
    final sampleBtn = find.text('Carregar exemplo para testar');
    await tester.scrollUntilVisible(sampleBtn, 200, scrollable: scrollable);
    await tester.ensureVisible(sampleBtn);
    await tester.pumpAndSettle();
    await tester.tap(sampleBtn);
    await tester.pumpAndSettle();

    expect(find.text('Cartões de Crédito'), findsWidgets);
    expect(find.text('Energia'), findsWidgets);
    expect(find.text('Internet'), findsWidgets);
    expect(find.text('Gasolina'), findsWidgets);

    // Scroll back up and add an expense via Saída button
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    final saidaBtn = find.text('Saída');
    await tester.ensureVisible(saidaBtn);
    await tester.pumpAndSettle();
    await tester.tap(saidaBtn);
    await tester.pumpAndSettle();

    expect(find.text('Nova Saída'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '150,00');
    await tester.tap(find.text('Salvar Saída'));
    await tester.pumpAndSettle();

    // Scroll to transactions and delete one item
    final deleteButtons = find.byTooltip('Excluir lançamento');
    await tester.scrollUntilVisible(deleteButtons.first, 250,
        scrollable: scrollable);
    await tester.ensureVisible(deleteButtons.first);
    await tester.pumpAndSettle();
    final beforeDelete = tester.widgetList(deleteButtons).length;
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    expect(
      tester.widgetList(find.byTooltip('Excluir lançamento')).length,
      beforeDelete - 1,
    );
  });
}
