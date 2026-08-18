import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/invoice_import.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<InvoiceImportDocument?> showInvoiceReviewDialog(
  BuildContext context, {
  required InvoiceImportDocument document,
  required InvoiceImportPreview preview,
  required List<FinanceCategory> categories,
}) => showDialog<InvoiceImportDocument>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _InvoiceReviewDialog(
    document: document,
    preview: preview,
    categories: categories,
  ),
);

enum _ReviewFilter { all, unresolved, unvalidated, reconciled }

class _InvoiceReviewDialog extends StatefulWidget {
  const _InvoiceReviewDialog({
    required this.document,
    required this.preview,
    required this.categories,
  });

  final InvoiceImportDocument document;
  final InvoiceImportPreview preview;
  final List<FinanceCategory> categories;

  @override
  State<_InvoiceReviewDialog> createState() => _InvoiceReviewDialogState();
}

class _InvoiceReviewDialogState extends State<_InvoiceReviewDialog> {
  late final List<Map<String, dynamic>> transactions = widget
      .document
      .transactions
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  final validated = <String>{};
  final approvedNewCategories = <String>{};
  final searchController = TextEditingController();
  var filter = _ReviewFilter.all;
  var categoryPromptShown = false;

  Set<String> get categoryNames => {
    ...widget.categories.map((item) => item.name),
    ...approvedNewCategories,
  };
  Map<String, InvoiceImportItemPreview> get previewItems =>
      widget.preview.itemsByExternalId;

