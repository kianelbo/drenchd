import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/formatters.dart';
import 'drug_editor.dart';
import 'widgets.dart';

/// Opens the log sheet. Pass [intake] to edit, or [day] to pre-fill the date.
Future<void> showIntakeEditor(
  BuildContext context, {
  Intake? intake,
  DateTime? day,
  int? presetDrugId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        _IntakeSheet(intake: intake, day: day, presetDrugId: presetDrugId),
  );
}

class _IntakeSheet extends StatefulWidget {
  const _IntakeSheet({this.intake, this.day, this.presetDrugId});

  final Intake? intake;
  final DateTime? day;
  final int? presetDrugId;

  @override
  State<_IntakeSheet> createState() => _IntakeSheetState();
}

class _IntakeSheetState extends State<_IntakeSheet> {
  late DateTime _timestamp;
  int? _drugId;
  bool _missingDrug = false;

  final _quantity = TextEditingController();
  final _cost = TextEditingController();
  final _comments = TextEditingController();

  bool get _isNew => widget.intake == null;

  @override
  void initState() {
    super.initState();
    final existing = widget.intake;
    if (existing != null) {
      _timestamp = !isFutureDay(existing.timestamp)
          ? existing.timestamp
          : DateTime(
              dateOnly(DateTime.now()).year,
              dateOnly(DateTime.now()).month,
              dateOnly(DateTime.now()).day,
              existing.timestamp.hour,
              existing.timestamp.minute,
            );
      _drugId = existing.drugId;
      if (existing.quantity != null) {
        _quantity.text = existing.quantity!.toString();
      }
      if (existing.cost != null) _cost.text = _fmtCost(existing.cost!);
      _comments.text = existing.comments ?? '';
    } else {
      final now = DateTime.now();
      final base = widget.day ?? now;
      _timestamp =
          DateTime(base.year, base.month, base.day, now.hour, now.minute);
      _drugId = widget.presetDrugId;
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _cost.dispose();
    _comments.dispose();
    super.dispose();
  }

  /// Drops trailing zeros: 1.50 -> "1.5", 3.0 -> "3", 0.125 -> "0.125".
  String _fmtCost(double value) {
    var s = value.toStringAsFixed(3);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    }
    return s;
  }

  int? _parseQuantity(TextEditingController c) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    final v = int.tryParse(raw);
    return (v == null || v < 0) ? null : v;
  }

  double? _parseCost(TextEditingController c) {
    final raw = c.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final v = double.tryParse(raw);
    return (v == null || v < 0) ? null : v;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: !isFutureDay(_timestamp)
          ? _timestamp
          : dateOnly(DateTime.now()),
      firstDate: DateTime(2015),
      lastDate: dateOnly(DateTime.now()),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null) return;
    setState(() {
      _timestamp = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _timestamp.hour,
        _timestamp.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (picked == null) return;
    setState(() {
      _timestamp = DateTime(
        _timestamp.year,
        _timestamp.month,
        _timestamp.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_drugId == null) {
      setState(() => _missingDrug = true);
      return;
    }
    final entry = Intake(
      id: widget.intake?.id,
      drugId: _drugId!,
      timestamp: _timestamp,
      quantity: _parseQuantity(_quantity),
      cost: _parseCost(_cost),
      comments: _comments.text,
    );
    await context.read<AppState>().saveIntake(entry);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final id = widget.intake?.id;
    if (id == null) return;
    final ok = await confirm(
      context,
      title: 'Delete this entry?',
      message: 'It will be removed from the calendar and your totals.',
    );
    if (!ok || !mounted) return;
    await context.read<AppState>().deleteIntake(id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final drugs = state.drugs;
    final selected = state.drugById(_drugId);
    final unit = selected?.unitName ?? 'g';

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
                Expanded(
                  child: Text(
                    _isNew ? 'Log an entry' : 'Edit entry',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (!_isNew)
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    color: theme.colorScheme.error,
                    tooltip: 'Delete entry',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (drugs.isEmpty)
              Panel(
                color: theme.colorScheme.onSurface.op(0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No substances yet',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add one to start logging.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        final id = await showDrugEditor(context);
                        if (id != null && mounted) {
                          setState(() => _drugId = id);
                        }
                      },
                      child: const Text('Add a substance'),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in drugs)
                    ChoiceChip(
                      selected: d.id == _drugId,
                      onSelected: (_) => setState(() {
                        _drugId = d.id;
                        _missingDrug = false;
                      }),
                      selectedColor: d.color.op(0.2),
                      avatar: Text(
                        d.emoji,
                        style: const TextStyle(fontSize: 15),
                      ),
                      label: Text(d.name),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 17),
                    label: const Text('New'),
                    onPressed: () async {
                      final id = await showDrugEditor(context);
                      if (id != null && mounted) {
                        setState(() => _drugId = id);
                      }
                    },
                  ),
                ],
              ),
            if (_missingDrug) ...[
              const SizedBox(height: 8),
              Text(
                'Pick a substance first.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _FieldButton(
                    icon: Icons.event_outlined,
                    label: dfDayMedium.format(_timestamp),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 118,
                  child: _FieldButton(
                    icon: Icons.schedule,
                    label: dfTime.format(_timestamp),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      hintText: 'optional',
                      suffixText: unit,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cost',
                      hintText: 'optional',
                      suffixText: kCurrency,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comments,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Context, setting, how it went…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed:
                  (drugs.isEmpty && _drugId == null) || isFutureDay(_timestamp)
                  ? null
                  : _save,
              child: Text(_isNew ? 'Save entry' : 'Save changes'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.onSurface.op(0.05);
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurface.op(0.6)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
