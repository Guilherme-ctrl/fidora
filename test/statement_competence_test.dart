import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/statement_import.dart';
import 'package:financeiro_ai/domain/statement_sheet.dart';
import 'package:financeiro_ai/presentation/widgets/statement_context_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

CreditCard _card({int closingDay = 20}) => CreditCard(
  id: 'c',
  name: 'Nubank',
  bank: 'Nu',
  lastFour: '1234',
  limit: 10000,
  closingDay: closingDay,
  dueDay: 27,
  holder: 'Você',
);

StatementParse _parse(String csv) =>
    parseStatementSheet(readDelimitedCells(csv));

void main() {
  test('takes the month most rows belong to, not the first row', () {
    // A statement always straddles two calendar months. With a card closing on
    // the 20th, purchases from 21 July through 20 August are August's invoice —
    // and the first row here is in July.
    final parse = _parse('''
Data;Descrição;Valor
25/07/2026;A;10,00
02/08/2026;B;10,00
10/08/2026;C;10,00
''');

    expect(inferCompetence(parse, _card()), DateTime(2026, 8));
  });

  test('follows the card closing day, not the calendar', () {
    // The same rows on a card that closes on the 5th land in September for the
    // August purchases.
    final parse = _parse('''
Data;Descrição;Valor
10/08/2026;A;10,00
12/08/2026;B;10,00
''');

    expect(inferCompetence(parse, _card(closingDay: 5)), DateTime(2026, 9));
  });

  test('a single row still yields its own month', () {
    final parse = _parse('Data;Descrição;Valor\n10/08/2026;A;10,00\n');
    expect(inferCompetence(parse, _card()), DateTime(2026, 8));
  });
}
