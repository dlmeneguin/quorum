import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../providers/goals_provider.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_form_screen.dart';
import 'goal_detail_screen.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Text(
                'Metas',
                style: AppTextStyles.splineSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ),
          ),

          goalsAsync.when(
            data: (goals) {
              final active =
                  goals.where((g) => g.status == 'active').toList();
              final paused =
                  goals.where((g) => g.status == 'paused').toList();
              final completed =
                  goals.where((g) => g.status == 'completed').toList();

              if (goals.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_outlined,
                            size: 48, color: textSecondary),
                        const SizedBox(height: 16),
                        Text('Nenhuma meta criada',
                            style: AppTextStyles.body(textSecondary)),
                        const SizedBox(height: 8),
                        Text('Toque em + para criar a primeira',
                            style: AppTextStyles.label(textSecondary)),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Seção Ativas
                    if (active.isNotEmpty) ...[
                      _SectionHeader(
                          label: 'Em andamento',
                          count: active.length,
                          color: AppColors.accent,
                          textSecondary: textSecondary),
                      const SizedBox(height: 8),
                      ...active.map((g) => GoalCard(
                            goal: g,
                            onTap: () => _openDetail(context, g),
                            onEdit: () => _openForm(context, g),
                            onDelete: () =>
                                _confirmDelete(context, ref, g.id),
                            onTogglePause: () =>
                                _togglePause(ref, g),
                          )),
                      const SizedBox(height: 8),
                    ],

                    // Seção Pausadas
                    if (paused.isNotEmpty) ...[
                      _SectionHeader(
                          label: 'Pausadas',
                          count: paused.length,
                          color: textSecondary,
                          textSecondary: textSecondary),
                      const SizedBox(height: 8),
                      ...paused.map((g) => GoalCard(
                            goal: g,
                            onTap: () => _openDetail(context, g),
                            onEdit: () => _openForm(context, g),
                            onDelete: () =>
                                _confirmDelete(context, ref, g.id),
                            onTogglePause: () =>
                                _togglePause(ref, g),
                          )),
                      const SizedBox(height: 8),
                    ],

                    // Seção Concluídas
                    if (completed.isNotEmpty) ...[
                      _SectionHeader(
                          label: 'Concluídas',
                          count: completed.length,
                          color: AppColors.success,
                          textSecondary: textSecondary),
                      const SizedBox(height: 8),
                      ...completed.map((g) => GoalCard(
                            goal: g,
                            onTap: () => _openDetail(context, g),
                            onEdit: () => _openForm(context, g),
                            onDelete: () =>
                                _confirmDelete(context, ref, g.id),
                          )),
                    ],
                  ]),
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
        onPressed: () => _openForm(context, null),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Nova meta',
          style: AppTextStyles.bodyBold(Colors.white),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, Goal goal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoalDetailScreen(
          goalId: goal.id,
          goalName: goal.name,
        ),
      ),
    );
  }

  void _openForm(BuildContext context, Goal? goal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoalFormScreen(goal: goal),
      ),
    );
  }

  Future<void> _togglePause(WidgetRef ref, Goal goal) async {
    final db = ref.read(databaseProvider);
    final newStatus = goal.status == 'paused' ? 'active' : 'paused';
    await db.goalsDao.updateGoal(
      GoalsCompanion(
        id: Value(goal.id),
        name: Value(goal.name),
        targetAmount: Value(goal.targetAmount),
        currentAmount: Value(goal.currentAmount),
        status: Value(newStatus),
        targetDate: Value(goal.targetDate),
        accountId: Value(goal.accountId),
        color: Value(goal.color),
        icon: Value(goal.icon),
        createdAt: Value(goal.createdAt),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir meta'),
        content: const Text(
            'Tem certeza? O histórico de contribuições também será removido.'),
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
      await db.goalsDao.deleteGoal(id);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color textSecondary;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${label.toUpperCase()} ($count)',
          style: AppTextStyles.label(textSecondary),
        ),
      ],
    );
  }
}