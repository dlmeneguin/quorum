import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../core/utils/currency.dart';
import '../../../core/models/category_expense.dart';

class ExpensesChart extends StatefulWidget {
  final List<CategoryExpense> expenses;

  const ExpensesChart({super.key, required this.expenses});

  @override
  State<ExpensesChart> createState() => _ExpensesChartState();
}

class _ExpensesChartState extends State<ExpensesChart> {
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

    if (widget.expenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.pie_chart_outline,
                  size: 40, color: textSecondary),
              const SizedBox(height: 12),
              Text('Sem gastos no período',
                  style: AppTextStyles.body(textSecondary)),
            ],
          ),
        ),
      );
    }

    final total =
        widget.expenses.fold(0.0, (sum, e) => sum + e.total);

    final touched = _touchedIndex >= 0 &&
            _touchedIndex < widget.expenses.length
        ? widget.expenses[_touchedIndex]
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
          Text('Gastos por categoria',
              style: AppTextStyles.sectionTitle(textPrimary)),
          const SizedBox(height: 20),

          // ── Donut + painel lateral ──
          Row(
            children: [
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
                    sections: widget.expenses
                        .asMap()
                        .entries
                        .map((entry) {
                      final i = entry.key;
                      final expense = entry.value;
                      final isTouched = i == _touchedIndex;

                      return PieChartSectionData(
                        color: Color(expense.categoryColor),
                        value: expense.total,
                        title: '',
                        radius: isTouched ? 36 : 28,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Painel lateral — mesma lógica do WealthDistributionChart
              Expanded(
                child: touched != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(touched.categoryName,
                              style: AppTextStyles.bodyBold(textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyUtils.format(touched.total),
                            style: AppTextStyles.splineSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(touched.categoryColor),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(touched.total / total * 100).toStringAsFixed(1)}% do total',
                            style: AppTextStyles.label(textSecondary),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
                      ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Legenda completa ──
          ...widget.expenses.map((expense) {
            final pct = expense.total / total * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(expense.categoryColor),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      expense.categoryName,
                      style: AppTextStyles.body(textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: AppTextStyles.label(textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    CurrencyUtils.format(expense.total),
                    style: AppTextStyles.dmSans(
                      fontSize: 13,
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