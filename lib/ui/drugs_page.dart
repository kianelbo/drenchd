import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'drug_editor.dart';
import 'widgets.dart';

class DrugsPage extends StatelessWidget {
  const DrugsPage({super.key});

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Substances', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Drag to reorder. The order sets the quick-log row.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => showDrugEditor(context),
                icon: const Icon(Icons.add),
                tooltip: 'Add substance',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: state.drugs.isEmpty
              ? EmptyState(
                  title: 'No substances yet',
                  message: 'Add the things you want to keep track of.',
                  action: FilledButton(
                    onPressed: () => showDrugEditor(context),
                    child: const Text('Add a substance'),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: state.drugs.length,
                  onReorder: context.read<AppState>().reorderDrugs,
                  proxyDecorator: (child, index, animation) => Material(
                    color: Colors.transparent,
                    child: child,
                  ),
                  itemBuilder: (context, i) {
                    final drug = state.drugs[i];
                    return Padding(
                      key: ValueKey('drug-${drug.id}'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DrugRow(
                        drug: drug,
                        index: i,
                        uses: state.usage[drug.id] ?? 0,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DrugRow extends StatelessWidget {
  const _DrugRow({required this.drug, required this.index, required this.uses});

  final Drug drug;
  final int index;
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
          onTap: () => showDrugEditor(context, drug: drug),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                EmojiBadge(emoji: drug.emoji, color: drug.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(drug.name,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        uses == 0
                            ? 'measured in ${drug.unitName}'
                            : '$uses ${uses == 1 ? 'entry' : 'entries'} · '
                                'measured in ${drug.unitName}',
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
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.drag_handle,
                        color: theme.colorScheme.onSurface.op(0.35)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await confirm(
      context,
      title: 'Delete ${drug.name}?',
      message: uses == 0
          ? 'This substance has no entries.'
          : 'Its $uses ${uses == 1 ? 'entry' : 'entries'} will be deleted too. '
              'This cannot be undone.',
    );
    if (!ok) return;
    await state.deleteDrug(drug.id!);
  }
}
