import 'package:financeiro_ai/domain/receipt_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 8, 18);

  group('parseBrazilianAmount', () {
    test('reads a comma as the decimal separator', () {
      expect(parseBrazilianAmount('45,90'), 45.90);
      expect(parseBrazilianAmount('1.234,56'), 1234.56);
      expect(parseBrazilianAmount('12.345.678,90'), 12345678.90);
    });

    test('reads a dot with two digits as a decimal point', () {
      // Some card slips print this way.
      expect(parseBrazilianAmount('45.90'), 45.90);
    });

    test('reads a dot with three digits as a thousands separator', () {
      // The ambiguous case that matters: 1.234 is one thousand, not one and a
      // bit, and getting it backwards understates a purchase by a thousandfold.
      expect(parseBrazilianAmount('1.234'), 1234);
    });

    test('returns null on nonsense', () {
      expect(parseBrazilianAmount(''), isNull);
      expect(parseBrazilianAmount('abc'), isNull);
    });
  });

  group('amount', () {
    test('takes the labelled total', () {
      final scan = parseReceipt('''
PADARIA CENTRAL
SUBTOTAL 38,00
DESCONTO 3,10
TOTAL 34,90
''', now: today);

      expect(scan.amount, 34.90);
    });

    test('prefers the more specific label over a bare total', () {
      final scan = parseReceipt('''
MERCADO EXTRA
TOTAL 120,00
TOTAL A PAGAR 98,40
''', now: today);

      expect(scan.amount, 98.40);
    });

    test('prefers it even when the bare total comes last', () {
      final scan = parseReceipt('''
MERCADO EXTRA
TOTAL A PAGAR 98,40
TOTAL 120,00
''', now: today);

      expect(scan.amount, 98.40);
    });

    test('is not fooled by an item count', () {
      // "TOTAL DE ITENS 7" would otherwise prefill seven reais.
      final scan = parseReceipt('''
MERCADO EXTRA
TOTAL DE ITENS 7
TOTAL A PAGAR 214,90
''', now: today);

      expect(scan.amount, 214.90);
    });

    test('handles the currency symbol, however it was read', () {
      expect(parseReceipt('TOTAL R\$ 45,90', now: today).amount, 45.90);
      expect(parseReceipt('TOTAL RS 45,90', now: today).amount, 45.90);
      expect(parseReceipt('TOTAL: 45,90', now: today).amount, 45.90);
    });

    test('reads a total split from its label by spacing', () {
      final scan = parseReceipt('''
RESTAURANTE
VALOR TOTAL          1.284,50
''', now: today);

      expect(scan.amount, 1284.50);
    });

    test('returns null when nothing is labelled as a total', () {
      // Deliberately no fallback to the largest number: that would happily
      // return a CNPJ fragment, a barcode or a card number.
      final scan = parseReceipt('''
POSTO IPIRANGA
CNPJ 12.345.678/0001-90
GASOLINA 3,20 x 40
''', now: today);

      expect(scan.amount, isNull);
    });

    test('ignores a total of zero', () {
      expect(parseReceipt('TOTAL 0,00', now: today).amount, isNull);
    });
  });

  group('merchant', () {
    test('takes the name at the top', () {
      final scan = parseReceipt('''
SUPERMERCADO ANGELONI
CNPJ 12.345.678/0001-90
RUA DAS FLORES 100
TOTAL A PAGAR 214,90
''', now: today);

      expect(scan.merchant, 'SUPERMERCADO ANGELONI');
    });

    test('skips a tax id printed first', () {
      final scan = parseReceipt('''
CNPJ 12.345.678/0001-90
PADARIA CENTRAL
TOTAL 24,80
''', now: today);

      expect(scan.merchant, 'PADARIA CENTRAL');
    });

    test('skips the document header some receipts open with', () {
      final scan = parseReceipt('''
CUPOM FISCAL ELETRONICO
NFC-e
FARMACIA SAO JOAO
TOTAL 86,70
''', now: today);

      expect(scan.merchant, 'FARMACIA SAO JOAO');
    });

    test('skips an address line', () {
      final scan = parseReceipt('''
AV BRASIL 1200
LOJA DO SEU ZE
TOTAL 15,00
''', now: today);

      expect(scan.merchant, 'LOJA DO SEU ZE');
    });

    test('skips a line that is only digits', () {
      final scan = parseReceipt('''
00000123456
RESTAURANTE SAINT PETER
TOTAL 118,00
''', now: today);

      expect(scan.merchant, 'RESTAURANTE SAINT PETER');
    });

    test('does not read a product name from far down the page', () {
      // The name is at the top; below it come the tax id, the address and the
      // items. Scanning the whole page picks up a product.
      final scan = parseReceipt('''
12.345.678/0001-90
000123
987654
000111
000222
000333
ARROZ TIO JOAO 5KG
TOTAL 32,90
''', now: today);

      expect(scan.merchant, isNull);
    });

    test('trims punctuation and collapses spacing', () {
      final scan = parseReceipt('''
***   MERCADO   BOM  PRECO   ***
TOTAL 10,00
''', now: today);

      expect(scan.merchant, 'MERCADO BOM PRECO');
    });

    test('caps a runaway line', () {
      final scan = parseReceipt('${'A' * 200}\nTOTAL 10,00', now: today);

      expect(scan.merchant!.length, 60);
    });
  });

  group('date', () {
    test('reads a four-digit year', () {
      final scan = parseReceipt('''
PADARIA
15/08/2026 14:32
TOTAL 24,80
''', now: today);

      expect(scan.date, DateTime(2026, 8, 15));
    });

    test('reads a two-digit year', () {
      final scan = parseReceipt('PADARIA\n15/08/26\nTOTAL 24,80', now: today);

      expect(scan.date, DateTime(2026, 8, 15));
    });

    test('rejects a date in the future', () {
      // A receipt cannot be from next month; that is a misread.
      final scan = parseReceipt('PADARIA\n15/09/2026\nTOTAL 24,80', now: today);

      expect(scan.date, isNull);
    });

    test('rejects a day that does not exist', () {
      // DateTime(2026, 2, 31) silently becomes 3 March.
      final scan = parseReceipt('PADARIA\n31/02/2026\nTOTAL 24,80', now: today);

      expect(scan.date, isNull);
    });

    test('rejects an implausibly old date', () {
      final scan = parseReceipt('PADARIA\n15/08/2011\nTOTAL 24,80', now: today);

      expect(scan.date, isNull);
    });

    test('takes the first plausible date on the page', () {
      final scan = parseReceipt('''
PADARIA
EMISSAO 15/08/2026
VENCIMENTO 20/08/2026
TOTAL 24,80
''', now: today);

      expect(scan.date, DateTime(2026, 8, 15));
    });
  });

  group('the whole thing', () {
    test('reads a complete receipt', () {
      final scan = parseReceipt('''
SUPERMERCADO ANGELONI S/A
CNPJ 83.646.984/0001-00
RUA DAS FLORES, 100 - CENTRO
CUPOM FISCAL ELETRONICO - NFC-e
15/08/2026 19:42:11

ARROZ TIO JOAO 5KG      32,90
FEIJAO CARIOCA 1KG       9,80
LEITE INTEGRAL 1L        5,49

TOTAL DE ITENS 3
SUBTOTAL 48,19
DESCONTO 2,00
TOTAL A PAGAR 46,19
FORMA DE PAGAMENTO: CARTAO CREDITO
''', now: today);

      expect(scan.merchant, 'SUPERMERCADO ANGELONI S/A');
      expect(scan.amount, 46.19);
      expect(scan.date, DateTime(2026, 8, 15));
      expect(scan.hasAnything, isTrue);
    });

    test('says it found nothing rather than guessing', () {
      final scan = parseReceipt('....\n||||\n####', now: today);

      expect(scan.hasAnything, isFalse);
      expect(scan.amount, isNull);
      expect(scan.merchant, isNull);
      expect(scan.date, isNull);
    });

    test('keeps the raw text so the reading can be checked', () {
      const text = 'PADARIA\nTOTAL 24,80';
      expect(parseReceipt(text, now: today).rawText, text);
    });

    test('survives an empty recognition', () {
      final scan = parseReceipt('', now: today);
      expect(scan.hasAnything, isFalse);
    });
  });
}
