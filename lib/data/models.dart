import 'package:flutter/material.dart';

import '../util/color.dart';

/// Local-calendar day key, e.g. `2026-09-17`.
///
/// Storing this alongside the raw timestamp lets SQLite group by *local* day
/// without any timezone maths, which is the one thing that reliably breaks
/// calendar apps built on epoch millis alone.
String dayKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isFutureDay(DateTime d) => dateOnly(d).isAfter(dateOnly(DateTime.now()));

/// A user-defined substance.
@immutable
class Substance {
  final int? id;
  final String name;
  final String emoji;
  final String unitName;
  final int colorValue;

  const Substance({
    this.id,
    required this.name,
    required this.emoji,
    this.unitName = 'g',
    this.colorValue = 0xFF7B68EE,
  });

  Color get color => Color(colorValue);

  Substance copyWith({
    int? id,
    String? name,
    String? emoji,
    String? unitName,
    int? colorValue,
  }) {
    return Substance(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      unitName: unitName ?? this.unitName,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'emoji': emoji,
    'unit_name': unitName,
    'color': colorValue,
  };

  static Substance fromMap(Map<String, Object?> m) => Substance(
    id: m['id'] as int?,
    name: m['name'] as String,
    emoji: m['emoji'] as String,
    unitName: (m['unit_name'] as String?) ?? 'g',
    colorValue:
        (m['color'] as int?) ?? fallbackEmojiColor(m['emoji'] as String),
  );
}

/// A single consumption event.
@immutable
class Intake {
  final int? id;
  final int substanceId;
  final DateTime timestamp;
  final int quantity;
  final double? cost;
  final String? comments;

  const Intake({
    this.id,
    required this.substanceId,
    required this.timestamp,
    required this.quantity,
    this.cost,
    this.comments,
  });


  Map<String, Object?> toMap() {
    final c = comments?.trim();
    return {
      if (id != null) 'id': id,
      'substance_id': substanceId,
      'ts': timestamp.millisecondsSinceEpoch,
      'day': dayKeyOf(timestamp),
      'quantity': quantity,
      'cost': cost,
      'comments': (c == null || c.isEmpty) ? null : c,
    };
  }

  static Intake fromMap(Map<String, Object?> m) => Intake(
    id: m['id'] as int?,
    substanceId: m['substance_id'] as int,
    timestamp: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
    quantity: m['quantity'] as int,
    cost: (m['cost'] as num?)?.toDouble(),
    comments: m['comments'] as String?,
  );
}

/// What a calendar cell needs to know.
@immutable
class DayMarker {
  final Substance topSubstance;
  final int totalCount;
  final int distinctSubstances;

  const DayMarker({
    required this.topSubstance,
    required this.totalCount,
    required this.distinctSubstances,
  });
}

/// One substance's entries within a single day.
class DayGroup {
  final Substance substance;
  final List<Intake> intakes;

  DayGroup({required this.substance, required this.intakes});

  int get count => intakes.length;

  int get totalQuantity {
    int sum = 0;
    for (final i in intakes) {
      sum += i.quantity;
    }
    return sum;
  }

  double? get totalCost {
    double? sum;
    for (final i in intakes) {
      if (i.cost != null) sum = (sum ?? 0) + i.cost!;
    }
    return sum;
  }
}

@immutable
class DateSpan {
  final DateTime start;
  final DateTime end;
  const DateSpan(this.start, this.end);

  int get days => dateOnly(end).difference(dateOnly(start)).inDays + 1;
}

@immutable
class DayCount {
  final DateTime day;
  final int count;
  const DayCount(this.day, this.count);
}

@immutable
class SubstanceStat {
  final Substance substance;
  final int count;
  final int quantity;
  final double? cost;
  final int daysUsed;

  const SubstanceStat({
    required this.substance,
    required this.count,
    required this.quantity,
    required this.cost,
    required this.daysUsed,
  });
}

@immutable
class RangeStats {
  final DateSpan span;
  final int totalIntakes;
  final double totalCost;
  final int activeDays;
  final List<SubstanceStat> perSubstance;
  final List<DayCount> daily;

  const RangeStats({
    required this.span,
    required this.totalIntakes,
    required this.totalCost,
    required this.activeDays,
    required this.perSubstance,
    required this.daily,
  });

  bool get isEmpty => totalIntakes == 0;
}
