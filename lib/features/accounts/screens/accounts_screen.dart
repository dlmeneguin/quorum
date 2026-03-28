import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../core/utils/currency.dart';
import '../../../core/database/database_provider.dart';
import '../providers/accounts_provider.dart';
import '../widgets/account_card.dart';
import 'account_form_screen.dart';

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
              final total = accounts.fold(
                  0.0, (sum, a) => sum + a.initialBalance);
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
                        Text(
                          CurrencyUtils.format(total),
                          style: AppTextStyles.dashboardNumber(
                              Colors.white),
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
                      return AccountCard(
                        account: account,
                        onTap: () {},
                        onEdit: () =>
                            _openForm(context, account: account),
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
      BuildContext context, WidgetRef ref, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
            'Tem certeza? Esta ação não pode ser desfeita.'),
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
      await db.accountsDao.deactivateAccount(id);
    }
  }
}