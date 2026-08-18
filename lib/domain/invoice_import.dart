import 'dart:convert';

const invoiceImportMovements = {
  'purchase',
  'refund',
  'credit',
  'transfer',
  'fee',
  'interest',
  'tax',
  'credit_pix',
};

const invoiceImportModalities = {'cash', 'installment'};

class InvoiceImportDocument {
  InvoiceImportDocument._({required this.payload, required this.transactions});

  final Map<String, dynamic> payload;
  final List<Map<String, dynamic>> transactions;

  Map<String, dynamic> get invoice =>
      payload['invoice'] as Map<String, dynamic>;
  String get requestId => payload['request_id'] as String;
  String get bank => invoice['bank'] as String;
  String get cardLastFour => invoice['card_last_four'] as String;
  String get sourceFile => invoice['source_file'] as String;
  DateTime get referenceMonth =>
      DateTime.parse(invoice['reference_month'] as String);
  double get statementTotal => (invoice['statement_total'] as num).toDouble();
  int get reviewCount =>
      transactions.where((item) => item['needs_review'] == true).length;
  int get installmentCount =>
      transactions.where((item) => item['modality'] == 'installment').length;
  int get paymentCount =>
      transactions.where((item) => item['movement_type'] == 'transfer').length;
  bool get createMissingCategories =>
      (payload['processing']
          as Map<String, dynamic>?)?['create_missing_categories'] ==
      true;

  InvoiceImportDocument withTransactions(
    List<Map<String, dynamic>> updatedTransactions,
  ) {
    final updatedPayload = Map<String, dynamic>.from(payload)
      ..['invoice'] = Map<String, dynamic>.from(invoice)
      ..['processing'] = Map<String, dynamic>.from(
        payload['processing'] as Map<String, dynamic>? ?? const {},
      )
      ..['transactions'] = updatedTransactions
          .map(Map<String, dynamic>.from)
          .toList();
    return InvoiceImportDocument.fromJson(updatedPayload);
  }

  InvoiceImportDocument withCreateMissingCategories(bool value) {
    final updatedPayload = Map<String, dynamic>.from(payload)
      ..['invoice'] = Map<String, dynamic>.from(invoice)
      ..['processing'] = (Map<String, dynamic>.from(
        payload['processing'] as Map<String, dynamic>? ?? const {},
      )..['create_missing_categories'] = value)
      ..['transactions'] = transactions.map(Map<String, dynamic>.from).toList();
    return InvoiceImportDocument.fromJson(updatedPayload);
  }

  double get computedTotal => transactions.fold(0, (sum, item) {
    final amount = (item['amount'] as num).toDouble();
    return switch (item['movement_type']) {
      'refund' || 'credit' => sum - amount,
      'transfer' => sum,
      _ => sum + amount,
    };
  });

  static InvoiceImportDocument decode(String contents) {
    dynamic decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException catch (error) {
      throw InvoiceImportException('JSON inválido: ${error.message}.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const InvoiceImportException(
        'O arquivo deve conter um objeto JSON.',
      );
    }
    return fromJson(decoded);
  }

  static InvoiceImportDocument fromJson(Map<String, dynamic> payload) {
    final errors = <String>[];
    if (payload['schema_version'] != '1.0') {
      errors.add('schema_version deve ser "1.0"');
    }
    _requiredText(payload, 'request_id', errors);
    if (payload['source'] != 'chatgpt') {
      errors.add('source deve ser "chatgpt"');
    }
    final invoiceValue = payload['invoice'];
    final transactionValue = payload['transactions'];
    if (invoiceValue is! Map<String, dynamic>) {
      errors.add('invoice é obrigatório');
    }
    if (transactionValue is! List || transactionValue.isEmpty) {
      errors.add('transactions deve conter pelo menos um lançamento');
    }
    if (errors.isNotEmpty) throw InvoiceImportException(errors.join('; '));

    final invoice = invoiceValue as Map<String, dynamic>;
    for (final field in [
      'bank',
      'card_last_four',
      'reference_month',
      'due_date',
      'currency',
      'source_file',
    ]) {
      _requiredText(invoice, field, errors);
    }
    if (!RegExp(r'^\d{4}$').hasMatch('${invoice['card_last_four'] ?? ''}')) {
      errors.add('card_last_four deve conter quatro dígitos');
    }
    final referenceMonth = _date(
      invoice['reference_month'],
      'reference_month',
      errors,
    );
    if (referenceMonth != null && referenceMonth.day != 1) {
      errors.add('reference_month deve usar o primeiro dia do mês');
    }
    _date(invoice['due_date'], 'due_date', errors);
    if (invoice['closing_date'] != null) {
      _date(invoice['closing_date'], 'closing_date', errors);
    }
    final statementTotal = invoice['statement_total'];
    if (statementTotal is! num || statementTotal < 0) {
      errors.add('statement_total deve ser um número não negativo');
    }

    final transactions = <Map<String, dynamic>>[];
    final externalIds = <String>{};
    for (final (index, value) in (transactionValue as List).indexed) {
      if (value is! Map<String, dynamic>) {
        errors.add('transactions[$index] deve ser um objeto');
        continue;
      }
      transactions.add(value);
      final prefix = 'transactions[$index]';
      for (final field in [
        'external_id',
        'purchased_at',
        'merchant_original',
        'merchant_normalized',
        'movement_type',
        'modality',
      ]) {
        _requiredText(value, field, errors, prefix: prefix);
      }
      final externalId = value['external_id'];
      if (externalId is String && !externalIds.add(externalId)) {
        errors.add('$prefix.external_id está duplicado');
      }
      _date(value['purchased_at'], '$prefix.purchased_at', errors);
      final amount = value['amount'];
      if (amount is! num || amount <= 0) {
        errors.add('$prefix.amount deve ser maior que zero');
      }
      if (!invoiceImportMovements.contains(value['movement_type'])) {
        errors.add('$prefix.movement_type não é suportado');
      }
      if (!invoiceImportModalities.contains(value['modality'])) {
        errors.add('$prefix.modality não é suportada');
      }
      final confidence = value['confidence'];
      if (confidence is! num || confidence < 0 || confidence > 1) {
        errors.add('$prefix.confidence deve estar entre 0 e 1');
      }
      if (value['needs_review'] is! bool) {
        errors.add('$prefix.needs_review deve ser booleano');
      }
      if (value['modality'] == 'installment') {
        final installment = value['installment'];
        if (installment is! Map<String, dynamic>) {
          errors.add('$prefix.installment é obrigatório para compra parcelada');
        } else {
          final current = installment['current'];
          final total = installment['total'];
          if (current is! int ||
              total is! int ||
              current < 1 ||
              total < current) {
            errors.add(
              '$prefix.installment deve ter parcela atual e total válidos',
            );
          }
        }
      }
    }
    if (errors.isNotEmpty) throw InvoiceImportException(errors.join('; '));

    final document = InvoiceImportDocument._(
      payload: payload,
      transactions: transactions,
    );
    if ((document.computedTotal - document.statementTotal).abs() > 0.01) {
      throw InvoiceImportException(
        'A soma dos lançamentos (${document.computedTotal.toStringAsFixed(2)}) '
        'não confere com a fatura (${document.statementTotal.toStringAsFixed(2)}).',
      );
    }
    return document;
  }

