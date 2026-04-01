import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../dashboard/widgets/expenses_chart.dart';
import '../../dashboard/widgets/balance_chart.dart';
import '../../transactions/screens/transaction_form_screen.dart';
import '../providers/accounts_provider.dart';
import '../providers/account_detail_provider.dart';
import '../widgets/account_type_badge.dart';

class AccountDetailScreen extends ConsumerWidget {
  final Account account;

  const AccountDetailScreen({super.key, required this.account});

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

    final accountColor =
        account.color != null ? Color(account.color!) : AppColors.primary;

    final balanceAsync = ref.watch(accountBalanceProvider(account));
    final summaryAsync = ref.watch(accountMonthSummaryProvider(account));
    final expensesAsync =
        ref.watch(accountExpensesByCategoryProvider(account));
    final historyAsync =
        ref.watch(accountBalanceHistoryProvider(account));
    final transactionsAsync =
        ref.watch(accountTransactionsProvider(account));
    final goalsAsync = ref.watch(accountGoalsProvider(account));
    final selected = ref.watch(accountDetailMonthProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          account.name,
          style: AppTextStyles.sectionTitle(textPrimary),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: CustomScrollView(
        slivers: [
          // ── Header: saldo atual ──
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accountColor, accountColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AccountTypeBadge(type: account.type),
                      const Spacer(),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _iconForType(account.type),
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Saldo atual',
                    style: AppTextStyles.label(
                        Colors.white.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 6),
                  balanceAsync.when(
                    data: (balance) => Text(
                      CurrencyUtils.format(balance),
                      style:
                          AppTextStyles.dashboardNumber(Colors.white),
                    ),
                    loading: () => Text(
                      '...',
                      style: AppTextStyles.dashboardNumber(
                          Colors.white.withOpacity(0.5)),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                ],
              ),
            ),
          ),

          // ── Card: metas vinculadas a esta conta ──
          goalsAsync.when(
            data: (goals) {
              if (goals.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _LinkedGoalsCard(
                    goals: goals,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // ── Seletor de mês + resumo ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Text('Resumo do mês',
                      style: AppTextStyles.sectionTitle(textPrimary)),
                  const Spacer(),
                  _MonthSelector(selected: selected, ref: ref),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: summaryAsync.when(
              data: (summary) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: summary.balance >= 0
                            ? AppColors.success.withOpacity(0.08)
                            : AppColors.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: summary.balance >= 0
                              ? AppColors.success.withOpacity(0.3)
                              : AppColors.danger.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: summary.balance >= 0
                                  ? AppColors.success.withOpacity(0.15)
                                  : AppColors.danger.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              summary.balance >= 0
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              color: summary.balance >= 0
                                  ? AppColors.success
                                  : AppColors.danger,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Resultado do mês',
                                  style:
                                      AppTextStyles.label(textSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyUtils.formatSigned(summary.balance),
                                style: AppTextStyles.splineSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: summary.balance >= 0
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniSummaryCard(
                            label: 'Receitas',
                            value: summary.income,
                            icon: Icons.arrow_downward_rounded,
                            color: AppColors.success,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniSummaryCard(
                            label: 'Despesas',
                            value: summary.expense,
                            icon: Icons.arrow_upward_rounded,
                            color: AppColors.danger,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => const SizedBox.shrink(),
            ),
          ),

          // ── Line chart: evolução do saldo ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: historyAsync.when(
                data: (history) => history.isEmpty
                    ? const SizedBox.shrink()
                    : BalanceChart(data: history),
                loading: () => _LoadingCard(
                    surfaceColor: surfaceColor, borderColor: borderColor),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          // ── Donut chart: gastos por categoria ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: expensesAsync.when(
                data: (expenses) => ExpensesChart(expenses: expenses),
                loading: () => _LoadingCard(
                    surfaceColor: surfaceColor, borderColor: borderColor),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          // ── Histórico de transações ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Text('Transações do mês',
                  style: AppTextStyles.sectionTitle(textPrimary)),
            ),
          ),

          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 40, color: textSecondary),
                            const SizedBox(height: 12),
                            Text('Sem transações no período',
                                style: AppTextStyles.body(textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              final grouped = _groupByDate(transactions);
              final dates = grouped.keys.toList();

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final date = dates[index];
                      final items = grouped[date]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              _formatDateHeader(date),
                              style:
                                  AppTextStyles.bodyBold(textSecondary),
                            ),
                          ),
                          ...items.map((t) => _TransactionTile(
                                transaction: t,
                                surfaceColor: surfaceColor,
                                borderColor: borderColor,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TransactionFormScreen(
                                        transaction: t),
                                  ),
                                ),
                              )),
                        ],
                      );
                    },
                    childCount: dates.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
          ),
        ],
      ),
    );
  }

  Map<DateTime, List<Transaction>> _groupByDate(
      List<Transaction> transactions) {
    final Map<DateTime, List<Transaction>> grouped = {};
    for (final t in transactions) {
      final date = DateTime.fromMillisecondsSinceEpoch(t.date);
      final dateOnly = DateTime(date.year, date.month, date.day);
      grouped.putIfAbsent(dateOnly, () => []).add(t);
    }
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'Hoje';
    if (date == yesterday) return 'Ontem';
    return AppDateUtils.toDayMonthName(date);
  }

  IconData _iconForType(String type) => switch (type) {
        'checking' => Icons.account_balance_outlined,
        'savings' => Icons.savings_outlined,
        'cash' => Icons.wallet_outlined,
        'credit' => Icons.credit_card_outlined,
        _ => Icons.account_balance_wallet_outlined,
      };
}

