import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'substance_editor.dart';
import 'widgets.dart';

class SubstancesPage extends StatelessWidget {
  const SubstancesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text('Substances', style: theme.textTheme.headlineSmall),
              ),
              IconButton.filledTonal(
                onPressed: () => showSubstanceEditor(context),
                icon: const Icon(Icons.add),
                tooltip: 'Add substance',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: state.substances.isEmpty
              ? EmptyState(
                  title: 'No substances yet',
                  message: 'Add the things you want to keep track of.',
                  action: FilledButton(
                    onPressed: () => showSubstanceEditor(context),
                    child: const Text('Add a substance'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: state.substances.length,
                  itemBuilder: (context, i) {
                    final substance = state.substances[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SubstanceRow(
                        substance: substance,
                        uses: state.usage[substance.id] ?? 0,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SubstanceRow extends StatelessWidget {
  const _SubstanceRow({required this.substance, required this.uses});

  final Substance substance;
  final int uses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Panel(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: () => showSubstanceEditor(context, substance: substance),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                EmojiBadge(emoji: substance.emoji, color: substance.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(substance.name,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        _buildDescription(substance, uses),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildDescription(Substance substance, int uses) {
    final buffer = StringBuffer();
    if (uses > 0) {
      buffer.write('$uses ${uses == 1 ? 'entry' : 'entries'} · ');
    }
    buffer.write('measured in ${substance.unitName}');
    if (substance.habitual) {
      buffer.write(' · habitual');
    }
    return buffer.toString();
  }

  Future<void> _delete(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await confirm(
      context,
      title: 'Delete ${substance.name}?',
      message: uses == 0
          ? 'This substance has no entries.'
          : 'Its $uses ${uses == 1 ? 'entry' : 'entries'} will be deleted too. '
              'This cannot be undone.',
    );
    if (!ok) return;
    await state.deleteSubstance(substance.id!);
  }
}
