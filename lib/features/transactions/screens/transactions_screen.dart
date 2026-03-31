import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../dashboard/widgets/month_selector.dart';
import '../providers/transactions_provider.dart';
import 'transaction_form_screen.dart';
import '../../accounts/screens/account_form_screen.dart';
import '../../accounts/providers/accounts_provider.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

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

    final filteredAsync = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionTypeFilterProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Row(
                children: [
                  Text('Transações',
                      style: AppTextStyles.splineSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      )),
                  const Spacer(),
                  const MonthSelector(),
                ],
              ),
            ),
          ),

          // Filtros de tipo
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Todas',
                    isSelected: filter == 'all',
                    color: AppColors.primary,
                    onTap: () => ref
                        .read(transactionTypeFilterProvider.notifier)
                        .state = 'all',
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Receitas',
                    isSelected: filter == 'income',
                    color: AppColors.success,
                    onTap: () => ref
                        .read(transactionTypeFilterProvider.notifier)
                        .state = 'income',
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Despesas',
                    isSelected: filter == 'expense',
                    color: AppColors.danger,
                    onTap: () => ref
                        .read(transactionTypeFilterProvider.notifier)
                        .state = 'expense',
                  ),
                ],
              ),
            ),
          ),

          // Lista de transações
          filteredAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48, color: textSecondary),
                        const SizedBox(height: 16),
                        Text('Nenhuma transação no período',
                            style: AppTextStyles.body(textSecondary)),
                        const SizedBox(height: 8),
                        Text('Toque em + para adicionar',
                            style: AppTextStyles.label(textSecondary)),
                      ],
                    ),
                  ),
                );
              }

              // Agrupa por data
              final grouped = _groupByDate(transactions);
              final dates = grouped.keys.toList();

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final date = dates[index];
                      final items = grouped[date]!;
                      final dayTotal = items.fold(0.0, (sum, t) {
                        if (t.type == 'income') return sum + t.amount;
                        if (t.type == 'expense') return sum - t.amount;
                        if (t.type == 'transfer') {
                          // Transferências se cancelam mutuamente no total do dia
                          // Entrada soma, saída subtrai
                          if (t.transferPairId != null && t.transferPairId! < t.id) {
                            return sum + t.amount; // entrada
                          } else {
                            return sum - t.amount; // saída
                          }
                        }
                        return sum;
                      });

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabeçalho do dia
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Text(
                                  _formatDateHeader(date),
                                  style: AppTextStyles.bodyBold(
                                      textSecondary),
                                ),
                                const Spacer(),
                                Text(
                                  CurrencyUtils.formatSigned(dayTotal),
                                  style: AppTextStyles.bodyBold(
                                    dayTotal >= 0
                                        ? AppColors.success
                                        : AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Transações do dia
                          ...items.map((t) => _TransactionTile(
                                transaction: t,
                                surfaceColor: surfaceColor,
                                borderColor: borderColor,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                onTap: () => _openForm(context, t),
                                onDelete: () =>
                                    _confirmDelete(context, ref, t.id),
                              )),
                        ],
                      );
                    },
                    childCount: dates.length,
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
        onPressed: () {
          final accounts = ref.read(accountsProvider);
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          accounts.whenData((list) {
            if (list.isEmpty) {
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(
                SnackBar(
                  content: const Text(
                      'Crie uma conta antes de adicionar transações'),
                  backgroundColor: AppColors.danger,
                  action: SnackBarAction(
                    label: 'Criar conta',
                    textColor: Colors.white,
                    onPressed: () {
                      messenger.hideCurrentSnackBar();
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => const AccountFormScreen(),
                        ),
                      );
                    },
                  ),
                ),
              );
            } else {
              _openForm(context, null);
            }
          });
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Nova transação',
            style: AppTextStyles.bodyBold(Colors.white)),
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

  void _openForm(BuildContext context, Transaction? transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(transaction: transaction),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir transação'),
        content:
            const Text('Tem certeza? Esta ação não pode ser desfeita.'),
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
      await db.transactionsDao.deleteTransaction(id);
    }
  }
}

// Chip de filtro
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.dmSans(
            fontSize: 13,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? color : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}

// Tile de uma transação
class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TransactionTile({
    required this.transaction,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final isTransfer = transaction.type == 'transfer';

    // Para transferências: entrada se transferPairId < id, saída se > id
    final isTransferIn = isTransfer &&
        transaction.transferPairId != null &&
        transaction.transferPairId! < transaction.id;

    final color = isTransfer
        ? AppColors.accent
        : isIncome
            ? AppColors.success
            : AppColors.danger;

    // Sinal do valor: receita ou transferência de entrada = positivo
    final isPositive = isIncome || isTransferIn;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
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
              size: 20,
            ),
          ),
          title: Text(
            transaction.description ?? _defaultLabel(transaction.type),
            style: AppTextStyles.bodyBold(textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: transaction.paymentMethod != null
              ? Text(
                  transaction.paymentMethod!,
                  style: AppTextStyles.label(textSecondary),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${isPositive ? '+' : '-'} ${CurrencyUtils.format(transaction.amount)}',
                style: AppTextStyles.bodyBold(
                  isPositive ? AppColors.success : AppColors.danger,
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    size: 16, color: textSecondary),
                onSelected: (value) {
                  if (value == 'edit') onTap();
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
        ),
      ),
    );
  }

  String _defaultLabel(String type) => switch (type) {
        'income' => 'Receita',
        'expense' => 'Despesa',
        'transfer' => 'Transferência',
        _ => 'Transação',
      };
}