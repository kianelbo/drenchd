import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/formatters.dart';
import 'intake_editor.dart';
import 'widgets.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: _MonthHeader()),
        const SliverToBoxAdapter(child: _CalendarGrid()),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        const SliverToBoxAdapter(child: _DayHeader()),
        if (state.dayGroups.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              title: 'Nothing logged',
              message: 'Such a clean day!',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: state.dayGroups.length,
              itemBuilder: (context, i) {
                final group = state.dayGroups[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DayGroupTile(
                    key: ValueKey('group-${group.substance.id}'),
                    group: group,
                  ),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final isThisMonth = state.focusedDay.year == DateTime.now().year &&
        state.focusedDay.month == DateTime.now().month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dfMonthYear.format(state.focusedDay),
              style: theme.textTheme.headlineSmall,
            ),
          ),
          if (!isThisMonth)
            TextButton(
              onPressed: () => context.read<AppState>().jumpToToday(),
              child: const Text('Today'),
            ),
          IconButton(
            onPressed: () => context.read<AppState>().shiftMonth(-1),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
          ),
          IconButton(
            onPressed: () => context.read<AppState>().shiftMonth(1),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
          ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
        child: TableCalendar<Object>(
          firstDay: DateTime.utc(2015, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),
          focusedDay: state.focusedDay,
          currentDay: DateTime.now(),
          headerVisible: false,
          rowHeight: 58,
          daysOfWeekHeight: 26,
          startingDayOfWeek: StartingDayOfWeek.monday,
          availableGestures: AvailableGestures.horizontalSwipe,
          selectedDayPredicate: (d) => isSameDay(d, state.selectedDay),
          onDaySelected: (selected, focused) =>
              context.read<AppState>().selectDay(selected, focused),
          onPageChanged: (focused) =>
              context.read<AppState>().setFocusedDay(focused),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: theme.textTheme.labelMedium!,
            weekendStyle: theme.textTheme.labelMedium!,
          ),
          calendarBuilders: CalendarBuilders<Object>(
            defaultBuilder: (context, day, _) => _DayCell(day: day),
            todayBuilder: (context, day, _) =>
                _DayCell(day: day, isToday: true),
            selectedBuilder: (context, day, _) =>
                _DayCell(day: day, isSelected: true),
            outsideBuilder: (context, day, _) =>
                _DayCell(day: day, isOutside: true),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    this.isToday = false,
    this.isSelected = false,
    this.isOutside = false,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final marker = context.select<AppState, DayMarker?>(
      (s) => s.markerFor(day),
    );

    final Color fill;
    if (isSelected) {
      fill = scheme.primary;
    } else if (marker != null) {
      fill = marker.topSubstance.color.op(isOutside ? 0.07 : 0.18);
    } else {
      fill = Colors.transparent;
    }

    final Color numberColor;
    if (isSelected) {
      numberColor = scheme.onPrimary;
    } else if (isOutside) {
      numberColor = scheme.onSurface.op(0.28);
    } else if (isToday) {
      numberColor = scheme.primary;
    } else {
      numberColor = scheme.onSurface.op(marker != null ? 0.85 : 0.6);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(13),
        border: isToday && !isSelected
            ? Border.all(color: scheme.primary.op(0.55), width: 1.4)
            : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: marker == null ? 14 : 11.5,
                    height: 1.1,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: numberColor,
                  ),
                ),
                if (marker != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      marker.topSubstance.emoji,
                      style: TextStyle(fontSize: 16, color: isOutside
                          ? scheme.onSurface.op(0.3)
                          : null),
                    ),
                  ),
              ],
            ),
          ),
          if (marker != null && marker.totalCount > 1 && !isOutside)
            Positioned(
              right: 3,
              top: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.onPrimary.op(0.28)
                      : scheme.onSurface.op(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${marker.totalCount}',
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? scheme.onPrimary
                        : scheme.onSurface.op(0.7),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Text(
        relativeDayLabel(state.selectedDay),
        style: theme.textTheme.titleLarge,
      )
    );
  }
}

/// Compact per-substance row for the selected day; expands to individual entries.
class DayGroupTile extends StatefulWidget {
  const DayGroupTile({super.key, required this.group});

  final DayGroup group;

  @override
  State<DayGroupTile> createState() => _DayGroupTileState();
}

class _DayGroupTileState extends State<DayGroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = widget.group;
    final substance = group.substance;

    final details = <String>[
      fmtAmount(group.totalQuantity, substance.unitName),
      if (group.totalCost != null) fmtMoney(group.totalCost!),
    ];

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    EmojiBadge(emoji: substance.emoji, color: substance.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  substance.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '×${group.count}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: substance.color,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (details.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(details.join(' · '),
                                style: theme.textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Icons.keyboard_arrow_down,
                          color: theme.colorScheme.onSurface.op(0.45)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    children: [
                      Divider(indent: 14, endIndent: 14, height: 1),
                      for (final intake in group.intakes)
                        _IntakeRow(intake: intake, substance: substance),
                      const SizedBox(height: 6),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _IntakeRow extends StatelessWidget {
  const _IntakeRow({required this.intake, required this.substance});

  final Intake intake;
  final Substance substance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = fmtAmount(intake.quantity, substance.unitName);
    final cost = intake.cost == null ? null : fmtMoney(intake.cost!);
    final meta = [amount, ?cost];

    return Dismissible(
      key: ValueKey('intake-${intake.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error.op(0.12),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.error),
      ),
      onDismissed: (_) => _delete(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showIntakeEditor(context, intake: intake),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 46,
                  child: Text(
                    dfTime.format(intake.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.isEmpty ? 'No amount recorded' : meta.join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: meta.isEmpty
                              ? theme.colorScheme.onSurface.op(0.45)
                              : null,
                        ),
                      ),
                      if ((intake.comments ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(intake.comments!,
                            style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18, color: theme.colorScheme.onSurface.op(0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final state = context.read<AppState>();
    await state.deleteIntake(intake.id!);
    if (!context.mounted) return;
    showToast(
      context,
      'Entry deleted',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => state.restoreIntake(intake),
      ),
    );
  }
}
