import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../providers/dashboard_provider.dart';

class MonthSelector extends ConsumerWidget {
  const MonthSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMonthProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final isCurrentMonth = () {
      final now = DateTime.now();
      return selected.year == now.year && selected.month == now.month;
    }();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            ref.read(selectedMonthProvider.notifier).state =
                DateTime(selected.year, selected.month - 1);
          },
          icon: Icon(Icons.chevron_left, color: textSecondary),
          visualDensity: VisualDensity.compact,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppDateUtils.toMonthYear(selected),
              style: AppTextStyles.bodyBold(textPrimary),
            ),
            if (isCurrentMonth)
              Text(
                'mês atual',
                style: AppTextStyles.label(AppColors.primary),
              ),
          ],
        ),
        IconButton(
          onPressed: isCurrentMonth
              ? null
              : () {
                  ref.read(selectedMonthProvider.notifier).state =
                      DateTime(selected.year, selected.month + 1);
                },
          icon: Icon(
            Icons.chevron_right,
            color: isCurrentMonth ? textSecondary.withOpacity(0.3) : textSecondary,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}