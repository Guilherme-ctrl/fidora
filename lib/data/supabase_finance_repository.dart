import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/invoice_import.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseFinanceRepository implements FinanceRepository {
  SupabaseFinanceRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<InvoiceImportPreview> previewInvoiceImport(
    InvoiceImportDocument document,
  ) async {
    final result = await _client.rpc(
      'preview_finora_invoice_import',
      params: {'p_payload': document.payload},
    );
    return InvoiceImportPreview.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<InvoiceImportResult> importInvoice(
    InvoiceImportDocument document,
  ) async {
    final result = await _client.rpc(
      'import_finora_invoice',
      params: {'p_payload': document.payload},
    );
    return InvoiceImportResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<FinanceSnapshot> loadSnapshot() async {
    final results = await Future.wait([
      _client
          .from('transactions')
          .select('*, categories(name), cards(last_four)')
          .order('purchased_at', ascending: false)
          .limit(2000),
      _client
          .from('categories')
          .select()
          .eq('active', true)
          .order('sort_order'),
      _client.from('cards').select().eq('active', true).order('name'),
      _client
          .from('invoices')
          .select()
          .order('reference_month', ascending: false)
          .limit(12),
      _client.from('goals').select().eq('active', true).order('created_at'),
      _client.from('review_queue').select('id').eq('status', 'pending'),
    ]);
    final palette = <Color>[
      coral,
      moss,
      const Color(0xFF5D65A8),
      const Color(0xFFBF5C7A),
      gold,
    ];
    final categories = (results[1] as List).indexed.map((entry) {
      final json = entry.$2 as Map<String, dynamic>;
      return FinanceCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: Icons.category_rounded,
        color: palette[entry.$1 % palette.length],
        monthlyBudget: (json['monthly_budget'] as num?)?.toDouble(),
      );
    }).toList();
    return FinanceSnapshot(
      transactions: (results[0] as List)
          .map(
            (json) => FinanceTransaction.fromJson(json as Map<String, dynamic>),
          )
          .toList(),
      categories: categories,
      cards: (results[2] as List)
          .map((json) => CreditCard.fromJson(json as Map<String, dynamic>))
          .toList(),
      invoices: (results[3] as List)
          .map((json) => Invoice.fromJson(json as Map<String, dynamic>))
          .toList(),
      goals: (results[4] as List)
          .map(
            (json) => Goal(
              name: json['name'] as String,
              current: (json['current_amount'] as num).toDouble(),
              target: (json['target_amount'] as num).toDouble(),
            ),
          )
          .toList(),
      pendingReviews: (results[5] as List).length,
    );
  }
}
