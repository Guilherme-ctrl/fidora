import 'package:financeiro_ai/core/design_system/common.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/catalog/presenter/widgets/goal_form_sheet.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:flutter/material.dart';

/// Goals, listed and editable.
///
/// It was 100 lines inside the settings page's `build`. Goals are catalogue —
/// `GoalDraft` lives here, `editGoal` lives here — and the only reason this
/// was in `settings` is that the menu is where it happens to be shown.
class GoalsSection extends StatelessWidget {
  const GoalsSection({required this.snapshot, super.key});

  final FinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) => RuledSection(
      title: 'Metas',
      tooltip: 'Criar uma meta',
      onTap: () => editGoal(context),
      trailing: IconButton(
        tooltip: 'Nova meta',
        onPressed: () => editGoal(context),
        icon: const Icon(Icons.add_rounded),
      ),
      child: Column(
        children: snapshot.goals
            .map(
      (goal) => Semantics(
        label: 'Ver detalhes da meta ${goal.name}',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => editGoal(context, existing: goal),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${(goal.progress * 100).round()}%',
                      style: TextStyle(
                        color: context.palette.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RuleBar(value: goal.progress),
                const SizedBox(height: 6),
                // A Spacer between two rigid amounts has no
                // give: at 1.3x text the pair overflowed by
                // 66px. spaceBetween plus Flexible lets the
                // values wrap instead.
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        currency.format(goal.current),
                        style: TextStyle(
                          color: context.palette.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        currency.format(goal.target),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: context.palette.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
            )
            .toList(),
      ),
    );
}
