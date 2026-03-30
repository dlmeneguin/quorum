import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/currency.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../dashboard/widgets/month_selector.dart';
import '../providers/budget_provider.dart';
import '../widgets/budget_card.dart';
import '../widgets/budget_form_dialog.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final selected = ref.watch(selectedMonthProvider);
    final budgetsAsync = ref.watch(budgetWithSpendingProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Row(
                children: [
                  Text(
                    'Orçamento',
                    style: AppTextStyles.splineSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  const MonthSelector(),
                ],
              ),
            ),
          ),

          // Resumo total do mês
          budgetsAsync.when(
            data: (budgets) {
              if (budgets.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

              final totalLimit = budgets.fold(
                  0.0, (sum, b) => sum + b.budget.limitAmount);
              final totalSpent =
                  budgets.fold(0.0, (sum, b) => sum + b.spent);
              final overCount =
                  budgets.where((b) => b.isOver).length;
              final warningCount =
                  budgets.where((b) => b.isWarning).length;

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumo do mês',
                          style: AppTextStyles.label(
                              Colors.white.withOpacity(0.8)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryItem(
                                label: 'Gasto',
                                value: CurrencyUtils.format(totalSpent),
                                valueColor: totalSpent > totalLimit
                                    ? AppColors.danger
                                    : Colors.white,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            Expanded(
                              child: _SummaryItem(
                                label: 'Limite total',
                                value:
                                    CurrencyUtils.format(totalLimit),
                                valueColor: Colors.white,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            Expanded(
                              child: _SummaryItem(
                                label: 'Disponível',
                                value: CurrencyUtils.format(
                                    (totalLimit - totalSpent)
                                        .clamp(0, double.infinity)),
                                valueColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (overCount > 0 || warningCount > 0) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (overCount > 0)
                                _AlertBadge(
                                  icon: Icons.cancel_outlined,
                                  label:
                                      '$overCount excedido${overCount > 1 ? 's' : ''}',
                                  color: AppColors.danger,
                                ),
                              if (warningCount > 0)
                                _AlertBadge(
                                  icon: Icons.warning_amber_rounded,
                                  label:
                                      '$warningCount em alerta',
                                  color: AppColors.accent,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
          ),

          // Lista de orçamentos
          budgetsAsync.when(
            data: (budgets) {
              if (budgets.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pie_chart_outline,
                            size: 48, color: textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum orçamento definido',
                          style: AppTextStyles.body(textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Toque em + para criar o primeiro',
                          style: AppTextStyles.label(textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = budgets[index];
                      return BudgetCard(
                        item: item,
                        onEdit: () => _openForm(context, ref,
                            selected, budget: item.budget),
                        onDelete: () =>
                            _confirmDelete(context, ref, item.budget.id),
                      );
                    },
                    childCount: budgets.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Erro: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref, selected),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Novo orçamento',
          style: AppTextStyles.bodyBold(Colors.white),
        ),
      ),
    );
  }

  void _openForm(
    BuildContext context,
    WidgetRef ref,
    DateTime selected, {
    Budget? budget,
  }) {
    showDialog(
      context: context,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: BudgetFormDialog(
          budget: budget,
          year: selected.year,
          month: selected.month,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir orçamento'),
        content: const Text(
            'Tem certeza? O histórico de gastos não será afetado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.budgetsDao.deleteBudget(id);
    }
  }
}

// Widgets auxiliares internos

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.dmSans(
            fontSize: 11,
            color: Colors.white.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AlertBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _AlertBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}