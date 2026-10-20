import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/calendar_date.dart';

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.content,
    required this.fontSize,
    required this.onDoubleTap,
  });
  final DateTime date;
  final bool inMonth, isToday;
  final String content;
  final double fontSize;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: Key('day-${dateKey(date)}'),
    behavior: HitTestBehavior.opaque,
    onDoubleTap: onDoubleTap,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: isToday ? Colors.teal.withValues(alpha: 0.12) : null,
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Keep the date visible even in a six-week month at the minimum
            // window size. Only scale the date label if available height demands it.
            final labelHeight = math.min(fontSize * 1.5, constraints.maxHeight);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: labelHeight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: !inMonth
                            ? Colors.grey
                            : date.weekday == DateTime.sunday
                            ? Colors.red.shade700
                            : date.weekday == DateTime.saturday
                            ? Colors.blue.shade700
                            : Colors.black87,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        content,
                        style: TextStyle(fontSize: fontSize, height: 1.25),
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
