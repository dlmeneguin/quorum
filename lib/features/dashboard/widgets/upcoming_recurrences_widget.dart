import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';

class UpcomingRecurrencesWidget extends StatefulWidget {
  final Map<DateTime, List<Transaction>> data;

  const UpcomingRecurrencesWidget({super.key, required this.data});

  @override
  State<UpcomingRecurrencesWidget> createState() =>
      _UpcomingRecurrencesWidgetState();
}

class _UpcomingRecurrencesWidgetState
    extends State<UpcomingRecurrencesWidget> {
  late List<DateTime> _months;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _months = widget.data.keys.toList()..sort();
    _selectedIndex = 0;
  }

  @override
  void didUpdateWidget(UpcomingRecurrencesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _months = widget.data.keys.toList()..sort();
      // Mantém o índice se ainda válido
      if (_selectedIndex >= _months.length) {
        _selectedIndex = 0;
      }
    }
  }

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

    if (_months.isEmpty) return const SizedBox.shrink();

    final selectedMonth = _months[_selectedIndex];
    final items = widget.data[selectedMonth] ?? [];
    final monthTotal = items.fold(0.0, (sum, t) {
      return t.type == 'income' ? sum + t.amount : sum - t.amount;
    });

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
          // Título + total do mês
          Row(
            children: [
              Text('Próximos lançamentos',
                  style: AppTextStyles.sectionTitle(textPrimary)),
              const Spacer(),
              Text(
                CurrencyUtils.formatSigned(monthTotal),
                style: AppTextStyles.bodyBold(
                  monthTotal >= 0 ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Seletor de mês horizontal
          SizedBox(
            height: 36,
            child: Row(
              children: [
                // Seta esquerda
                _NavArrow(
                  icon: Icons.chevron_left,
                  enabled: _selectedIndex > 0,
                  onTap: () =>
                      setState(() => _selectedIndex--),
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                // Botões de mês com scroll
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _months.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final isSelected = index == _selectedIndex;
                      final month = _months[index];
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _shortMonth(month),
                            style: AppTextStyles.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                // Seta direita
                _NavArrow(
                  icon: Icons.chevron_right,
                  enabled: _selectedIndex < _months.length - 1,
                  onTap: () =>
                      setState(() => _selectedIndex++),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Lista de itens do mês selecionado
          if (items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nenhum lançamento neste mês',
                  style: AppTextStyles.body(textSecondary),
                ),
              ),
            )
          else
            ...items.map((t) => _RecurrenceItem(
                  transaction: t,
                  surfaceColor: isDark
                      ? AppColors.backgroundDark
                      : AppColors.backgroundLight,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                )),
        ],
      ),
    );
  }

  // "abr/26" — curto e limpo para os botões
  String _shortMonth(DateTime date) {
    return AppDateUtils.toShortMonthYear(date);
  }
}

// Botão de seta de navegação
class _NavArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool isDark;

  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
        : (isDark
            ? AppColors.textSecondaryDark.withOpacity(0.2)
            : AppColors.textSecondaryLight.withOpacity(0.2));

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withOpacity(0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _RecurrenceItem extends StatelessWidget {
  final Transaction transaction;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _RecurrenceItem({
    required this.transaction,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final color = isIncome ? AppColors.success : AppColors.danger;
    final date = DateTime.fromMillisecondsSinceEpoch(transaction.date);

    final isInstallment = transaction.installmentTotal != null;
    final badgeLabel = isInstallment
        ? '${transaction.installmentCurrent}/${transaction.installmentTotal}'
        : '↺';
    final badgeColor =
        isInstallment ? const Color(0xFF6366F1) : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description ?? _defaultLabel(transaction.type),
                  style: AppTextStyles.bodyBold(textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      AppDateUtils.toDayMonth(date),
                      style: AppTextStyles.label(textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeLabel,
                        style: AppTextStyles.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'} ${CurrencyUtils.format(transaction.amount)}',
            style: AppTextStyles.bodyBold(color),
          ),
        ],
      ),
    );
  }

  String _defaultLabel(String type) => switch (type) {
        'income' => 'Receita',
        'expense' => 'Despesa',
        _ => 'Transação',
      };
}