  List<String> get unmappedCategories {
    final values =
        transactions
            .where(_included)
            .map((item) => item['category'])
            .whereType<String>()
            .where((category) => !categoryNames.contains(category))
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (categoryPromptShown || unmappedCategories.isEmpty) return;
    categoryPromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showCategoryCreation();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool _included(Map<String, dynamic> item) =>
      item['movement_type'] != 'transfer' && item['include_in_totals'] != false;

  bool _resolved(Map<String, dynamic> item) {
    if (!_included(item)) return true;
    final category = item['category'];
    return item['needs_review'] != true &&
        category is String &&
        categoryNames.contains(category);
  }

  String _disposition(Map<String, dynamic> item) =>
      previewItems[item['external_id']]?.disposition ??
      (item['movement_type'] == 'transfer' ? 'payment' : 'new');

  List<Map<String, dynamic>> get visibleTransactions {
    final query = searchController.text.trim().toLowerCase();
    return transactions.where((item) {
      final disposition = _disposition(item);
      final matchesFilter = switch (filter) {
        _ReviewFilter.all => true,
        _ReviewFilter.unresolved => !_resolved(item),
        _ReviewFilter.unvalidated => !validated.contains(item['external_id']),
        _ReviewFilter.reconciled =>
          disposition == 'reconcile' || disposition == 'duplicate',
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return '${item['merchant_original']} ${item['category'] ?? ''} ${item['subcategory'] ?? ''}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  int get unresolvedCount =>
      transactions.where((item) => !_resolved(item)).length;
  int get remainingValidation => transactions.length - validated.length;

  void _validateSafeItems() {
    setState(() {
      validated.addAll(
        transactions
            .where(_resolved)
            .map((item) => item['external_id'] as String),
      );
    });
  }

  Future<void> _showCategoryCreation() async {
    final missing = unmappedCategories;
    if (missing.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryCreationDialog(missingCategories: missing),
    );
    if (confirmed != true || !mounted) return;
    setState(() => approvedNewCategories.addAll(missing));
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final index = transactions.indexOf(item);
    final edited = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TransactionEditDialog(
        transaction: item,
        categories: categoryNames.toList()..sort(),
      ),
    );
    if (edited == null) return;
    setState(() {
      transactions[index] = edited;
      final id = edited['external_id'] as String;
      if (_resolved(edited)) {
        validated.add(id);
      } else {
        validated.remove(id);
      }
    });
  }

  void _toggleValidation(Map<String, dynamic> item) {
    if (!_resolved(item)) {
      _editItem(item);
      return;
    }
    final id = item['external_id'] as String;
    setState(
      () => validated.contains(id) ? validated.remove(id) : validated.add(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 650;
    final visible = visibleTransactions;
    return Dialog(
      insetPadding: EdgeInsets.all(compact ? 8 : 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 940,
        height: compact ? size.height - 16 : size.height.clamp(620, 820),
        child: Column(
          children: [
            _Header(
              document: widget.document,
              onClose: () => Navigator.pop(context),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 24,
                12,
                compact ? 14 : 24,
                8,
              ),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SummaryChip(
                        label: '${transactions.length} itens',
                        icon: Icons.receipt_long_rounded,
                      ),
                      _SummaryChip(
                        label: '${widget.preview.toCreate} novos',
                        icon: Icons.add_circle_outline_rounded,
                      ),
                      _SummaryChip(
                        label: '${widget.preview.toReconcile} conciliados',
                        icon: Icons.sync_rounded,
                      ),
                      _SummaryChip(
                        label: '$unresolvedCount com pendência',
                        icon: unresolvedCount == 0
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        color: unresolvedCount == 0 ? moss : gold,
                      ),
                      _SummaryChip(
                        label: '$remainingValidation para validar',
                        icon: Icons.fact_check_outlined,
                      ),
                    ],
                  ),
                  if (unmappedCategories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Material(
                      color: gold.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.create_new_folder_outlined,
                          color: gold,
                        ),
                        title: Text(
                          '${unmappedCategories.length} ${unmappedCategories.length == 1 ? 'categoria ainda não cadastrada' : 'categorias ainda não cadastradas'}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(unmappedCategories.join(', ')),
                        trailing: Tooltip(
                          message:
                              'Confirmar a criação das categorias recebidas no JSON',
                          child: TextButton(
                            onPressed: _showCategoryCreation,
                            child: const Text('Criar'),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar estabelecimento ou categoria',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar busca',
                              onPressed: () => setState(searchController.clear),
                              icon: const Icon(Icons.close_rounded),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Todos',
                          selected: filter == _ReviewFilter.all,
                          onTap: () =>
                              setState(() => filter = _ReviewFilter.all),
                        ),
                        _FilterChip(
                          label: 'Pendências',
                          selected: filter == _ReviewFilter.unresolved,
                          onTap: () =>
                              setState(() => filter = _ReviewFilter.unresolved),
                        ),
                        _FilterChip(
                          label: 'Não validados',
                          selected: filter == _ReviewFilter.unvalidated,
                          onTap: () => setState(
                            () => filter = _ReviewFilter.unvalidated,
                          ),
                        ),
                        _FilterChip(
                          label: 'Conciliados',
                          selected: filter == _ReviewFilter.reconciled,
                          onTap: () =>
                              setState(() => filter = _ReviewFilter.reconciled),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('Nenhum lançamento neste filtro.'))
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 6 : 16,
                        vertical: 8,
                      ),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        return _TransactionReviewTile(
                          item: item,
                          disposition: _disposition(item),
                          resolved: _resolved(item),
                          validated: validated.contains(item['external_id']),
                          included: _included(item),
                          onValidate: () => _toggleValidation(item),
                          onEdit: () => _editItem(item),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 24,
                10,
                compact ? 12 : 24,
                12,
              ),
              child: Row(
                children: [
                  if (remainingValidation > 0 && !compact)
                    OutlinedButton.icon(
                      onPressed: _validateSafeItems,
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text('Validar itens sem alerta'),
                    )
                  else if (remainingValidation > 0)
                    Tooltip(
                      message: 'Validar todos os itens sem alerta',
                      child: IconButton.outlined(
                        onPressed: _validateSafeItems,
                        icon: const Icon(Icons.done_all_rounded),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: remainingValidation == 0
                        ? 'Confirmar os itens e continuar a importação'
                        : 'Valide os $remainingValidation itens restantes',
                    child: FilledButton.icon(
                      onPressed: remainingValidation == 0
                          ? () => Navigator.pop(
                              context,
                              widget.document
                                  .withTransactions(transactions)
                                  .withCreateMissingCategories(
                                    approvedNewCategories.isNotEmpty,
                                  ),
                            )
                          : null,
                      icon: const Icon(Icons.cloud_upload_rounded),
                      label: Text(
                        compact ? 'Continuar' : 'Confirmar importação',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCreationDialog extends StatelessWidget {
  const _CategoryCreationDialog({required this.missingCategories});

  final List<String> missingCategories;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      missingCategories.length == 1
          ? 'Criar nova categoria?'
          : 'Criar novas categorias?',
    ),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              missingCategories.length == 1
                  ? 'Esta categoria veio no JSON e ainda não existe no Finora. Deseja cadastrá-la?'
                  : 'Estas categorias vieram no JSON e ainda não existem no Finora. Deseja cadastrá-las?',
            ),
            const SizedBox(height: 18),
            Material(
              color: mint.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final category in missingCategories)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add_circle_outline_rounded,
                              color: moss,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Elas serão criadas junto com a importação. Se você cancelar a importação, nada será cadastrado.',
              style: TextStyle(color: ink.withValues(alpha: .64)),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Não criar'),
      ),
      Tooltip(
        message: 'Criar as categorias ao confirmar a importação',
        child: FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.add_rounded),
          label: Text(
            missingCategories.length == 1
                ? 'Criar categoria'
                : 'Criar categorias',
          ),
        ),
      ),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.document, required this.onClose});
  final InvoiceImportDocument document;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 18, 14, 18),
    color: mint.withValues(alpha: .55),
    child: Row(
      children: [
        const Icon(Icons.fact_check_rounded, color: moss),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Validar lançamentos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              Text(
                '${document.bank} • final ${document.cardLastFour} • ${currency.format(document.statementTotal)}',
                style: TextStyle(color: ink.withValues(alpha: .64)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cancelar importação',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.icon,
    this.color = moss,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 17, color: color),
    label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

class _TransactionReviewTile extends StatelessWidget {
  const _TransactionReviewTile({
    required this.item,
    required this.disposition,
    required this.resolved,
    required this.validated,
    required this.included,
    required this.onValidate,
    required this.onEdit,
  });

  final Map<String, dynamic> item;
  final String disposition;
  final bool resolved;
  final bool validated;
  final bool included;
  final VoidCallback onValidate;
  final VoidCallback onEdit;

  String get dispositionLabel => switch (disposition) {
    'reconcile' => 'Conciliar Atalho',
    'duplicate' => 'Já existente',
    'payment' => 'Pagamento',
    _ => 'Novo',
  };

  Color get dispositionColor => switch (disposition) {
    'reconcile' => const Color(0xFF5D65A8),
    'duplicate' => moss,
    'payment' => gold,
    _ => coral,
  };

  @override
  Widget build(BuildContext context) {
    final installment = item['installment'] as Map<String, dynamic>?;
    final details = <String>[
      DateFormat(
        'dd/MM/yyyy',
      ).format(DateTime.parse(item['purchased_at'] as String)),
      item['category'] as String? ?? 'Sem categoria',
      if (installment != null)
        '${installment['current']}/${installment['total']}',
      if (!included) 'Fora das finanças',
    ];
    return Material(
      color: validated
          ? mint.withValues(alpha: .35)
          : !resolved
          ? gold.withValues(alpha: .10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            children: [
              Tooltip(
                message: !resolved
                    ? 'Corrigir este lançamento antes de validar'
                    : validated
                    ? 'Marcar como não validado'
                    : 'Validar este lançamento',
                child: IconButton(
                  onPressed: onValidate,
                  icon: Icon(
                    validated
                        ? Icons.check_circle_rounded
                        : !resolved
                        ? Icons.error_outline_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: validated
                        ? moss
                        : !resolved
                        ? gold
                        : ink.withValues(alpha: .4),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['merchant_original'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details.join(' • '),
                      style: TextStyle(
                        fontSize: 12,
                        color: ink.withValues(alpha: .60),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currency.format(item['amount']),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    dispositionLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: dispositionColor,
                    ),
                  ),
                ],
              ),
              Tooltip(
                message: 'Editar categoria, tipo e inclusão',
                child: IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionEditDialog extends StatefulWidget {
  const _TransactionEditDialog({
    required this.transaction,
    required this.categories,
  });
  final Map<String, dynamic> transaction;
  final List<String> categories;

  @override
  State<_TransactionEditDialog> createState() => _TransactionEditDialogState();
}

class _TransactionEditDialogState extends State<_TransactionEditDialog> {
  late final Map<String, dynamic> edited = Map<String, dynamic>.from(
    widget.transaction,
  );
  late final TextEditingController subcategoryController =
      TextEditingController(text: edited['subcategory'] as String? ?? '');
  late String? category = widget.categories.contains(edited['category'])
      ? edited['category'] as String?
      : null;
  late String movement = edited['movement_type'] as String;
  late bool included =
      movement != 'transfer' && edited['include_in_totals'] != false;

  @override
  void dispose() {
    subcategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !included || category != null;
    return AlertDialog(
      title: const Text('Validar lançamento'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                edited['merchant_original'] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('dd/MM/yyyy').format(DateTime.parse(edited['purchased_at'] as String))} • ${currency.format(edited['amount'])}',
                style: TextStyle(color: ink.withValues(alpha: .62)),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                ),
                items: widget.categories
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: included
                    ? (value) => setState(() => category = value)
                    : null,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: subcategoryController,
                decoration: const InputDecoration(
                  labelText: 'Subcategoria',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: movement,
                decoration: const InputDecoration(
                  labelText: 'Tipo de movimento',
                  border: OutlineInputBorder(),
                ),
                items: invoiceImportMovements
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_movementLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    movement = value;
                    if (movement == 'transfer') included = false;
                  });
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Incluir nas minhas finanças',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Desative para cartões adicionais ou itens que não entram nas metas.',
                ),
                value: included,
                onChanged: movement == 'transfer'
                    ? null
                    : (value) => setState(() => included = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        Tooltip(
          message: canSave
              ? 'Salvar correções e validar este item'
              : 'Escolha uma categoria ou retire o item das suas finanças',
          child: FilledButton.icon(
            onPressed: canSave
                ? () {
                    edited
                      ..['category'] = category
                      ..['subcategory'] =
                          subcategoryController.text.trim().isEmpty
                          ? null
                          : subcategoryController.text.trim()
                      ..['movement_type'] = movement
                      ..['include_in_totals'] = included
                      ..['needs_review'] = false
                      ..['review_reason'] = null
                      ..['confidence'] = 1.0;
                    Navigator.pop(context, edited);
                  }
                : null,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Salvar e validar'),
          ),
        ),
      ],
    );
  }
}

String _movementLabel(String value) => switch (value) {
  'purchase' => 'Compra',
  'refund' => 'Estorno',
  'credit' => 'Crédito/desconto',
  'transfer' => 'Pagamento/transferência',
  'fee' => 'Tarifa',
  'interest' => 'Juros',
  'tax' => 'Imposto/IOF',
  'credit_pix' => 'Pix no crédito',
  _ => value,
};
