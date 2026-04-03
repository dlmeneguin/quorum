import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../core/utils/currency.dart';
import '../../../core/database/database_provider.dart';
import '../providers/accounts_provider.dart';
import '../widgets/account_card.dart';
import 'account_form_screen.dart';
import 'account_detail_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Contas',
                            style: AppTextStyles.splineSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: textPrimary)),
                        const SizedBox(height: 4),
                        accountsAsync.when(
                          data: (accounts) => Text(
                            '${accounts.length} conta${accounts.length != 1 ? 's' : ''} cadastrada${accounts.length != 1 ? 's' : ''}',
                            style: AppTextStyles.label(textSecondary),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  // Botão nova conta
                  FilledButton.icon(
                    onPressed: () => _openForm(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nova conta'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Patrimônio total
          accountsAsync.when(
            data: (accounts) {
              final totalAsync = ref.watch(totalBalanceProvider);
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
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
                          'Patrimônio líquido',
                          style: AppTextStyles.label(
                              Colors.white.withOpacity(0.8)),
                        ),
                        const SizedBox(height: 8),
                        totalAsync.when(
                          data: (total) => Text(
                            CurrencyUtils.format(total),
                            style: AppTextStyles.dashboardNumber(Colors.white),
                          ),
                          loading: () => const CircularProgressIndicator(
                              color: Colors.white),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
          ),

          // Lista de contas
          accountsAsync.when(
            data: (accounts) {
              if (accounts.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 48, color: textSecondary),
                        const SizedBox(height: 16),
                        Text('Nenhuma conta cadastrada',
                            style: AppTextStyles.body(textSecondary)),
                        const SizedBox(height: 8),
                        Text('Crie sua primeira conta para começar',
                            style: AppTextStyles.label(textSecondary)),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final account = accounts[index];
                      final balanceAsync =
                          ref.watch(accountBalanceProvider(account));
                      return AccountCard(
                        account: account,
                        balanceAsync: balanceAsync,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AccountDetailScreen(account: account),
                          ),
                        ),
                        onEdit: () => _openForm(context, account: account),
                        onDelete: () =>
                            _confirmDelete(context, ref, account.id),
                      );
                    },
                    childCount: accounts.length,
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
    );
  }

  void _openForm(BuildContext context, {account}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountFormScreen(account: account),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id) async {
    final db = ref.read(databaseProvider);
  
    // Busca as dependências antes de exibir o diálogo
    final counts = await db.accountsDao.getAccountDependencyCounts(id);
  
    if (!context.mounted) return;
  
    // Monta a descrição do impacto
    final List<String> impacts = [];
    if (counts.transactions > 0) {
      impacts.add(
          '${counts.transactions} transaç${counts.transactions == 1 ? 'ão' : 'ões'}');
    }
    if (counts.goals > 0) {
      impacts.add('${counts.goals} meta${counts.goals == 1 ? '' : 's'}');
    }
  
    final String impactText = impacts.isEmpty
        ? 'Esta conta não possui transações ou metas vinculadas.'
        : 'Serão excluídos permanentemente: ${impacts.join(' e ')} vinculados a esta conta.';
  
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(impactText),
            if (impacts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: AppColors.danger),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Esta ação é permanente e não pode ser desfeita.',
                        style: TextStyle(
                            color: AppColors.danger, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: const Text('Excluir tudo'),
          ),
        ],
      ),
    );
  
    if (confirmed == true) {
      await db.accountsDao.deleteAccountCascade(id);
    }
  }
}