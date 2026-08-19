import 'package:financeiro_ai/domain/merchant_identity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Descriptions in the shapes Brazilian banks actually write them.
///
/// No real statement is in this repository and none should be — `AGENTS.md`
/// forbids a fixture carrying personal financial data. These are synthetic
/// lines in the real formats, with documents that pass their own check digits
/// but belong to nobody.
void main() {
  group('Reading who was paid', () {
    test('a Pix carrying a CNPJ is resolvable', () {
      // The shape Nubank and Inter use when the payee is a company.
      const line =
          'Transferência enviada pelo Pix - PADARIA CENTRAL LTDA - '
          '34.028.316/0001-03 - BANCO X (0001)';
      final payee = readPayee(line);
      expect(payee.kind, PayeeKind.business);
      expect(payee.isPix, isTrue);
      expect(payee.cnpj, '34028316000103');
      expect(payee.canLookUpActivity, isTrue);
    });

    test('a bare fourteen-digit CNPJ is found too', () {
      final payee = readPayee('PIX ENVIADO MERCADO XYZ 34028316000103');
      expect(payee.cnpj, '34028316000103');
    });

    test('a Pix to a person is not resolvable, and says so', () {
      final payee = readPayee(
        'Transferência enviada pelo Pix - JOAO DA SILVA - 111.444.777-35',
      );
      expect(payee.kind, PayeeKind.person);
      expect(payee.canLookUpActivity, isFalse);
    });

    test('a masked document still tells us it was a person', () {
      // Nubank hides most of it. That is enough to stop guessing.
      final payee = readPayee(
        'Transferência enviada pelo Pix - MARIA SOUZA - •••.444.777-••',
      );
      expect(payee.kind, PayeeKind.maskedPerson);
    });

    test('a Pix with only a name is the hard case', () {
      final payee = readPayee('PIX TRANSF JOSE 12/08');
      expect(payee.kind, PayeeKind.pixNameOnly);
      expect(payee.canLookUpActivity, isFalse);
    });

    test('a card purchase is not a Pix', () {
      final payee = readPayee('MERCADO EXTRA');
      expect(payee.kind, PayeeKind.other);
      expect(payee.isPix, isFalse);
    });
  });

  group('The check digits are the whole point', () {
    test('a transaction id is not mistaken for a company', () {
      // Fourteen digits appear in statements constantly — ids, references,
      // barcodes. Counting them as companies would make the coverage number a
      // lie, which is the one thing this spike cannot afford.
      final payee = readPayee('PIX ENVIADO REF 12345678901234');
      expect(payee.cnpj, isNull);
      expect(payee.kind, PayeeKind.pixNameOnly);
    });

    test('rejects repeated digits and wrong check digits', () {
      expect(isValidCnpj('00000000000000'), isFalse);
      expect(isValidCnpj('34028316000104'), isFalse);
      expect(isValidCnpj('34028316000103'), isTrue);
      expect(isValidCpf('11111111111'), isFalse);
      expect(isValidCpf('111.444.777-35'), isTrue);
    });
  });

  _normalisation();

  group('Coverage', () {
    test('reports what a lookup would actually reach', () {
      final coverage = PayeeCoverage();
      for (final line in [
        'Transferência enviada pelo Pix - LOJA A - 34.028.316/0001-03',
        'Transferência enviada pelo Pix - LOJA A - 34.028.316/0001-03',
        'Transferência enviada pelo Pix - JOAO - 111.444.777-35',
        'PIX TRANSF MARIA 12/08',
        'MERCADO EXTRA',
      ]) {
        coverage.add(line);
      }

      expect(coverage.total, 5);
      expect(coverage.pix, 4);
      expect(coverage.resolvable, 2);
      // Two lines, one company: the lookup happens once per merchant, which is
      // what makes it cheap.
      expect(coverage.distinctCnpj, hasLength(1));
      expect(coverage.shareOfAll, closeTo(0.4, 0.001));
      expect(coverage.shareOfPix, closeTo(0.5, 0.001));
    });

    test('an empty ledger reports nothing rather than dividing by zero', () {
      final coverage = PayeeCoverage();
      expect(coverage.shareOfAll, 0);
      expect(coverage.shareOfPix, 0);
    });
  });
}

/// The two mechanical reasons a merchant is not recognisable as itself.
void _normalisation() {
  group('Normalising a merchant name', () {
    test('the instalment written inside the name comes off', () {
      // This is the one that matters most: without it, ten instalments of one
      // purchase are ten different merchants.
      expect(normalizeMerchant('LOJA X 03/10'), 'LOJA X');
      expect(normalizeMerchant('LOJA X 04/10'), 'LOJA X');
      expect(normalizeMerchant('MAGAZINE LUIZA D03/12'), 'MAGAZINE LUIZA');
      expect(normalizeMerchant('CASA E CIA L01/06'), 'CASA E CIA');
      expect(
        normalizeMerchant('LOJA X 03/10'),
        normalizeMerchant('LOJA X 07/10'),
        reason: 'duas parcelas da mesma compra têm de virar o mesmo nome',
      );
    });

    test('the acquirer in front comes off, the shop stays', () {
      expect(normalizeMerchant('PAYPAL*SPOTIFY'), 'SPOTIFY');
      expect(normalizeMerchant('MP *SHOPEE'), 'SHOPEE');
      expect(normalizeMerchant('PAG    *PADARIA CENTRAL'), 'PADARIA CENTRAL');
      expect(normalizeMerchant('EBANX* STEAM GAMES'), 'STEAM GAMES');
    });

    test('both at once', () {
      expect(normalizeMerchant('PAYPAL*LOJA X 02/06'), 'LOJA X');
    });

    test('leaves a plain name alone', () {
      expect(normalizeMerchant('MERCADO EXTRA'), 'MERCADO EXTRA');
      expect(normalizeMerchant('  UBER  '), 'UBER');
    });

    test('never returns nothing', () {
      // A name that is only an aggregator prefix has no shop in it, so the
      // original is better than an empty string.
      expect(normalizeMerchant('PAYPAL*'), 'PAYPAL*');
      expect(normalizeMerchant('03/10'), '03/10');
    });
  });
}
