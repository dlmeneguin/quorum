import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../features/accounts/providers/accounts_provider.dart';
import '../../../features/accounts/screens/accounts_screen.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/month_selector.dart';
import '../widgets/summary_card.dart';
import '../widgets/expenses_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

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

    final accountsAsync = ref.watch(accountsProvider);
    final summaryAsync = ref.watch(monthSummaryProvider);
    final expensesAsync = ref.watch(expensesByCategoryProvider);
    final now = DateTime.now();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header com saudação e saldo total
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(),
                              style: AppTextStyles.label(
                                  Colors.white.withOpacity(0.8)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppDateUtils.toFullDate(now),
                              style: AppTextStyles.label(
                                  Colors.white.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ),
                      // Botão de contas
                      IconButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AccountsScreen(),
                          ),
                        ),
                        icon: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white,
                        ),
                        tooltip: 'Gerenciar contas',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Patrimônio total',
                    style: AppTextStyles.label(
                        Colors.white.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 6),
                  accountsAsync.when(
                    data: (accounts) {
                      final total = accounts.fold(
                          0.0, (sum, a) => sum + a.initialBalance);
                      return Text(
                        CurrencyUtils.format(total),
                        style: AppTextStyles.dashboardNumber(
                            Colors.white),
                      );
                    },
                    loading: () => Text(
                      'Carregando...',
                      style: AppTextStyles.dashboardNumber(
                          Colors.white.withOpacity(0.5)),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // Seletor de mês
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Text('Resumo do mês',
                      style: AppTextStyles.sectionTitle(textPrimary)),
                  const Spacer(),
                  const MonthSelector(),
                ],
              ),
            ),
          ),

          // Cards de resumo
          SliverToBoxAdapter(
            child: summaryAsync.when(
              data: (summary) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  children: [
                    // Resultado do mês — card maior
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
                              Text(
                                'Resultado do mês',
                                style:
                                    AppTextStyles.label(textSecondary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyUtils.formatSigned(
                                    summary.balance),
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
                    // Receitas e despesas lado a lado
                    Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            label: 'Receitas',
                            value: summary.income,
                            icon: Icons.arrow_downward_rounded,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SummaryCard(
                            label: 'Despesas',
                            value: summary.expense,
                            icon: Icons.arrow_upward_rounded,
                            color: AppColors.danger,
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
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erro: $e'),
              ),
            ),
          ),

          // Chart de gastos por categoria
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: expensesAsync.when(
                data: (expenses) =>
                    ExpensesChart(expenses: expenses),
                loading: () => Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: const Center(
                      child: CircularProgressIndicator()),
                ),
                error: (e, _) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Contas rápidas
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Text('Suas contas',
                      style: AppTextStyles.sectionTitle(textPrimary)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AccountsScreen(),
                      ),
                    ),
                    child: Text('Ver todas',
                        style: AppTextStyles.label(AppColors.primary)),
                  ),
                ],
              ),
            ),
          ),

          accountsAsync.when(
            data: (accounts) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final account = accounts[index];
                    final accountColor = account.color != null
                        ? Color(account.color!)
                        : AppColors.primary;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
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
                              color: accountColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.account_balance_outlined,
                              color: accountColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              account.name,
                              style: AppTextStyles.body(textPrimary),
                            ),
                          ),
                          Text(
                            CurrencyUtils.format(
                                account.initialBalance),
                            style:
                                AppTextStyles.bodyBold(textPrimary),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: accounts.length,
                ),
              ),
            ),
            loading: () => const SliverToBoxAdapter(child: SizedBox()),
            error: (_, __) =>
                const SliverToBoxAdapter(child: SizedBox()),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia 👋';
    if (hour < 18) return 'Boa tarde 👋';
    return 'Boa noite 👋';
  }
}