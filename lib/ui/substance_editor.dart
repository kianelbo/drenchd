import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../util/color.dart';

/// Returns the id of the created/updated substance, or null if cancelled.
Future<int?> showSubstanceEditor(BuildContext context, {Substance? substance}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _SubstanceSheet(substance: substance),
  );
}

class _SubstanceSheet extends StatefulWidget {
  const _SubstanceSheet({this.substance});
  final Substance? substance;

  @override
  State<_SubstanceSheet> createState() => _SubstanceSheetState();
}

class _SubstanceSheetState extends State<_SubstanceSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.substance?.name ?? '');
  late final TextEditingController _emoji =
      TextEditingController(text: widget.substance?.emoji ?? '💊');
  late final TextEditingController _unit =
      TextEditingController(text: widget.substance?.unitName ?? 'g');
  bool _habitual = false;

  String? _rowError;

  bool get _isNew => widget.substance?.id == null;
  bool get _isNameEmpty => _name.text.trim().isEmpty;
  bool get _isEmojiEmpty => _emoji.text.trim().isEmpty;
  bool get _isUnitEmpty => _unit.text.trim().isEmpty;

  bool _isDuplicateName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;

    final currentId = widget.substance?.id;
    return context.read<AppState>().substances.any(
      (substance) =>
          substance.id != currentId &&
          substance.name.trim().toLowerCase() == trimmed.toLowerCase(),
    );
  }

  bool get _hasNameConflict => _isDuplicateName(_name.text);
  bool get _canSubmit => !_isNameEmpty && !_isEmojiEmpty && !_isUnitEmpty && !_hasNameConflict;

  String? get _currentRowError {
    if (_isNameEmpty && _isEmojiEmpty && _isUnitEmpty) {
      return 'Give it a name, an icon, and a unit.';
    }
    if (_isNameEmpty && _isEmojiEmpty) return 'Give it a name and an icon.';
    if (_isNameEmpty && _isUnitEmpty) return 'Give it a name and a unit.';
    if (_isEmojiEmpty && _isUnitEmpty) return 'Add an icon and a unit.';
    if (_isNameEmpty) return 'Give it a name.';
    if (_isEmojiEmpty) return 'Add an icon.';
    if (_isUnitEmpty) return 'Add a unit.';
    if (_hasNameConflict) return 'A substance with this name already exists.';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _habitual = widget.substance?.habitual ?? false;
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
    final unit = _unit.text.trim();

    if (!_canSubmit) {
      setState(() => _rowError = _currentRowError);
      return;
    }

    setState(() => _rowError = null);

    final state = context.read<AppState>();
    final color = await emojiColorFor(emoji);
    final id = await state.saveSubstance(
      (widget.substance ?? Substance(name: name, emoji: emoji)).copyWith(
        name: name,
        emoji: emoji,
        unitName: unit,
        colorValue: color,
        habitual: _habitual,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _unit,
                    inputFormatters: [LengthLimitingTextInputFormatter(12)],
                    decoration: InputDecoration(
                      labelText: 'Unit',
                      hintText: 'g, ml, tab(s)…',
                      isDense: true,
                      errorText: _isUnitEmpty ? ' ' : null,
                    ),
                    onChanged: (_) => setState(() {
                      _rowError = _currentRowError;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _habitual,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (value) {
                          setState(() => _habitual = value ?? false);
                        },
                      ),
                      const Text('habitual'),
                    ],
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
