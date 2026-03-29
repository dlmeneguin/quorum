import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/database/daos/transactions_dao.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';

class BalanceChart extends StatefulWidget {
  final List<MonthlyBalance> data;

  const BalanceChart({super.key, required this.data});

  @override
  State<BalanceChart> createState() => _BalanceChartState();
}

class _BalanceChartState extends State<BalanceChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;

    if (widget.data.isEmpty) return const SizedBox.shrink();

    final spots = widget.data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.balance);
    }).toList();

    final values = widget.data.map((d) => d.balance).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).abs();
    final padding = range < 1.0 ? 100.0 : range * 0.2;
    final minY = minVal - padding;
    final maxY = maxVal + padding;

    final displayIndex = _touchedIndex ?? (widget.data.length - 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Evolução do patrimônio',
                  style: AppTextStyles.sectionTitle(textPrimary)),
              const Spacer(),
              Text('6 meses',
                  style: AppTextStyles.label(textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                CurrencyUtils.format(widget.data[displayIndex].balance),
                style: AppTextStyles.splineSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _capitalize(
                    AppDateUtils.toMonthYear(widget.data[displayIndex].month)),
                style: AppTextStyles.label(textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (widget.data.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: range < 1.0 ? 50 : range / 3,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: borderColor,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      // intervalo exatamente 1 — um label por ponto
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        // Rejeita qualquer valor que não seja exatamente
                        // um inteiro correspondente a um ponto real
                        if ((value - index).abs() > 0.01) {
                          return const SizedBox.shrink();
                        }
                        if (index < 0 || index >= widget.data.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            AppDateUtils.toShortMonthYear(
                                widget.data[index].month),
                            style: AppTextStyles.dmSans(
                              fontSize: 10,
                              color: index == displayIndex
                                  ? AppColors.primary
                                  : textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.lineBarSpots == null ||
                          response.lineBarSpots!.isEmpty) {
                        _touchedIndex = null;
                        return;
                      }
                      _touchedIndex =
                          response.lineBarSpots!.first.spotIndex;
                    });
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    tooltipBorder: BorderSide(color: borderColor),
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              CurrencyUtils.format(s.y),
                              AppTextStyles.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    preventCurveOverShooting: true,
                    preventCurveOvershootingThreshold: 0,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        final isTouched = index == _touchedIndex;
                        final isLast =
                            index == widget.data.length - 1 &&
                                _touchedIndex == null;
                        final highlight = isTouched || isLast;
                        return FlDotCirclePainter(
                          radius: highlight ? 5 : 3,
                          color: highlight
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.6),
                          strokeWidth: highlight ? 2 : 0,
                          strokeColor: surfaceColor,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.15),
                          AppColors.primary.withOpacity(0.0),
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
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}