part of 'home_medication_timing_chart.dart';

class _TimingSummary extends StatelessWidget {
  const _TimingSummary({required this.counts});

  final _DoseTimingCounts counts;

  String _label(_DoseTiming timing) => switch (timing) {
    _DoseTiming.early => _text('homeMedicineEarly', 'Early'),
    _DoseTiming.onTime => _text('homeMedicineOnTime', 'On time'),
    _DoseTiming.late => _text('homeMedicineLate', 'Late'),
  };

  Color _color(_DoseTiming timing) => switch (timing) {
    _DoseTiming.early => _earlyColor,
    _DoseTiming.onTime => _onTimeColor,
    _DoseTiming.late => _lateColor,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timings = _DoseTiming.values;
    final percentages = {
      for (final timing in timings)
        timing: (counts.values[timing]! * 100 / counts.total).round(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 28,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CustomPaint(
              painter: _TimingBarPainter(
                counts: counts.values,
                colors: {for (final timing in timings) timing: _color(timing)},
                textDirection: Directionality.of(context),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            for (final timing in timings)
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _color(timing),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _label(timing),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        toWesternDigits('${percentages[timing]}%'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: _color(timing),
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
