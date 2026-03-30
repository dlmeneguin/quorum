import 'package:flutter/material.dart';
import '../../../core/utils/currency.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../providers/budget_provider.dart';

class BudgetCard extends StatelessWidget {
  final BudgetWithSpending item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const BudgetCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;

    final categoryColor = Color(item.categoryColor);
    final percentage = item.percentage.clamp(0.0, 1.0);

    final Color progressColor;
    final Widget? statusIcon;

    if (item.isOver) {
      progressColor = AppColors.danger;
      statusIcon = const Icon(Icons.cancel_outlined,
          size: 16, color: AppColors.danger);
    } else if (item.isWarning) {
      progressColor = AppColors.accent;
      statusIcon = const Icon(Icons.warning_amber_rounded,
          size: 16, color: AppColors.accent);
    } else {
      progressColor = AppColors.success;
      statusIcon = null;
    }

    final remaining = item.budget.limitAmount - item.spent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isOver
              ? AppColors.danger.withOpacity(0.4)
              : item.isWarning
                  ? AppColors.accent.withOpacity(0.4)
                  : borderColor,
        ),
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
          // Linha 1: ícone de cor + nome + status + menu
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.categoryName,
                  style: AppTextStyles.bodyBold(textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (statusIcon != null) ...[
                statusIcon,
                const SizedBox(width: 6),
              ],
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: textSecondary),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 16, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text('Excluir',
                            style: TextStyle(color: AppColors.danger)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linha 2: gasto / limite
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyUtils.format(item.spent),
                style: AppTextStyles.splineSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: item.isOver ? AppColors.danger : textPrimary,
                ),
              ),
              Text(
                'de ${CurrencyUtils.format(item.budget.limitAmount)}',
                style: AppTextStyles.label(textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Barra de progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor:
                  progressColor.withOpacity(isDark ? 0.15 : 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 8),

          // Linha 3: percentual + restante/excedente
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(item.percentage * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                ),
              ),
              Text(
                item.isOver
                    ? 'Excedido em ${CurrencyUtils.format(item.spent - item.budget.limitAmount)}'
                    : 'Restam ${CurrencyUtils.format(remaining)}',
                style: AppTextStyles.label(
                  item.isOver ? AppColors.danger : textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}