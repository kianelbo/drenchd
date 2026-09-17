import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/formatters.dart';
import 'widgets.dart';

enum _Preset { week, month, quarter, year, all, custom }

extension on _Preset {
  String get label => switch (this) {
        _Preset.week => '7 days',
        _Preset.month => '30 days',
        _Preset.quarter => '90 days',
        _Preset.year => '12 months',
        _Preset.all => 'All time',
        _Preset.custom => 'Custom',
      };
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _Preset _preset = _Preset.month;
  DateSpan _span = _spanForDays(30);
  final Set<int> _drugFilter = <int>{};

  AppState? _state;
  Future<RangeStats>? _future;

  static DateSpan _spanForDays(int days) {
    final today = dateOnly(DateTime.now());
    return DateSpan(
      DateTime(today.year, today.month, today.day - (days - 1)),
      today,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (identical(state, _state)) return;
    _state?.removeListener(_recompute);
    _state = state..addListener(_recompute);
    _recompute();
  }

  @override
  void dispose() {
    _state?.removeListener(_recompute);
    super.dispose();
  }

  /// Recomputed only when the range, the filter, or the data actually change —
  /// not on every rebuild, which would flash the spinner.
  void _recompute() {
    final state = _state;
    if (state == null || !mounted) return;
    setState(() {
      _future = state.statsFor(_span, Set<int>.from(_drugFilter));
    });
  }

  Future<void> _applyPreset(_Preset preset) async {
    final state = context.read<AppState>();
    DateSpan span;
    switch (preset) {
      case _Preset.week:
        span = _spanForDays(7);
      case _Preset.month:
        span = _spanForDays(30);
      case _Preset.quarter:
        span = _spanForDays(90);
      case _Preset.year:
        span = _spanForDays(365);
      case _Preset.all:
        {
          final earliest = await state.earliestEntry();
          span = DateSpan(
            dateOnly(earliest ?? DateTime.now()),
            dateOnly(DateTime.now()),
          );
        }
      case _Preset.custom:
        {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2015),
            lastDate: DateTime(DateTime.now().year + 1, 12, 31),
            initialDateRange:
                DateTimeRange(start: _span.start, end: _span.end),
          );
          if (picked == null) return;
          span = DateSpan(dateOnly(picked.start), dateOnly(picked.end));
        }
    }
    if (!mounted) return;
    _preset = preset;
    _span = span;
    _recompute();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Insights', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  '${dfDayMedium.format(_span.start)} – '
                  '${dfDayMedium.format(_span.end)} · ${_span.days} days',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              children: [
                for (final p in _Preset.values) ...[
                  ChoiceChip(
                    label: Text(p.label),
                    selected: _preset == p,
                    onSelected: (_) => _applyPreset(p),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        if (state.activeDrugs.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                children: [
                  ChoiceChip(
                    label: const Text('Everything'),
                    selected: _drugFilter.isEmpty,
                    onSelected: (_) {
                      _drugFilter.clear();
                      _recompute();
                    },
                  ),
                  const SizedBox(width: 8),
                  for (final d in state.activeDrugs) ...[
                    FilterChip(
                      avatar:
                          Text(d.emoji, style: const TextStyle(fontSize: 14)),
                      label: Text(d.name),
                      selected: _drugFilter.contains(d.id),
                      selectedColor: d.color.op(0.2),
                      onSelected: (on) {
                        if (on) {
                          _drugFilter.add(d.id!);
                        } else {
                          _drugFilter.remove(d.id);
                        }
                        _recompute();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: FutureBuilder<RangeStats>(
            future: _future,
            builder: (context, snapshot) {
              final stats = snapshot.data;
              if (stats == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (stats.isEmpty) {
                return const EmptyState(
                  title: 'Nothing in this range',
                  message: 'Widen the dates or clear the filters to see totals.',
                );
              }
              return _StatsBody(stats: stats);
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});

  final RangeStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = stats.perDrug.isEmpty
        ? 1
        : stats.perDrug.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    final perDay = stats.totalIntakes / stats.span.days;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  value: '${stats.totalIntakes}',
                  label: 'entries',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  value: '${stats.activeDays}/${stats.span.days}',
                  label: 'days with an entry',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  value: fmtMoney(stats.totalCost),
                  label: 'recorded spend',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  value: perDay.toStringAsFixed(perDay >= 10 ? 0 : 1),
                  label: 'entries per day',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Daily activity'),
                const SizedBox(height: 14),
                _ActivityChart(data: stats.daily),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dfDayShort.format(stats.span.start),
                        style: theme.textTheme.bodySmall),
                    Text(dfDayShort.format(stats.span.end),
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Breakdown'),
          const SizedBox(height: 10),
          for (final stat in stats.perDrug) ...[
            _BreakdownRow(stat: stat, maxCount: maxCount),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.data});

  final List<DayCount> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (data.isEmpty) return const SizedBox(height: 74);
    final peak =
        data.map((d) => d.count).fold<int>(1, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 74,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in data)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.8),
                child: Container(
                  height: d.count == 0 ? 3 : 6 + (68 * d.count / peak),
                  decoration: BoxDecoration(
                    color: d.count == 0
                        ? scheme.onSurface.op(0.07)
                        : scheme.primary.op(0.35 + 0.65 * (d.count / peak)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.stat, required this.maxCount});

  final DrugStat stat;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final drug = stat.drug;
    final meta = <String>[
      '${stat.daysUsed} ${stat.daysUsed == 1 ? 'day' : 'days'}',
      if (stat.quantity != null) fmtAmount(stat.quantity, drug.unitName)!,
      if (stat.cost != null && stat.cost! > 0) fmtMoney(stat.cost!),
    ];

    return Panel(
      child: Row(
        children: [
          EmojiBadge(emoji: drug.emoji, color: drug.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(drug.name,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '×${stat.count}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: drug.color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ShareBar(
                  fraction: maxCount == 0 ? 0 : stat.count / maxCount,
                  color: drug.color,
                ),
                const SizedBox(height: 6),
                Text(meta.join(' · '), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