// ── Card de metas vinculadas ──

class _LinkedGoalsCard extends StatelessWidget {
  final List<Goal> goals;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _LinkedGoalsCard({
    required this.goals,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final totalAllocated =
        goals.fold(0.0, (sum, g) => sum + g.currentAmount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
                Theme.of(context).brightness == Brightness.dark
                    ? 0.2
                    : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título + total alocado
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.savings_outlined,
                    size: 16, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dinheiro reservado em metas',
                  style: AppTextStyles.bodyBold(textPrimary),
                ),
              ),
              Text(
                CurrencyUtils.format(totalAllocated),
                style: AppTextStyles.splineSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Saldo alocado: este valor não aparece no seu total livre',
            style: AppTextStyles.label(textSecondary),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Lista de metas
          ...goals.map((goal) {
            final goalColor =
                goal.color != null ? Color(goal.color!) : AppColors.accent;
            final percentage = goal.targetAmount > 0
                ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
                : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: goalColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          goal.name,
                          style: AppTextStyles.body(textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (goal.status == 'paused')
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: textSecondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'pausada',
                            style: AppTextStyles.dmSans(
                              fontSize: 10,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      Text(
                        CurrencyUtils.format(goal.currentAmount),
                        style: AppTextStyles.bodyBold(goalColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 5,
                            backgroundColor:
                                goalColor.withOpacity(0.12),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(goalColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(percentage * 100).toStringAsFixed(0)}% de ${CurrencyUtils.format(goal.targetAmount)}',
                        style: AppTextStyles.label(textSecondary),
                      ),
                    ],
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

// ── Widgets internos ──

class _MonthSelector extends StatelessWidget {
  final DateTime selected;
  final WidgetRef ref;

  const _MonthSelector({required this.selected, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    final isCurrentMonth = () {
      final now = DateTime.now();
      return selected.year == now.year && selected.month == now.month;
    }();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            ref.read(accountDetailMonthProvider.notifier).state =
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
              Text('mês atual',
                  style: AppTextStyles.label(AppColors.primary)),
          ],
        ),
        IconButton(
          onPressed: isCurrentMonth
              ? null
              : () {
                  ref.read(accountDetailMonthProvider.notifier).state =
                      DateTime(selected.year, selected.month + 1);
                },
          icon: Icon(
            Icons.chevron_right,
            color: isCurrentMonth
                ? textSecondary.withOpacity(0.3)
                : textSecondary,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _MiniSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(label, style: AppTextStyles.label(textSecondary)),
          const SizedBox(height: 2),
          Text(
            CurrencyUtils.format(value),
            style: AppTextStyles.splineSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final Color surfaceColor;
  final Color borderColor;

  const _LoadingCard(
      {required this.surfaceColor, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.transaction,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final isTransfer = transaction.type == 'transfer';
    final isTransferIn = isTransfer &&
        transaction.transferPairId != null &&
        transaction.transferPairId! < transaction.id;
    final color = isTransfer
        ? AppColors.accent
        : isIncome
            ? AppColors.success
            : AppColors.danger;
    final isPositive = isIncome || isTransferIn;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isTransfer
                    ? (isTransferIn
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded)
                    : isIncome
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description ?? _defaultLabel(),
                    style: AppTextStyles.bodyBold(textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (transaction.paymentMethod != null)
                    Text(
                      transaction.paymentMethod!,
                      style: AppTextStyles.label(textSecondary),
                    ),
                ],
              ),
            ),
            Text(
              '${isPositive ? '+' : '-'} ${CurrencyUtils.format(transaction.amount)}',
              style: AppTextStyles.bodyBold(
                  isPositive ? AppColors.success : AppColors.danger),
            ),
          ],
        ),
      ),
    );
  }

  String _defaultLabel() => switch (transaction.type) {
        'income' => 'Receita',
        'expense' => 'Despesa',
        'transfer' => 'Transferência',
        _ => 'Transação',
      };
}