import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../providers/goals_provider.dart';
import '../widgets/goal_form_screen.dart';
import '../../../core/utils/balance_validator.dart';
import '../../../core/services/sync_service_provider.dart';

class GoalDetailScreen extends ConsumerWidget {
  final String goalId;
  final String goalName;

  const GoalDetailScreen({
    super.key,
    required this.goalId,
    required this.goalName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(goalByIdProvider(goalId));

    return goalAsync.when(
      data: (goal) {
        if (goal == null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => Navigator.of(context).pop());
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return _GoalDetailContent(goal: goal);
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(goalName),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Erro: $e'))),
    );
  }
}

class _GoalDetailContent extends ConsumerWidget {
  final Goal goal;

  const _GoalDetailContent({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;

    final contributionsAsync = ref.watch(contributionsProvider(goal.id));
    final goalColor =
        goal.color != null ? Color(goal.color!) : AppColors.accent;
    final percentage = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final isCompleted = goal.status == 'completed';

    // Conta vinculada e seu saldo disponível
    final accountsAsync = ref.watch(accountsProvider);
    final linkedAccount = accountsAsync.whenOrNull(
      data: (accounts) =>
          accounts.where((a) => a.id == goal.accountId).firstOrNull,
    );
    final accountBalanceAsync = linkedAccount != null
        ? ref.watch(accountBalanceProvider(linkedAccount))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          goal.name,
          style: AppTextStyles.sectionTitle(textPrimary),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => GoalFormScreen(goal: goal)),
            ),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar meta',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Card de progresso
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [goalColor, goalColor.withOpacity(0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progresso',
                            style: AppTextStyles.label(
                                Colors.white.withOpacity(0.8))),
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('✓ Concluída',
                                style: AppTextStyles.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                )),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      CurrencyUtils.format(goal.currentAmount),
                      style: AppTextStyles.splineSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'de ${CurrencyUtils.format(goal.targetAmount)}',
                      style: AppTextStyles.label(
                          Colors.white.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage,
                        minHeight: 10,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(percentage * 100).toStringAsFixed(0)}%',
                          style: AppTextStyles.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (goal.targetDate != null)
                          Text(
                            'Alvo: ${AppDateUtils.toMonthYear(DateTime.fromMillisecondsSinceEpoch(goal.targetDate!))}',
                            style: AppTextStyles.label(
                                Colors.white.withOpacity(0.8)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Card da conta vinculada com saldo disponível
          if (linkedAccount != null && accountBalanceAsync != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: accountBalanceAsync.when(
                  data: (balance) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_outlined,
                            size: 18, color: textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(linkedAccount.name,
                                  style:
                                      AppTextStyles.bodyBold(textPrimary)),
                              Text('Saldo disponível na conta',
                                  style:
                                      AppTextStyles.label(textSecondary)),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyUtils.format(balance),
                          style: AppTextStyles.bodyBold(
                            balance < 0
                                ? AppColors.danger
                                : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

          // Projeção de conclusão
          contributionsAsync.when(
            data: (contributions) {
              final projection = projectCompletionDate(
                  goal.currentAmount, goal.targetAmount, contributions);
              if (isCompleted || projection == null) {
                return const SliverToBoxAdapter(child: SizedBox());
              }
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: goalColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: goalColor.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.trending_up,
                            size: 18, color: goalColor),
                        const SizedBox(width: 10),
                        Text(
                          'Projeção: ${_capitalize(AppDateUtils.toMonthYear(projection))}',
                          style: AppTextStyles.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: goalColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () =>
                const SliverToBoxAdapter(child: SizedBox()),
            error: (_, __) =>
                const SliverToBoxAdapter(child: SizedBox()),
          ),

          // Botões contribuição e retirada
          if (!isCompleted)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _showContributionDialog(
                            context, ref, goal,
                            isWithdrawal: false),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Contribuir'),
                        style: FilledButton.styleFrom(
                          backgroundColor: goalColor,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    if (goal.currentAmount > 0) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showContributionDialog(
                              context, ref, goal,
                              isWithdrawal: true),
                          icon: Icon(Icons.remove,
                              size: 18, color: AppColors.danger),
                          label: Text('Retirar',
                              style: AppTextStyles.bodyBold(
                                  AppColors.danger)),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                                color: AppColors.danger),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Para metas concluídas, só mostra retirada
          if (isCompleted && goal.currentAmount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: OutlinedButton.icon(
                  onPressed: () => _showContributionDialog(
                      context, ref, goal,
                      isWithdrawal: true),
                  icon: Icon(Icons.remove,
                      size: 18, color: AppColors.danger),
                  label: Text('Retirar da meta',
                      style:
                          AppTextStyles.bodyBold(AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

          // Título do histórico
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text('Histórico',
                  style: AppTextStyles.sectionTitle(textPrimary)),
            ),
          ),

          // Lista de contribuições
          contributionsAsync.when(
            data: (contributions) {
              if (contributions.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Icon(Icons.savings_outlined,
                              size: 40, color: textSecondary),
                          const SizedBox(height: 12),
                          Text('Nenhuma movimentação ainda',
                              style: AppTextStyles.body(textSecondary)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final c = contributions[index];
                      final date =
                          DateTime.fromMillisecondsSinceEpoch(c.date);
                      final isWithdrawal = c.amount < 0;
                      final entryColor = isWithdrawal
                          ? AppColors.danger
                          : goalColor;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: entryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isWithdrawal
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                color: entryColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.note ??
                                        (isWithdrawal
                                            ? 'Retirada'
                                            : 'Contribuição'),
                                    style: AppTextStyles.bodyBold(
                                        textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    AppDateUtils.toFullDate(date),
                                    style: AppTextStyles.label(
                                        textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isWithdrawal ? '-' : '+'}${CurrencyUtils.format(c.amount.abs())}',
                              style:
                                  AppTextStyles.bodyBold(entryColor),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: contributions.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Text('Erro: $e'))),
          ),
        ],
      ),
    );
  }

  void _showContributionDialog(
    BuildContext context,
    WidgetRef ref,
    Goal goal, {
    required bool isWithdrawal,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final goalColor =
        goal.color != null ? Color(goal.color!) : AppColors.accent;
    final dialogColor = isWithdrawal ? AppColors.danger : goalColor;

    final amountController = TextEditingController();
    final noteController = TextEditingController();
    int amountCents = 0;
    DateTime selectedDate = DateTime.now();
    String? errorMessage;

    String formatCents(int cents) =>
        (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Saldo disponível para contribuição (conta) ou retirada (meta)
          final accountsAsync = ref.watch(accountsProvider);
          final linkedAccount = accountsAsync.whenOrNull(
            data: (accounts) => accounts
                .where((a) => a.id == goal.accountId)
                .firstOrNull,
          );
          final availableBalanceAsync = linkedAccount != null && !isWithdrawal
              ? ref.watch(accountBalanceProvider(linkedAccount))
              : null;

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isWithdrawal ? 'Retirar da meta' : 'Nova contribuição',
                    style: AppTextStyles.sectionTitle(textPrimary),
                  ),
                  const SizedBox(height: 8),

                  // Saldo disponível
                  if (isWithdrawal)
                    _BalanceInfo(
                      label: 'Disponível na meta',
                      value: goal.currentAmount,
                      color: dialogColor,
                    )
                  else if (availableBalanceAsync != null)
                    availableBalanceAsync.whenOrNull(
                      data: (balance) => _BalanceInfo(
                        label: 'Disponível na conta',
                        value: balance,
                        color: balance <= 0
                            ? AppColors.danger
                            : dialogColor,
                      ),
                    ) ?? const SizedBox.shrink()
                  else
                    const SizedBox.shrink(),

                  const SizedBox(height: 16),

                  // Valor
                  Text('Valor',
                      style: AppTextStyles.label(textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    onChanged: (input) {
                      final digits =
                          input.replaceAll(RegExp(r'[^0-9]'), '');
                      amountCents = int.tryParse(digits) ?? 0;
                      final formatted = formatCents(amountCents);
                      amountController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                            offset: formatted.length),
                      );

                      // Valida limites
                      final amount = amountCents / 100;
                      if (isWithdrawal && amount > goal.currentAmount) {
                        errorMessage =
                            'Valor maior que o saldo da meta (${CurrencyUtils.format(goal.currentAmount)})';
                      } else {
                        errorMessage = null;
                      }
                      setDialogState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: '0,00',
                      prefixIcon: Padding(
                        padding:
                            const EdgeInsets.only(left: 16, right: 8),
                        child: Text('R\$',
                            style: AppTextStyles.bodyBold(dialogColor)),
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 0, minHeight: 0),
                      errorText: errorMessage,
                    ),
                    style: AppTextStyles.splineSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: dialogColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Data
                  Text('Data',
                      style: AppTextStyles.label(textSecondary)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        locale: const Locale('pt', 'BR'),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 16, color: textSecondary),
                          const SizedBox(width: 10),
                          Text(AppDateUtils.toFullDate(selectedDate),
                              style: AppTextStyles.body(textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Observação
                  Text('Observação (opcional)',
                      style: AppTextStyles.label(textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      hintText: isWithdrawal
                          ? 'Ex: Usar para viagem...'
                          : 'Ex: Bônus do trabalho...',
                    ),
                    style: AppTextStyles.body(textPrimary),
                  ),
                  const SizedBox(height: 24),

                  // Botões
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: amountCents <= 0 || errorMessage != null
                              ? null
                              : () async {
                                  final db = ref.read(databaseProvider);
                                  final amount = amountCents / 100;

                                  if (!isWithdrawal) {
                                    // Valida saldo disponível na conta antes de contribuir
                                    final error =
                                        await BalanceValidator.checkSufficientBalance(
                                      db: db,
                                      accountId: goal.accountId!,
                                      amount: amount,
                                    );
                                    if (error != null) {
                                      setDialogState(() => errorMessage = error);
                                      return;
                                    }
                                    await addContributionAndUpdate(
                                      db: db,
                                      goal: goal,
                                      amount: amount,
                                      date: selectedDate,
                                      note: noteController.text,
                                    );
                                  } else {
                                    await withdrawFromGoal(
                                      db: db,
                                      goal: goal,
                                      amount: amount,
                                      date: selectedDate,
                                      note: noteController.text,
                                    );
                                  }

                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  ref.read(syncServiceProvider).scheduleUpload();
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: dialogColor,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text('Confirmar',
                              style:
                                  AppTextStyles.bodyBold(Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// Widget auxiliar para exibir saldo disponível no dialog
class _BalanceInfo extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _BalanceInfo({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.dmSans(fontSize: 12, color: color)),
          Text(
            CurrencyUtils.format(value),
            style: AppTextStyles.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}