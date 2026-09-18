import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';

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
  late final TextEditingController _emoji =
      TextEditingController(text: widget.drug?.emoji ?? '💊');
  late final TextEditingController _unit =
      TextEditingController(text: widget.drug?.unitName ?? 'g');

  late int _color = widget.drug?.colorValue ?? _colorChoices.first;
  String? _rowError;

  bool get _isNew => widget.drug?.id == null;
  bool get _isNameEmpty => _name.text.trim().isEmpty;
  bool get _isEmojiEmpty => _emoji.text.trim().isEmpty;
  bool get _canSubmit => !_isNameEmpty && !_isEmojiEmpty;

  String? get _currentRowError {
    if (_isNameEmpty && _isEmojiEmpty) return 'Give it a name and an icon.';
    if (_isNameEmpty) return 'Give it a name.';
    if (_isEmojiEmpty) return 'Add an icon.';
    return null;
  }

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final emoji = _emoji.text.trim();

    if (!_canSubmit) {
      setState(() => _rowError = _currentRowError);
      return;
    }

    setState(() => _rowError = null);

    final unit = _unit.text.trim().isEmpty ? 'g' : _unit.text.trim();
    final state = context.read<AppState>();
    final id = await state.saveDrug(
      (widget.drug ?? Drug(name: name, emoji: emoji)).copyWith(
        name: name,
        emoji: emoji,
        unitName: unit,
        colorValue: _color,
      ),
    );
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'Weed, Kratom, Melatonin…',
                      errorText: _isNameEmpty ? ' ' : null,
                    ),
                    onChanged: (_) => setState(() {
                      _rowError = _currentRowError;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _emoji,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    decoration: InputDecoration(
                      labelText: 'Icon',
                      isDense: true,
                      counterText: '',
                      errorText: _isEmojiEmpty ? ' ' : null,
                    ),
                    onChanged: (_) => setState(() {
                      _rowError = _currentRowError;
                    }),
                  ),
                ),
              ],
            ),
            if (_rowError != null) ...[
              const SizedBox(height: 8),
              Text(
                _rowError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
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
              onPressed: _canSubmit ? _save : null,
              child: Text(_isNew ? 'Add substance' : 'Save changes'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
