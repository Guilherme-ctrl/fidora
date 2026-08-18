import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/invoice_import.dart';
import 'package:flutter/material.dart';

class DemoFinanceRepository implements FinanceRepository {
  @override
  Future<InvoiceImportPreview> previewInvoiceImport(
    InvoiceImportDocument document,
  ) async => InvoiceImportPreview(
    rows: document.transactions.length,
    toCreate: document.transactions.length - document.paymentCount,
    toReconcile: 0,
    duplicates: 0,
    reviews: document.reviewCount,
    paymentsIgnored: document.paymentCount,
    missingCategories: const [],
    alreadyImported: false,
    items: document.transactions
        .map(
          (item) => InvoiceImportItemPreview(
            externalId: item['external_id'] as String,
            disposition: item['movement_type'] == 'transfer'
                ? 'payment'
                : 'new',
          ),
        )
        .toList(),
  );

  @override
  Future<InvoiceImportResult> importInvoice(
    InvoiceImportDocument document,
  ) => throw const InvoiceImportException(
    'A importação somente grava dados quando o Finora está conectado ao Supabase.',
  );

  @override
  Future<FinanceSnapshot> loadSnapshot() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final now = DateTime.now();
    return FinanceSnapshot(
      transactions: [
        FinanceTransaction(
          id: '1',
          date: now,
          merchant: 'PADARIA CENTRAL',
          amount: 24.80,
          category: 'Alimentação',
          cardLastFour: '6902',
          source: 'apple_pay',
        ),
        FinanceTransaction(
          id: '2',
          date: now.subtract(const Duration(days: 1)),
          merchant: 'UBER',
          amount: 31.40,
          category: 'Transporte',
          cardLastFour: '6902',
          source: 'apple_pay',
        ),
        FinanceTransaction(
          id: '3',
          date: now.subtract(const Duration(days: 2)),
          merchant: 'UNIFIQUE TELECOM',
          amount: 197.50,
          category: 'Moradia',
          cardLastFour: '2780',
        ),
        FinanceTransaction(
          id: '4',
          date: now.subtract(const Duration(days: 3)),
          merchant: 'GOOGLE YOUTUBE',
          amount: 16.90,
          category: 'Assinaturas',
          cardLastFour: '2780',
        ),
        FinanceTransaction(
          id: '5',
          date: now.subtract(const Duration(days: 5)),
          merchant: 'MERCADO LIVRE',
          amount: 156.30,
          category: 'Compras',
          cardLastFour: '4567',
          installmentCurrent: 2,
          installmentTotal: 4,
        ),
        FinanceTransaction(
          id: '6',
          date: now.subtract(const Duration(days: 7)),
          merchant: 'RESTAURANTE SAINT PETER',
          amount: 118.00,
          category: 'Alimentação',
          cardLastFour: '6902',
        ),
        FinanceTransaction(
          id: '7',
          date: now.subtract(const Duration(days: 9)),
          merchant: 'AIRBNB',
          amount: 410.14,
          category: 'Viagem',
          cardLastFour: '2780',
          installmentCurrent: 3,
          installmentTotal: 6,
        ),
        FinanceTransaction(
          id: '8',
          date: now.subtract(const Duration(days: 10)),
          merchant: 'FARMÁCIA',
          amount: 86.70,
          category: 'Saúde',
          cardLastFour: '0590',
          status: TransactionStatus.pending,
        ),
      ],
      categories: const [
        FinanceCategory(
          id: '1',
          name: 'Alimentação',
          icon: Icons.restaurant_rounded,
          color: coral,
          monthlyBudget: 1200,
        ),
        FinanceCategory(
          id: '2',
          name: 'Transporte',
          icon: Icons.directions_car_rounded,
          color: Color(0xFF377D71),
          monthlyBudget: 600,
        ),
        FinanceCategory(
          id: '3',
          name: 'Moradia',
          icon: Icons.home_rounded,
          color: Color(0xFF5D65A8),
          monthlyBudget: 2200,
        ),
        FinanceCategory(
          id: '4',
          name: 'Saúde',
          icon: Icons.favorite_rounded,
          color: Color(0xFFBF5C7A),
          monthlyBudget: 500,
        ),
        FinanceCategory(
          id: '5',
          name: 'Educação',
          icon: Icons.school_rounded,
          color: Color(0xFF7D63A8),
        ),
        FinanceCategory(
          id: '6',
          name: 'Lazer',
          icon: Icons.sports_soccer_rounded,
          color: gold,
          monthlyBudget: 700,
        ),
        FinanceCategory(
          id: '7',
          name: 'Viagem',
          icon: Icons.flight_rounded,
          color: Color(0xFF477D9B),
        ),
        FinanceCategory(
          id: '8',
          name: 'Compras',
          icon: Icons.shopping_bag_rounded,
          color: Color(0xFF98734E),
          monthlyBudget: 900,
        ),
        FinanceCategory(
          id: '9',
          name: 'Assinaturas',
          icon: Icons.subscriptions_rounded,
          color: Color(0xFF6B7B58),
          monthlyBudget: 250,
        ),
        FinanceCategory(
          id: '10',
          name: 'Financeiro',
          icon: Icons.account_balance_rounded,
          color: Color(0xFF4B6473),
        ),
        FinanceCategory(
          id: '11',
          name: 'Transferências',
          icon: Icons.swap_horiz_rounded,
          color: Color(0xFF718096),
        ),
        FinanceCategory(
          id: '12',
          name: 'Outros',
          icon: Icons.more_horiz_rounded,
          color: Color(0xFF8A8178),
        ),
      ],
      cards: const [
        CreditCard(
          id: '1',
          name: 'Uniclass Black',
          bank: 'Itaú',
          lastFour: '6902',
          limit: 41470,
          closingDay: 2,
          dueDay: 9,
          holder: 'Guilherme',
        ),
        CreditCard(
          id: '2',
          name: 'Ourocard Platinum',
          bank: 'Banco do Brasil',
          lastFour: '4567',
          limit: 39418,
          closingDay: 30,
          dueDay: 10,
          holder: 'Guilherme',
        ),
      ],
      invoices: [
        Invoice(
          id: '1',
          cardId: '1',
          referenceMonth: DateTime(now.year, now.month + 1),
          total: 2840.72,
          dueDate: DateTime(now.year, now.month + 1, 9),
          status: 'open',
        ),
        Invoice(
          id: '2',
          cardId: '2',
          referenceMonth: DateTime(now.year, now.month),
          total: 1296.35,
          dueDate: DateTime(now.year, now.month, 10),
          status: 'closed',
        ),
      ],
      goals: const [
        Goal(name: 'Reserva de emergência', current: 18500, target: 30000),
        Goal(name: 'Viagem', current: 4200, target: 12000),
      ],
      pendingReviews: 3,
    );
  }
}
