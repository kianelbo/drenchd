import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'widgets.dart';

const _emojiChoices = <String>[
  '☘️', '🍄', '🌀', '💠', '🌫️', '🍺', '🚬', '☕', '💊', '💉',
  '🌿', '🍁', '🧪', '⚗️', '🌵', '🍷', '🥃', '🧊', '❄️', '🔥',
  '🌙', '✨', '🎈', '🫧', '🌸', '🦋', '🐉', '🧿', '🍫', '🧠',
  '💤', '🕯️', '🌞', '🌈', '🪄', '🔮',
];

const _unitChoices = <String>[
  'g', 'mg', 'µg', 'ml', 'units', 'pills', 'tabs', 'caps',
  'hits', 'puffs', 'cig', 'drops', 'lines', 'shots', 'bowls',
];

const _colorChoices = <int>[
  0xFF5FA55A, 0xFFC85C5C, 0xFF8F6FD6, 0xFF3FA7D6, 0xFF7D8CA3,
  0xFFD9A441, 0xFF9C7A66, 0xFFA6785C, 0xFFE07A5F, 0xFF3D9970,
  0xFFB5559B, 0xFF4F6D7A,
];

/// Returns the id of the created/updated drug, or null if cancelled.
Future<int?> showDrugEditor(BuildContext context, {Drug? drug}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _DrugSheet(drug: drug),
  );
}

class _DrugSheet extends StatefulWidget {
  const _DrugSheet({this.drug});
  final Drug? drug;

  @override
  State<_DrugSheet> createState() => _DrugSheetState();
}

class _DrugSheetState extends State<_DrugSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.drug?.name ?? '');
  late final TextEditingController _unit =
      TextEditingController(text: widget.drug?.unitName ?? 'g');

  late String _emoji = widget.drug?.emoji ?? '☘️';
  late int _color = widget.drug?.colorValue ?? _colorChoices.first;
  String? _error;

  bool get _isNew => widget.drug?.id == null;

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name so you can find it later.');
      return;
    }
    final unit = _unit.text.trim().isEmpty ? 'g' : _unit.text.trim();
    final state = context.read<AppState>();
    final id = await state.saveDrug(
      (widget.drug ?? Drug(name: name, emoji: _emoji)).copyWith(
        name: name,
        emoji: _emoji,
        unitName: unit,
        colorValue: _color,
      ),
    );
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(_color);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                EmojiBadge(emoji: _emoji, color: color, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _isNew ? 'New substance' : 'Edit substance',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'Weed, Kratom, Melatonin…',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 20),
            Text('Symbol', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            _EmojiGrid(
              selected: _emoji,
              onSelected: (e) => setState(() => _emoji = e),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Or paste any emoji',
                isDense: true,
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(4)],
              onChanged: (v) {
                final t = v.trim();
                if (t.isNotEmpty) setState(() => _emoji = t);
              },
            ),
            const SizedBox(height: 16),
            Text('Unit shown next to quantities',
                style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _unit,
              inputFormatters: [LengthLimitingTextInputFormatter(12)],
              decoration: const InputDecoration(isDense: true),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final u in _unitChoices)
                  ChoiceChip(
                    label: Text(u),
                    selected: _unit.text.trim() == u,
                    onSelected: (_) => setState(() {
                      _unit.text = u;
                      _unit.selection =
                          TextSelection.collapsed(offset: u.length);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Colour on the calendar',
                style: theme.textTheme.labelMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in _colorChoices)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 26),
            FilledButton(
              onPressed: _save,
              child: Text(_isNew ? 'Add substance' : 'Save changes'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 96,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: _emojiChoices.length,
        itemBuilder: (context, i) {
          final emoji = _emojiChoices[i];
          final isSelected = emoji == selected;
          return GestureDetector(
            onTap: () => onSelected(emoji),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary.op(0.16)
                    : scheme.onSurface.op(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? scheme.primary : Colors.transparent,
                  width: 1.6,
                ),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          );
        },
      ),
    );
  }
}
