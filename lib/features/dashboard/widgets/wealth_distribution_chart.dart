import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/currency.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../core/models/wealth_slice.dart';

class WealthDistributionChart extends StatefulWidget {
  final List<WealthSlice> slices;

  const WealthDistributionChart({super.key, required this.slices});

  @override
  State<WealthDistributionChart> createState() =>
      _WealthDistributionChartState();
}

class _WealthDistributionChartState
    extends State<WealthDistributionChart> {
  int _touchedIndex = -1;

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

    if (widget.slices.isEmpty) return const SizedBox.shrink();

    final total =
        widget.slices.fold(0.0, (sum, s) => sum + s.value);

    final touched = _touchedIndex >= 0 && _touchedIndex < widget.slices.length
        ? widget.slices[_touchedIndex]
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
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
          Text('Distribuição do patrimônio',
              style: AppTextStyles.sectionTitle(textPrimary)),
          const SizedBox(height: 20),
          Row(
            children: [
              // Donut
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = response
                              .touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: widget.slices
                        .asMap()
                        .entries
                        .map((entry) {
                      final i = entry.key;
                      final slice = entry.value;
                      final isTouched = i == _touchedIndex;
                      final pct = slice.value / total * 100;

                      return PieChartSectionData(
                        color: Color(slice.color),
                        value: slice.value,
                        title: '${pct.toStringAsFixed(0)}%',
                        radius: isTouched ? 36 : 28,
                        titleStyle: AppTextStyles.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Centro: valor tocado ou total
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (touched != null) ...[
                      Text(
                        touched.label,
                        style: AppTextStyles.bodyBold(textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyUtils.format(touched.value),
                        style: AppTextStyles.splineSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(touched.color),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(touched.value / total * 100).toStringAsFixed(1)}% do total',
                        style: AppTextStyles.label(textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: touched.isGoal
                              ? AppColors.accent.withOpacity(0.12)
                              : AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          touched.isGoal ? 'Meta' : 'Conta',
                          style: AppTextStyles.label(
                            touched.isGoal
                                ? AppColors.accent
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ] else ...[
                      Text('Total',
                          style: AppTextStyles.label(textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyUtils.format(total),
                        style: AppTextStyles.splineSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toque em uma fatia\npara ver detalhes',
                        style: AppTextStyles.label(textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Legenda
          ...widget.slices.map((slice) {
            final pct = slice.value / total * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(slice.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (slice.isGoal)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('META',
                          style: AppTextStyles.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          )),
                    ),
                  Expanded(
                    child: Text(
                      slice.label,
                      style: AppTextStyles.label(textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: AppTextStyles.label(textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyUtils.format(slice.value),
                    style: AppTextStyles.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}