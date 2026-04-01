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
          Row(
            children: [
              // Donut com info central ao toque
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
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
                        centerSpaceRadius: 44,
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
                            radius: isTouched ? 34 : 26,
                          );
                        }).toList(),
                      ),
                    ),
                    // Info central: percentual quando tocado, total geral quando não
                    touched != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(touched.total / total * 100).toStringAsFixed(0)}%',
                                style: AppTextStyles.splineSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(touched.categoryColor),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'total',
                                style: AppTextStyles.label(textSecondary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyUtils.formatCompact(total),
                                style: AppTextStyles.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Legenda: mostra detalhes da fatia tocada ou lista resumida
              Expanded(
                child: touched != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Color(touched.categoryColor),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  touched.categoryName,
                                  style:
                                      AppTextStyles.bodyBold(textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            CurrencyUtils.format(touched.total),
                            style: AppTextStyles.splineSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(touched.categoryColor),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(touched.total / total * 100).toStringAsFixed(1)}% do total',
                            style: AppTextStyles.label(textSecondary),
                          ),
                        ],
                      )
                    : Column(
                        children: widget.expenses.take(5).map((expense) {
                          final percentage =
                              expense.total / total * 100;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
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
                                    style: AppTextStyles.label(
                                        textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${percentage.toStringAsFixed(0)}%',
                                  style: AppTextStyles.label(textPrimary),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // Lista detalhada completa
          ...widget.expenses.map((expense) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(expense.categoryColor),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(expense.categoryName,
                          style: AppTextStyles.body(textPrimary)),
                    ),
                    Text(
                      CurrencyUtils.format(expense.total),
                      style: AppTextStyles.bodyBold(textPrimary),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}