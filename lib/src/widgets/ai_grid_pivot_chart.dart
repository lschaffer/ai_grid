import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../models/ai_grid_pivot.dart';

/// Data bundle for rendering a pivot chart.
class PivotChartData {
  const PivotChartData({
    required this.categories,
    required this.seriesNames,
    required this.values,
    this.valueFormatter,
  });

  /// Category labels (e.g. Row dimensions like 'Furniture', 'Technology').
  final List<String> categories;

  /// Series names (e.g. Column headings like 'Central', 'East' or Measure names).
  final List<String> seriesNames;

  /// values[seriesIndex][categoryIndex]
  final List<List<num>> values;

  final String Function(num value)? valueFormatter;
}

/// A responsive, high-performance canvas chart specifically designed for [AiGrid] Pivot Mode.
class AiGridPivotChart extends StatefulWidget {
  const AiGridPivotChart({
    super.key,
    required this.data,
    required this.chartType,
    required this.onChartTypeChanged,
    required this.onClose,
  });

  final PivotChartData data;
  final AiGridPivotChartType chartType;
  final ValueChanged<AiGridPivotChartType> onChartTypeChanged;
  final VoidCallback onClose;

  @override
  State<AiGridPivotChart> createState() => _AiGridPivotChartState();
}

class _AiGridPivotChartState extends State<AiGridPivotChart> {
  Offset? _hoverPosition;

  static const List<Color> _palette = <Color>[
    Color(0xFF0078D4), // Fluent Blue
    Color(0xFF107C41), // Excel Green
    Color(0xFFD83B01), // Bright Orange
    Color(0xFF8764B8), // Purple
    Color(0xFF00B7C3), // Teal
    Color(0xFFE3008C), // Magenta
    Color(0xFF5C2D91), // Deep Purple
    Color(0xFF498205), // Olive
  ];

