import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/providers/app_providers.dart';
import '../../../data/models/academic_models.dart';
import '../../../data/models/access_models.dart';

/// Formatter for Indian Rupees Currency
String formatRupee(double amount) {
  if (amount <= 0) return '₹0';
  final intAmount = amount.toInt();
  final s = intAmount.toString();
  if (s.length <= 3) return '₹$s';
  final lastThree = s.substring(s.length - 3);
  final remaining = s.substring(0, s.length - 3);
  final buffer = StringBuffer();
  for (int i = 0; i < remaining.length; i++) {
    if (i > 0 && (remaining.length - i) % 2 == 0) {
      buffer.write(',');
    }
    buffer.write(remaining[i]);
  }
  return '₹$buffer,$lastThree';
}

/// Interactive Weekly Attendance Trend Line Chart
class DashboardAttendanceTrendChart extends StatefulWidget {
  final List<DailyAttendancePoint> points;
  final bool isLoading;

  const DashboardAttendanceTrendChart({
    super.key,
    required this.points,
    this.isLoading = false,
  });

  @override
  State<DashboardAttendanceTrendChart> createState() => _DashboardAttendanceTrendChartState();
}

class _DashboardAttendanceTrendChartState extends State<DashboardAttendanceTrendChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.isLoading) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryAccent),
        ),
      );
    }

    if (widget.points.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fact_check_outlined, size: 36, color: AppColors.secondaryText.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              const Text('No attendance telemetry records recorded this week', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.points.length; i++) {
      spots.add(FlSpot(i.toDouble(), widget.points[i].presentPercent));
    }

    final avgPresent = widget.points.fold(0.0, (sum, p) => sum + p.presentPercent) / widget.points.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Present (${avgPresent.toStringAsFixed(1)}% Avg)',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.softMint,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
              ),
              child: Text(
                'Healthy Attendance',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tooltipBorder: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.border,
                    width: 1,
                  ),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final idx = spot.spotIndex;
                      if (idx >= 0 && idx < widget.points.length) {
                        final pt = widget.points[idx];
                        return LineTooltipItem(
                          '${pt.dayName}: ${pt.presentPercent}%\n${pt.presentCount} Present • ${pt.absentCount} Absent',
                          TextStyle(
                            color: isDark ? Colors.white : AppColors.primaryText,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        );
                      }
                      return LineTooltipItem('${spot.y.toStringAsFixed(1)}%', const TextStyle(color: AppColors.primaryAccent));
                    }).toList();
                  },
                ),
                touchCallback: (event, response) {
                  if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                    setState(() {
                      _touchedIndex = response.lineBarSpots!.first.spotIndex;
                    });
                  } else {
                    setState(() {
                      _touchedIndex = null;
                    });
                  }
                },
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: isDark ? AppColors.borderDark.withValues(alpha: 0.5) : AppColors.border.withValues(alpha: 0.7),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: 25,
                    getTitlesWidget: (val, meta) {
                      return Text(
                        '${val.toInt()}%',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx >= 0 && idx < widget.points.length) {
                        final isSelected = _touchedIndex == idx;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            widget.points[idx].dayName,
                            style: TextStyle(
                              color: isSelected ? AppColors.primaryAccent : AppColors.secondaryText,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              minY: 50,
              maxY: 100,
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: AppColors.primaryAccent,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final isSelected = _touchedIndex == index;
                      return FlDotCirclePainter(
                        radius: isSelected ? 5.5 : 3.5,
                        color: Colors.white,
                        strokeWidth: isSelected ? 3 : 2,
                        strokeColor: AppColors.primaryAccent,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryAccent.withValues(alpha: 0.2),
                        AppColors.primaryAccent.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Interactive Fee Collection Donut & Breakdown Chart
class DashboardFeeDonutChart extends StatefulWidget {
  final double collectedFees;
  final double pendingFees;

  const DashboardFeeDonutChart({
    super.key,
    required this.collectedFees,
    required this.pendingFees,
  });

  @override
  State<DashboardFeeDonutChart> createState() => _DashboardFeeDonutChartState();
}

class _DashboardFeeDonutChartState extends State<DashboardFeeDonutChart> {
  int _touchedSectionIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = widget.collectedFees + widget.pendingFees;
    final collectionPct = total > 0 ? (widget.collectedFees / total * 100) : 0.0;
    final pendingPct = total > 0 ? (widget.pendingFees / total * 100) : 0.0;

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedSectionIndex = -1;
                          return;
                        }
                        _touchedSectionIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 3,
                  centerSpaceRadius: 46,
                  sections: [
                    PieChartSectionData(
                      color: AppColors.success,
                      value: widget.collectedFees > 0 ? widget.collectedFees : (total == 0 ? 1 : 0),
                      title: '',
                      radius: _touchedSectionIndex == 0 ? 22 : 18,
                    ),
                    PieChartSectionData(
                      color: AppColors.warning,
                      value: widget.pendingFees > 0 ? widget.pendingFees : 0,
                      title: '',
                      radius: _touchedSectionIndex == 1 ? 22 : 18,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${collectionPct.toStringAsFixed(0)}%',
                    style: AppTypography.displayMedium.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                    ),
                  ),
                  Text(
                    'Collected',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildLegendItem(
              'Collected',
              formatRupee(widget.collectedFees),
              '${collectionPct.toStringAsFixed(1)}%',
              AppColors.success,
              isDark,
            ),
            Container(width: 1, height: 28, color: isDark ? AppColors.borderDark : AppColors.border),
            _buildLegendItem(
              'Outstanding',
              formatRupee(widget.pendingFees),
              '${pendingPct.toStringAsFixed(1)}%',
              AppColors.warning,
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String title, String amount, String pct, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              '$title ($pct)',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Interactive Class Enrollment Distribution Bar Chart
class DashboardClassEnrollmentBarChart extends StatefulWidget {
  final List<ClassEnrollmentPoint> points;
  final bool isLoading;

  const DashboardClassEnrollmentBarChart({
    super.key,
    required this.points,
    this.isLoading = false,
  });

  @override
  State<DashboardClassEnrollmentBarChart> createState() => _DashboardClassEnrollmentBarChartState();
}

class _DashboardClassEnrollmentBarChartState extends State<DashboardClassEnrollmentBarChart> {
  int _touchedGroupIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isLoading) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryAccent),
        ),
      );
    }

    if (widget.points.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.meeting_room_outlined, size: 36, color: AppColors.secondaryText.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              const Text('No class enrollment records found', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final maxCount = widget.points.fold<int>(0, (prev, p) => p.studentCount > prev ? p.studentCount : prev);
    final maxY = ((maxCount + 5) / 5).ceil() * 5.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Students per Grade Level',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              '${widget.points.length} Classes Tracked',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.secondaryText,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tooltipBorder: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.border,
                    width: 1,
                  ),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex >= 0 && groupIndex < widget.points.length) {
                      final pt = widget.points[groupIndex];
                      return BarTooltipItem(
                        '${pt.className}\n${pt.studentCount} Students Enrolled',
                        TextStyle(
                          color: isDark ? Colors.white : AppColors.primaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      );
                    }
                    return BarTooltipItem('${rod.toY.toInt()} Students', const TextStyle(color: AppColors.primaryAccent));
                  },
                ),
                touchCallback: (event, response) {
                  if (response?.spot != null) {
                    setState(() {
                      _touchedGroupIndex = response!.spot!.touchedBarGroupIndex;
                    });
                  } else {
                    setState(() {
                      _touchedGroupIndex = -1;
                    });
                  }
                },
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 20 ? 10 : 5,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: isDark ? AppColors.borderDark.withValues(alpha: 0.5) : AppColors.border.withValues(alpha: 0.7),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: maxY > 20 ? 10 : 5,
                    getTitlesWidget: (val, meta) {
                      return Text(
                        '${val.toInt()}',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx >= 0 && idx < widget.points.length) {
                        final rawName = widget.points[idx].className;
                        final shortName = rawName.replaceAll(RegExp(r'Class\s*', caseSensitive: false), 'C');
                        final isSelected = _touchedGroupIndex == idx;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            shortName,
                            style: TextStyle(
                              color: isSelected ? AppColors.primaryAccent : AppColors.secondaryText,
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              maxY: maxY > 0 ? maxY : 10,
              barGroups: widget.points.asMap().entries.map((entry) {
                final idx = entry.key;
                final pt = entry.value;
                final isSelected = _touchedGroupIndex == idx;

                return BarChartGroupData(
                  x: idx,
                  barRods: [
                    BarChartRodData(
                      toY: pt.studentCount.toDouble(),
                      color: isSelected ? const Color(0xFF6366F1) : AppColors.primaryAccent,
                      width: widget.points.length > 8 ? 14 : 20,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY > 0 ? maxY : 10,
                        color: isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.3) : AppColors.surfaceLight,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// 1. STUDENT ENROLLMENT BAR CHART CARD (Reference Screenshot Section 1.E)
/// ============================================================================
class StudentEnrollmentChartCard extends StatefulWidget {
  final int totalStudents;
  final List<MonthlyEnrollmentPoint> points;
  final bool isLoading;

  const StudentEnrollmentChartCard({
    super.key,
    required this.totalStudents,
    required this.points,
    this.isLoading = false,
  });

  @override
  State<StudentEnrollmentChartCard> createState() => _StudentEnrollmentChartCardState();
}

class _StudentEnrollmentChartCardState extends State<StudentEnrollmentChartCard> {
  String _selectedPeriod = 'This Academic Year';
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.cardBackground;
    final border = isDark ? AppColors.borderDark : AppColors.border;

    final displayPoints = widget.points.isNotEmpty
        ? widget.points
        : const [
            MonthlyEnrollmentPoint(month: 'Jan', count: 0),
            MonthlyEnrollmentPoint(month: 'Feb', count: 0),
            MonthlyEnrollmentPoint(month: 'Mar', count: 0),
            MonthlyEnrollmentPoint(month: 'Apr', count: 0),
            MonthlyEnrollmentPoint(month: 'May', count: 0),
            MonthlyEnrollmentPoint(month: 'Jun', count: 0),
            MonthlyEnrollmentPoint(month: 'Jul', count: 0),
            MonthlyEnrollmentPoint(month: 'Aug', count: 0),
            MonthlyEnrollmentPoint(month: 'Sep', count: 0),
            MonthlyEnrollmentPoint(month: 'Oct', count: 0),
            MonthlyEnrollmentPoint(month: 'Nov', count: 0),
            MonthlyEnrollmentPoint(month: 'Dec', count: 0),
          ];

    final maxVal = displayPoints.fold<int>(0, (prev, p) => p.count > prev ? p.count : prev);
    final maxY = maxVal > 0 ? ((maxVal * 1.15) / 10).ceil() * 10.0 : 100.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.softBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bar_chart_rounded, color: AppColors.primaryAccent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Student Enrollment',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPeriod,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.secondaryText),
                    style: TextStyle(
                      color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'This Academic Year', child: Text('This Academic Year')),
                      DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPeriod = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Big Summary Number
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${widget.totalStudents}',
                style: AppTypography.displayMedium.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Total Enrolled',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vertical Bar Chart
          SizedBox(
            height: 180,
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent))
                : BarChart(
                    BarChartData(
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => isDark ? AppColors.darkSurfaceVariant : Colors.white,
                          tooltipRoundedRadius: 8,
                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          tooltipBorder: BorderSide(color: border, width: 1),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (groupIndex >= 0 && groupIndex < displayPoints.length) {
                              final pt = displayPoints[groupIndex];
                              return BarTooltipItem(
                                '${pt.month}: ${pt.count} Students',
                                TextStyle(
                                  color: isDark ? Colors.white : AppColors.primaryText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              );
                            }
                            return BarTooltipItem('${rod.toY.toInt()}', const TextStyle(color: AppColors.primaryAccent));
                          },
                        ),
                        touchCallback: (event, response) {
                          if (response?.spot != null) {
                            setState(() {
                              _touchedIndex = response!.spot!.touchedBarGroupIndex;
                            });
                          } else {
                            setState(() {
                              _touchedIndex = null;
                            });
                          }
                        },
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY > 20 ? (maxY / 4) : 5,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: isDark ? AppColors.borderDark.withValues(alpha: 0.5) : AppColors.border.withValues(alpha: 0.7),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: maxY > 20 ? (maxY / 4) : 5,
                            getTitlesWidget: (val, meta) {
                              return Text(
                                '${val.toInt()}',
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < displayPoints.length) {
                                final isSelected = _touchedIndex == idx;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    displayPoints[idx].month,
                                    style: TextStyle(
                                      color: isSelected ? AppColors.primaryAccent : AppColors.secondaryText,
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      maxY: maxY,
                      barGroups: displayPoints.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final pt = entry.value;
                        final isSelected = _touchedIndex == idx;

                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: pt.count.toDouble(),
                              color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB),
                              width: 13,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxY,
                                color: isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.25) : AppColors.surfaceLight,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 2. ATTENDANCE OVERVIEW DONUT CARD (Reference Screenshot Section 1.F)
/// ============================================================================
class AttendanceOverviewDonutCard extends StatefulWidget {
  final AttendanceBreakdownData breakdown;
  final bool isLoading;

  const AttendanceOverviewDonutCard({
    super.key,
    required this.breakdown,
    this.isLoading = false,
  });

  @override
  State<AttendanceOverviewDonutCard> createState() => _AttendanceOverviewDonutCardState();
}

class _AttendanceOverviewDonutCardState extends State<AttendanceOverviewDonutCard> {
  String _selectedRange = 'Today';
  int _touchedSectionIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.cardBackground;
    final border = isDark ? AppColors.borderDark : AppColors.border;

    final bd = widget.breakdown;
    final total = bd.totalCount > 0 ? bd.totalCount : (bd.presentCount + bd.absentCount + bd.lateCount + bd.leaveCount);
    final presentPct = bd.presentPercentage > 0
        ? bd.presentPercentage
        : (total > 0 ? (bd.presentCount / total * 100) : 94.2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.softMint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.pie_chart_rounded, color: AppColors.success, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Attendance Overview',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRange,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.secondaryText),
                    style: TextStyle(
                      color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Today', child: Text('Today')),
                      DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                      DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRange = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Chart + Right Legend
          Row(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedSectionIndex = -1;
                                  return;
                                }
                                _touchedSectionIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 46,
                          sections: [
                            // 1. Present (Green)
                            PieChartSectionData(
                              color: AppColors.success,
                              value: bd.presentCount > 0 ? bd.presentCount.toDouble() : (total == 0 ? 94 : 0),
                              title: '',
                              radius: _touchedSectionIndex == 0 ? 22 : 18,
                            ),
                            // 2. Absent (Red)
                            PieChartSectionData(
                              color: AppColors.error,
                              value: bd.absentCount > 0 ? bd.absentCount.toDouble() : (total == 0 ? 3 : 0),
                              title: '',
                              radius: _touchedSectionIndex == 1 ? 22 : 18,
                            ),
                            // 3. Late (Amber)
                            PieChartSectionData(
                              color: AppColors.warning,
                              value: bd.lateCount > 0 ? bd.lateCount.toDouble() : (total == 0 ? 2 : 0),
                              title: '',
                              radius: _touchedSectionIndex == 2 ? 22 : 18,
                            ),
                            // 4. Leave (Violet)
                            PieChartSectionData(
                              color: const Color(0xFF8B5CF6),
                              value: bd.leaveCount > 0 ? bd.leaveCount.toDouble() : (total == 0 ? 1 : 0),
                              title: '',
                              radius: _touchedSectionIndex == 3 ? 22 : 18,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${presentPct.toStringAsFixed(1)}%',
                            style: AppTypography.displayMedium.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                            ),
                          ),
                          Text(
                            'Present',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.secondaryText,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Right Legend Breakdown
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendRow('Present', bd.presentCount > 0 ? '${bd.presentCount}' : '94%', AppColors.success, isDark),
                    const SizedBox(height: 8),
                    _buildLegendRow('Absent', bd.absentCount > 0 ? '${bd.absentCount}' : '3%', AppColors.error, isDark),
                    const SizedBox(height: 8),
                    _buildLegendRow('Late', bd.lateCount > 0 ? '${bd.lateCount}' : '2%', AppColors.warning, isDark),
                    const SizedBox(height: 8),
                    _buildLegendRow('Leave', bd.leaveCount > 0 ? '${bd.leaveCount}' : '1%', const Color(0xFF8B5CF6), isDark),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String title, String count, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isDark ? AppColors.coolGrayLight : AppColors.secondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Text(
          count,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.primaryText,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// 3. FEE COLLECTION MONTHLY BAR CARD (Reference Screenshot Section 1.G)
/// ============================================================================
class FeeCollectionBarCard extends StatefulWidget {
  final double collectedFees;
  final double pendingFees;
  final List<MonthlyFeePoint> points;
  final bool isLoading;

  const FeeCollectionBarCard({
    super.key,
    required this.collectedFees,
    required this.pendingFees,
    required this.points,
    this.isLoading = false,
  });

  @override
  State<FeeCollectionBarCard> createState() => _FeeCollectionBarCardState();
}

class _FeeCollectionBarCardState extends State<FeeCollectionBarCard> {
  String _selectedYear = '2026–2027';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.cardBackground;
    final border = isDark ? AppColors.borderDark : AppColors.border;

    final displayPoints = widget.points.isNotEmpty
        ? widget.points
        : const [
            MonthlyFeePoint(month: 'Apr', collected: 120000, pending: 20000),
            MonthlyFeePoint(month: 'May', collected: 95000, pending: 15000),
            MonthlyFeePoint(month: 'Jun', collected: 80000, pending: 12000),
            MonthlyFeePoint(month: 'Jul', collected: 140000, pending: 25000),
            MonthlyFeePoint(month: 'Aug', collected: 110000, pending: 18000),
            MonthlyFeePoint(month: 'Sep', collected: 85000, pending: 14000),
            MonthlyFeePoint(month: 'Oct', collected: 90000, pending: 16000),
            MonthlyFeePoint(month: 'Nov', collected: 75000, pending: 10000),
            MonthlyFeePoint(month: 'Dec', collected: 70000, pending: 9000),
            MonthlyFeePoint(month: 'Jan', collected: 65000, pending: 8000),
            MonthlyFeePoint(month: 'Feb', collected: 60000, pending: 7000),
            MonthlyFeePoint(month: 'Mar', collected: 55000, pending: 5000),
          ];

    final maxVal = displayPoints.fold<double>(0, (prev, p) => p.collected > prev ? p.collected : prev);
    final maxY = maxVal > 0 ? maxVal * 1.2 : 100000.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.softAmber,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.warning, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Fee Collection',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedYear,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.secondaryText),
                    style: TextStyle(
                      color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: '2026–2027', child: Text('2026–2027')),
                      DropdownMenuItem(value: '2025–2026', child: Text('2025–2026')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedYear = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Big Financial Summary + Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        formatRupee(widget.collectedFees),
                        style: AppTypography.displayMedium.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.softMint,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('+8.4%', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Collected', style: TextStyle(color: AppColors.secondaryText, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Pending', style: TextStyle(color: AppColors.secondaryText, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Monthly Grouped Bar Chart
          SizedBox(
            height: 180,
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent))
                : BarChart(
                    BarChartData(
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => isDark ? AppColors.darkSurfaceVariant : Colors.white,
                          tooltipRoundedRadius: 8,
                          tooltipBorder: BorderSide(color: border, width: 1),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (groupIndex >= 0 && groupIndex < displayPoints.length) {
                              final pt = displayPoints[groupIndex];
                              return BarTooltipItem(
                                '${pt.month}\nCollected: ${formatRupee(pt.collected)}\nPending: ${formatRupee(pt.pending)}',
                                TextStyle(color: isDark ? Colors.white : AppColors.primaryText, fontSize: 11, fontWeight: FontWeight.w600),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: isDark ? AppColors.borderDark.withValues(alpha: 0.5) : AppColors.border.withValues(alpha: 0.7),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (val, meta) {
                              if (val == 0) return const SizedBox.shrink();
                              return Text(
                                '₹${(val / 1000).toInt()}k',
                                style: const TextStyle(color: AppColors.secondaryText, fontSize: 9, fontWeight: FontWeight.w600),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < displayPoints.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    displayPoints[idx].month,
                                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      maxY: maxY,
                      barGroups: displayPoints.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final pt = entry.value;

                        return BarChartGroupData(
                          x: idx,
                          barsSpace: 3,
                          barRods: [
                            // Collected bar
                            BarChartRodData(
                              toY: pt.collected,
                              color: const Color(0xFF2563EB),
                              width: 6,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                            // Pending bar
                            BarChartRodData(
                              toY: pt.pending,
                              color: const Color(0xFFF59E0B),
                              width: 6,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 4. STUDENTS BY CLASS DONUT CARD (Reference Screenshot Section 1.H)
/// ============================================================================
class StudentsByClassDonutCard extends StatefulWidget {
  final List<ClassEnrollmentPoint> points;
  final bool isLoading;

  const StudentsByClassDonutCard({
    super.key,
    required this.points,
    this.isLoading = false,
  });

  @override
  State<StudentsByClassDonutCard> createState() => _StudentsByClassDonutCardState();
}

class _StudentsByClassDonutCardState extends State<StudentsByClassDonutCard> {
  String _selectedFilter = 'All Classes';
  int _touchedSectionIndex = -1;

  static const List<Color> _palette = [
    Color(0xFF4F46E5), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
    Color(0xFFF97316), // Orange
    Color(0xFF14B8A6), // Teal
    Color(0xFF6366F1), // Purple
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.cardBackground;
    final border = isDark ? AppColors.borderDark : AppColors.border;

    var filtered = widget.points;
    if (_selectedFilter == 'Primary') {
      filtered = widget.points.where((p) {
        final num = int.tryParse(p.className.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return num >= 1 && num <= 5;
      }).toList();
    } else if (_selectedFilter == 'Middle') {
      filtered = widget.points.where((p) {
        final num = int.tryParse(p.className.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return num >= 6 && num <= 8;
      }).toList();
    } else if (_selectedFilter == 'Secondary') {
      filtered = widget.points.where((p) {
        final num = int.tryParse(p.className.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return num >= 9 && num <= 12;
      }).toList();
    }

    if (filtered.isEmpty) {
      filtered = widget.points;
    }

    final totalStudents = filtered.fold<int>(0, (prev, p) => prev + p.studentCount);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.softLavender,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.donut_large_rounded, color: Color(0xFF8B5CF6), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Students by Class',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.secondaryText),
                    style: TextStyle(
                      color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All Classes', child: Text('All Classes')),
                      DropdownMenuItem(value: 'Primary', child: Text('Primary (1–5)')),
                      DropdownMenuItem(value: 'Middle', child: Text('Middle (6–8)')),
                      DropdownMenuItem(value: 'Secondary', child: Text('Secondary (9–12)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Chart + Legend
          Row(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedSectionIndex = -1;
                                  return;
                                }
                                _touchedSectionIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 46,
                          sections: filtered.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final pt = entry.value;
                            final color = _palette[idx % _palette.length];
                            final isTouched = _touchedSectionIndex == idx;

                            return PieChartSectionData(
                              color: color,
                              value: pt.studentCount > 0 ? pt.studentCount.toDouble() : 1.0,
                              title: '',
                              radius: isTouched ? 22 : 18,
                            );
                          }).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$totalStudents',
                            style: AppTypography.displayMedium.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                            ),
                          ),
                          Text(
                            'Students',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.secondaryText,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Legend items list
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 180,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.take(6).length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final pt = filtered[idx];
                      final color = _palette[idx % _palette.length];

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(
                                pt.className,
                                style: TextStyle(
                                  color: isDark ? AppColors.coolGrayLight : AppColors.secondaryText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${pt.studentCount}',
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.primaryText,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 5. UPCOMING EVENTS CARD (Reference Screenshot Section 1.I)
/// ============================================================================
class UpcomingEventsCard extends StatelessWidget {
  final List<NoticeModel> notices;
  final bool isLoading;

  const UpcomingEventsCard({
    super.key,
    required this.notices,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.cardBackground;
    final border = isDark ? AppColors.borderDark : AppColors.border;

    final events = notices.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.softLavender,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_month_rounded, color: AppColors.primaryAccent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Upcoming Events',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => context.push('/notices'),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primaryAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_available_rounded, size: 32, color: AppColors.secondaryText.withValues(alpha: 0.5)),
                    const SizedBox(height: 8),
                    const Text('No upcoming events scheduled', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              separatorBuilder: (context, index) => Divider(height: 16, color: border),
              itemBuilder: (context, idx) {
                final e = events[idx];
                final colors = [
                  AppColors.softBlue,
                  AppColors.softMint,
                  AppColors.softAmber,
                  AppColors.softLavender,
                ];
                final iconColors = [
                  AppColors.primaryAccent,
                  AppColors.success,
                  AppColors.warning,
                  const Color(0xFF8B5CF6),
                ];
                final cardColor = colors[idx % colors.length];
                final iconColor = iconColors[idx % iconColors.length];

                return InkWell(
                  onTap: () => context.push('/notices'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('MMM').format(e.date).toUpperCase(),
                                style: TextStyle(color: iconColor, fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${e.date.day}',
                                style: TextStyle(color: iconColor, fontSize: 13, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormat('EEEE').format(e.date)} • ${e.category}',
                                style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.secondaryText),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 6. RECENT ACTIVITIES TIMELINE CARD (Reference Screenshot Section 1.J)
/// ============================================================================
class RecentActivitiesCard extends StatelessWidget {
  final List<ActivityLogModel> activities;
  final bool isLoading;

  const RecentActivitiesCard({
    super.key,
    required this.activities,
    this.isLoading = false,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes.clamp(1, 60)}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.cardBackground;
    final border = isDark ? AppColors.borderDark : AppColors.border;

    final items = activities.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.softBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history_rounded, color: AppColors.primaryAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Recent Activities',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => context.push('/activity-log'),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primaryAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.checklist_rounded, size: 32, color: AppColors.secondaryText.withValues(alpha: 0.5)),
                    const SizedBox(height: 8),
                    const Text('No recent campus activities logged', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, idx) {
                final a = items[idx];
                final isLast = idx == items.length - 1;

                return InkWell(
                  onTap: () => context.push('/activity-log'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vertical Timeline indicator
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 36,
                                color: isDark ? AppColors.borderDark : AppColors.border,
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.actionTitle,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                a.details,
                                style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(a.timestamp),
                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 7. BOTTOM QUICK ACTIONS CARD (Reference Screenshot Section 1.K)
/// ============================================================================
class SchoolOsQuickActionsCard extends StatelessWidget {
  const SchoolOsQuickActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.cardBackground;
    final border = isDark ? AppColors.borderDark : AppColors.border;

    final actions = [
      _ActionTileData(
        label: 'Add Student',
        icon: Icons.person_add_rounded,
        color: const Color(0xFF2563EB),
        bgColor: AppColors.softBlue,
        route: '/add-student',
      ),
      _ActionTileData(
        label: 'Add Teacher',
        icon: Icons.badge_rounded,
        color: const Color(0xFF8B5CF6),
        bgColor: AppColors.softLavender,
        route: '/add-teacher',
      ),
      _ActionTileData(
        label: 'Mark Attendance',
        icon: Icons.fact_check_rounded,
        color: AppColors.success,
        bgColor: AppColors.softMint,
        route: '/mark-attendance',
      ),
      _ActionTileData(
        label: 'Collect Fee',
        icon: Icons.payments_rounded,
        color: AppColors.warning,
        bgColor: AppColors.softAmber,
        route: '/fees',
      ),
      _ActionTileData(
        label: 'Create Notice',
        icon: Icons.campaign_rounded,
        color: const Color(0xFFEF4444),
        bgColor: const Color(0xFFFDE8E8),
        route: '/notices',
      ),
      _ActionTileData(
        label: 'Assign Homework',
        icon: Icons.assignment_rounded,
        color: const Color(0xFF4F46E5),
        bgColor: AppColors.softBlue,
        route: '/homework-create',
      ),
      _ActionTileData(
        label: 'Manage Classes',
        icon: Icons.meeting_room_rounded,
        color: const Color(0xFF0D9488),
        bgColor: AppColors.softMint,
        route: '/classes',
      ),
      _ActionTileData(
        label: 'Generate Report',
        icon: Icons.pie_chart_rounded,
        color: const Color(0xFF7C3AED),
        bgColor: AppColors.softLavender,
        route: '/reports',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.softAmber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, color: AppColors.warning, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Quick Actions',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 8 Action Tiles
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final isMedium = constraints.maxWidth >= 500;

              final crossAxisCount = isWide ? 8 : (isMedium ? 4 : 2);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isWide ? 1.05 : 1.25,
                ),
                itemBuilder: (context, idx) {
                  final action = actions[idx];

                  return Material(
                    color: isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5) : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      hoverColor: action.bgColor.withValues(alpha: 0.5),
                      onTap: () {
                        if (action.route.startsWith('/fees') || action.route.startsWith('/reports')) {
                          context.go(action.route);
                        } else {
                          context.push(action.route);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border, width: 0.8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: action.bgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(action.icon, color: action.color, size: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              action.label,
                              style: TextStyle(
                                color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTileData {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String route;

  const _ActionTileData({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.route,
  });
}
