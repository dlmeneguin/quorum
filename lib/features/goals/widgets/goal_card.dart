import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';

class GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTogglePause; // null para metas concluídas

  const GoalCard({
    super.key,
    required this.goal,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onTogglePause,
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

    final goalColor =
        goal.color != null ? Color(goal.color!) : AppColors.accent;

    final percentage = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;

    final isCompleted = goal.status == 'completed';
    final isPaused = goal.status == 'paused';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? AppColors.success.withOpacity(0.4)
                : isPaused
                    ? borderColor
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
          children: [
            // Faixa colorida no topo
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.success
                    : isPaused
                        ? textSecondary.withOpacity(0.4)
                        : goalColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha 1: nome + badges + menu
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                goal.name,
                                style: AppTextStyles.bodyBold(textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isCompleted)
                              _StatusBadge(
                                label: 'Concluída',
                                color: AppColors.success,
                              )
                            else if (isPaused)
                              _StatusBadge(
                                label: 'Pausada',
                                color: textSecondary,
                              ),
                          ],
                        ),
                      ),
                      // Botão de exclusão rápida para concluídas
                      if (isCompleted)
                        IconButton(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: AppColors.danger),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Excluir meta',
                        )
                      else
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              size: 18, color: textSecondary),
                          onSelected: (value) {
                            if (value == 'edit') onEdit();
                            if (value == 'delete') onDelete();
                            if (value == 'toggle' && onTogglePause != null) {
                              onTogglePause!();
                            }
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
                            PopupMenuItem(
                              value: 'toggle',
                              child: Row(
                                children: [
                                  Icon(
                                    isPaused
                                        ? Icons.play_arrow_outlined
                                        : Icons.pause_outlined,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(isPaused ? 'Reativar' : 'Pausar'),
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
                                      style:
                                          TextStyle(color: AppColors.danger)),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Linha 2: valor atual / alvo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        CurrencyUtils.format(goal.currentAmount),
                        style: AppTextStyles.splineSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isCompleted ? AppColors.success : textPrimary,
                        ),
                      ),
                      Text(
                        'de ${CurrencyUtils.format(goal.targetAmount)}',
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
                      backgroundColor: (isCompleted
                              ? AppColors.success
                              : isPaused
                                  ? textSecondary
                                  : goalColor)
                          .withOpacity(isDark ? 0.15 : 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCompleted
                            ? AppColors.success
                            : isPaused
                                ? textSecondary.withOpacity(0.6)
                                : goalColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Linha 3: percentual + data alvo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(percentage * 100).toStringAsFixed(0)}%',
                        style: AppTextStyles.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? AppColors.success
                              : isPaused
                                  ? textSecondary
                                  : goalColor,
                        ),
                      ),
                      if (goal.targetDate != null)
                        Text(
                          isCompleted
                              ? '✓ Concluída'
                              : 'Alvo: ${AppDateUtils.toMonthYear(DateTime.fromMillisecondsSinceEpoch(goal.targetDate!))}',
                          style: AppTextStyles.label(
                            isCompleted ? AppColors.success : textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.label(color),
      ),
    );
  }
}