  static void _requiredText(
    Map<String, dynamic> json,
    String field,
    List<String> errors, {
    String? prefix,
  }) {
    final value = json[field];
    if (value is! String || value.trim().isEmpty) {
      errors.add('${prefix == null ? '' : '$prefix.'}$field é obrigatório');
    }
  }

  static DateTime? _date(dynamic value, String field, List<String> errors) {
    if (value is! String || DateTime.tryParse(value) == null) {
      errors.add('$field deve ser uma data ISO 8601 válida');
      return null;
    }
    return DateTime.parse(value);
  }
}

class InvoiceImportPreview {
  const InvoiceImportPreview({
    required this.rows,
    required this.toCreate,
    required this.toReconcile,
    required this.duplicates,
    required this.reviews,
    required this.paymentsIgnored,
    required this.missingCategories,
    required this.alreadyImported,
    required this.items,
  });

  final int rows;
  final int toCreate;
  final int toReconcile;
  final int duplicates;
  final int reviews;
  final int paymentsIgnored;
  final List<String> missingCategories;
  final bool alreadyImported;
  final List<InvoiceImportItemPreview> items;
  Map<String, InvoiceImportItemPreview> get itemsByExternalId => {
    for (final item in items) item.externalId: item,
  };
  bool get canImport => missingCategories.isEmpty && !alreadyImported;

  factory InvoiceImportPreview.fromJson(Map<String, dynamic> json) =>
      InvoiceImportPreview(
        rows: json['rows'] as int,
        toCreate: json['to_create'] as int,
        toReconcile: json['to_reconcile'] as int,
        duplicates: json['duplicates'] as int,
        reviews: json['reviews'] as int,
        paymentsIgnored: json['payments_ignored'] as int,
        missingCategories: List<String>.from(
          json['missing_categories'] as List? ?? const [],
        ),
        alreadyImported: json['already_imported'] as bool? ?? false,
        items: (json['items'] as List? ?? const [])
            .map(
              (item) => InvoiceImportItemPreview.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );
}

class InvoiceImportItemPreview {
  const InvoiceImportItemPreview({
    required this.externalId,
    required this.disposition,
  });

  final String externalId;
  final String disposition;

  factory InvoiceImportItemPreview.fromJson(Map<String, dynamic> json) =>
      InvoiceImportItemPreview(
        externalId: json['external_id'] as String,
        disposition: json['disposition'] as String,
      );
}

class InvoiceImportResult {
  const InvoiceImportResult({
    required this.created,
    required this.reconciled,
    required this.reviews,
    required this.duplicateBatch,
  });
  final int created;
  final int reconciled;
  final int reviews;
  final bool duplicateBatch;

  factory InvoiceImportResult.fromJson(Map<String, dynamic> json) =>
      InvoiceImportResult(
        created: json['created'] as int? ?? 0,
        reconciled: json['reconciled'] as int? ?? 0,
        reviews: json['reviews'] as int? ?? 0,
        duplicateBatch: json['duplicate_batch'] as bool? ?? false,
      );
}

class InvoiceImportException implements Exception {
  const InvoiceImportException(this.message);
  final String message;
  @override
  String toString() => message;
}