  PivotChartData get _effectiveData {
    final raw = widget.data;
    if (raw.seriesNames.length <= 8 && raw.categories.length <= 15) {
      return raw;
    }

    // Sort series by aggregate value sum across categories and take top 6
    final seriesSums = <int, num>{};
    for (var s = 0; s < raw.seriesNames.length; s++) {
      num sum = 0;
      if (s < raw.values.length) {
        for (final v in raw.values[s]) {
          sum += v;
        }
      }
      seriesSums[s] = sum;
    }

    final sortedSeriesIndices = seriesSums.keys.toList()
      ..sort((a, b) => seriesSums[b]!.compareTo(seriesSums[a]!));
    final topSeriesIndices = sortedSeriesIndices.take(6).toList();

    // Sort categories by sum across top series and take top 10
    final catSums = <int, num>{};
    for (var c = 0; c < raw.categories.length; c++) {
      num sum = 0;
      for (final s in topSeriesIndices) {
        if (s < raw.values.length && c < raw.values[s].length) {
          sum += raw.values[s][c];
        }
      }
      catSums[c] = sum;
    }

    final sortedCatIndices = catSums.keys.toList()
      ..sort((a, b) => catSums[b]!.compareTo(catSums[a]!));
    final topCatIndices = sortedCatIndices.take(10).toList()..sort();

    final newCategories = [for (final c in topCatIndices) raw.categories[c]];
    final newSeriesNames = [for (final s in topSeriesIndices) raw.seriesNames[s]];
    final newValues = <List<num>>[
      for (final s in topSeriesIndices)
        <num>[
          for (final c in topCatIndices)
            (s < raw.values.length && c < raw.values[s].length) ? raw.values[s][c] : 0,
        ],
    ];

    return PivotChartData(
      categories: newCategories,
      seriesNames: newSeriesNames,
      values: newValues,
      valueFormatter: raw.valueFormatter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effective = _effectiveData;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar Header
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252526) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Pivot Chart',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (widget.data.seriesNames.length > effective.seriesNames.length) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Top ${effective.seriesNames.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Builder(
                      builder: (btnContext) {
                        return IconButton(
                          tooltip: 'Change Chart Type',
                          icon: Icon(
                            switch (widget.chartType) {
                              AiGridPivotChartType.groupedBar => Icons.bar_chart,
                              AiGridPivotChartType.column => Icons.equalizer,
                              AiGridPivotChartType.line => Icons.show_chart,
                              AiGridPivotChartType.pie => Icons.pie_chart,
                            },
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          splashRadius: 16,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () async {
                            final box = btnContext.findRenderObject() as RenderBox?;
                            if (box == null) return;
                            final overlay = Overlay.of(btnContext).context.findRenderObject() as RenderBox?;
                            if (overlay == null) return;
                            final position = RelativeRect.fromRect(
                              Rect.fromPoints(
                                box.localToGlobal(Offset.zero, ancestor: overlay),
                                box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
                              ),
                              Offset.zero & overlay.size,
                            );
                            final selected = await showMenu<AiGridPivotChartType>(
                              context: btnContext,
                              position: position,
                              items: [
                                for (final type in AiGridPivotChartType.values)
                                  PopupMenuItem(
                                    value: type,
                                    child: Row(
                                      children: [
                                        Icon(
                                          switch (type) {
                                            AiGridPivotChartType.groupedBar => Icons.bar_chart,
                                            AiGridPivotChartType.column => Icons.equalizer,
                                            AiGridPivotChartType.line => Icons.show_chart,
                                            AiGridPivotChartType.pie => Icons.pie_chart,
                                          },
                                          size: 16,
                                          color: type == widget.chartType
                                              ? theme.colorScheme.primary
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          type.displayName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: type == widget.chartType
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                            if (selected != null) {
                              widget.onChartTypeChanged(selected);
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Hide Chart',
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Legend (Constrained with SingleChildScrollView to never overflow)
          if (effective.seriesNames.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 62),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < effective.seriesNames.length; i++)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _palette[i % _palette.length],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              effective.seriesNames[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      if (widget.data.seriesNames.length > effective.seriesNames.length)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '+${widget.data.seriesNames.length - effective.seriesNames.length} more in table',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Chart Canvas
          Expanded(
            child: effective.categories.isEmpty || effective.seriesNames.isEmpty
                ? Center(
                    child: Text(
                      'No data to visualize',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  )
                : MouseRegion(
                    onHover: (e) => setState(() => _hoverPosition = e.localPosition),
                    onExit: (_) => setState(() => _hoverPosition = null),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _PivotChartPainter(
                        data: effective,
                        chartType: widget.chartType,
                        palette: _palette,
                        isDark: isDark,
                        hoverPosition: _hoverPosition,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PivotChartPainter extends CustomPainter {
  _PivotChartPainter({
    required this.data,
    required this.chartType,
    required this.palette,
    required this.isDark,
    this.hoverPosition,
  });

  final PivotChartData data;
  final AiGridPivotChartType chartType;
  final List<Color> palette;
  final bool isDark;
  final Offset? hoverPosition;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 50 || size.height < 50) return;

    if (chartType == AiGridPivotChartType.pie) {
      _paintPie(canvas, size);
      return;
    }

    _paintCartesian(canvas, size);
  }

  void _paintCartesian(Canvas canvas, Size size) {
    const leftPadding = 55.0;
    const rightPadding = 20.0;
    const topPadding = 25.0;
    const bottomPadding = 45.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // Find max value
    num maxVal = 0;
    for (final series in data.values) {
      for (final v in series) {
        if (v > maxVal) maxVal = v;
      }
    }
    if (maxVal <= 0) maxVal = 100;
    maxVal = _roundUpMax(maxVal);

    final axisPaint = Paint()
      ..color = isDark ? const Color(0xFF444444) : const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    final textStyle = TextStyle(
      color: isDark ? Colors.grey[400] : Colors.grey[600],
      fontSize: 10,
    );

    // Draw horizontal grid lines and Y-axis labels
    const gridSteps = 4;
    for (var i = 0; i <= gridSteps; i++) {
      final y = topPadding + chartHeight - (chartHeight * i / gridSteps);
      final val = maxVal * i / gridSteps;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        axisPaint,
      );

      final label = _formatNumber(val);
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 6, y - tp.height / 2));
    }

    final catCount = data.categories.length;
    final seriesCount = data.seriesNames.length;
    final slotWidth = chartWidth / catCount;

    String? hoverTooltipText;
    Offset? tooltipAnchor;

    // Draw categories
    for (var c = 0; c < catCount; c++) {
      final xCenter = leftPadding + (c + 0.5) * slotWidth;

      // Draw X label
      final catName = data.categories[c];
      final shortLabel =
          catName.length > 10 ? '${catName.substring(0, 9)}…' : catName;
      final catTp = TextPainter(
        text: TextSpan(text: shortLabel, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slotWidth);
      catTp.paint(
        canvas,
        Offset(xCenter - catTp.width / 2, topPadding + chartHeight + 8),
      );

      if (chartType == AiGridPivotChartType.groupedBar) {
        final barGroupWidth = slotWidth * 0.75;
        final barWidth = (barGroupWidth / seriesCount).clamp(3.0, 36.0);
        final startX = xCenter - (barWidth * seriesCount) / 2;

        for (var s = 0; s < seriesCount; s++) {
          final val = (c < data.values[s].length) ? data.values[s][c] : 0;
          final barH = (val / maxVal * chartHeight).clamp(0.0, chartHeight);
          final barRect = Rect.fromLTWH(
            startX + s * barWidth,
            topPadding + chartHeight - barH,
            barWidth - 2,
            barH,
          );

          final barPaint = Paint()
            ..color = palette[s % palette.length]
            ..style = PaintingStyle.fill;
          canvas.drawRRect(
            RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
            barPaint,
          );

          // Check hover
          if (hoverPosition != null && barRect.contains(hoverPosition!)) {
            hoverTooltipText =
                '${data.categories[c]}\n${data.seriesNames[s]}: ${_formatNumber(val)}';
            tooltipAnchor = Offset(barRect.center.dx, barRect.top);
          }
        }
      } else if (chartType == AiGridPivotChartType.column) {
        // Single summary bar
        num sumVal = 0;
        for (var s = 0; s < seriesCount; s++) {
          if (c < data.values[s].length) sumVal += data.values[s][c];
        }
        final barH = (sumVal / (maxVal * seriesCount) * chartHeight)
            .clamp(0.0, chartHeight);
        final barWidth = (slotWidth * 0.5).clamp(6.0, 48.0);
        final barRect = Rect.fromLTWH(
          xCenter - barWidth / 2,
          topPadding + chartHeight - barH,
          barWidth,
          barH,
        );

        final barPaint = Paint()
          ..color = palette[0]
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(barRect, const Radius.circular(3)),
          barPaint,
        );

        if (hoverPosition != null && barRect.contains(hoverPosition!)) {
          hoverTooltipText =
              '${data.categories[c]}\nTotal: ${_formatNumber(sumVal)}';
          tooltipAnchor = Offset(barRect.center.dx, barRect.top);
        }
      }
    }

    // Line Chart
    if (chartType == AiGridPivotChartType.line) {
      for (var s = 0; s < seriesCount; s++) {
        final linePath = Path();
        final points = <Offset>[];
        for (var c = 0; c < catCount; c++) {
          final x = leftPadding + (c + 0.5) * slotWidth;
          final val = (c < data.values[s].length) ? data.values[s][c] : 0;
          final y = topPadding + chartHeight - (val / maxVal * chartHeight);
          points.add(Offset(x, y));
          if (c == 0) {
            linePath.moveTo(x, y);
          } else {
            linePath.lineTo(x, y);
          }
        }

        final linePaint = Paint()
          ..color = palette[s % palette.length]
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawPath(linePath, linePaint);

        // Dots
        final dotPaint = Paint()
          ..color = palette[s % palette.length]
          ..style = PaintingStyle.fill;
        for (var i = 0; i < points.length; i++) {
          canvas.drawCircle(points[i], 3.5, dotPaint);

          if (hoverPosition != null &&
              (hoverPosition! - points[i]).distance <= 12) {
            final val = (i < data.values[s].length) ? data.values[s][i] : 0;
            hoverTooltipText =
                '${data.categories[i]}\n${data.seriesNames[s]}: ${_formatNumber(val)}';
            tooltipAnchor = points[i];
          }
        }
      }
    }

    // Draw hover tooltip
    if (hoverTooltipText != null && tooltipAnchor != null) {
      _drawTooltip(canvas, size, tooltipAnchor, hoverTooltipText);
    }
  }

  void _paintPie(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.5;
    if (radius <= 10) return;

    // Sum totals by category (using first series or sum of series)
    final catTotals = <num>[];
    num grandTotal = 0;
    for (var c = 0; c < data.categories.length; c++) {
      num catSum = 0;
      for (var s = 0; s < data.seriesNames.length; s++) {
        if (c < data.values[s].length) catSum += data.values[s][c];
      }
      catTotals.add(catSum);
      grandTotal += catSum;
    }
    if (grandTotal <= 0) grandTotal = 1;

    var startAngle = -math.pi / 2;
    final innerRadius = radius * 0.45; // Donut style

    String? hoverTooltipText;
    Offset? tooltipAnchor;

    for (var i = 0; i < catTotals.length; i++) {
      final sweepAngle = (catTotals[i] / grandTotal) * 2 * math.pi;
      final color = palette[i % palette.length];

      final arcPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final path = Path()
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerRadius),
          startAngle + sweepAngle,
          -sweepAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, arcPaint);

      // Check hover
      if (hoverPosition != null) {
        final d = (hoverPosition! - center).distance;
        if (d >= innerRadius && d <= radius) {
          var angle = math.atan2(
            hoverPosition!.dy - center.dy,
            hoverPosition!.dx - center.dx,
          );
          if (angle < -math.pi / 2) angle += 2 * math.pi;
          if (angle >= startAngle && angle < startAngle + sweepAngle) {
            final pct = (catTotals[i] / grandTotal * 100).toStringAsFixed(1);
            hoverTooltipText =
                '${data.categories[i]}\n${_formatNumber(catTotals[i])} ($pct%)';
            tooltipAnchor = hoverPosition;
          }
        }
      }

      startAngle += sweepAngle;
    }

    if (hoverTooltipText != null && tooltipAnchor != null) {
      _drawTooltip(canvas, size, tooltipAnchor, hoverTooltipText);
    }
  }

  void _drawTooltip(Canvas canvas, Size size, Offset anchor, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 160);

    const pad = 6.0;
    final rect = Rect.fromLTWH(
      (anchor.dx - tp.width / 2 - pad).clamp(8.0, size.width - tp.width - 16),
      (anchor.dy - tp.height - pad * 2 - 8).clamp(8.0, size.height - tp.height - 16),
      tp.width + pad * 2,
      tp.height + pad * 2,
    );

    final bgPaint = Paint()
      ..color = const Color(0xE6222222)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      bgPaint,
    );

    tp.paint(canvas, Offset(rect.left + pad, rect.top + pad));
  }

  static String _formatNumber(num value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  static num _roundUpMax(num val) {
    if (val <= 10) return 10;
    final factor = math.pow(10, (math.log(val) / math.ln10).floor());
    return ((val / factor).ceil()) * factor;
  }

  @override
  bool shouldRepaint(covariant _PivotChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.chartType != chartType ||
        oldDelegate.hoverPosition != hoverPosition ||
        oldDelegate.isDark != isDark;
  }
}
