import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/currency.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import 'account_type_badge.dart';

class AccountCard extends ConsumerWidget {
  final Account account;
  final AsyncValue<double> balanceAsync;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AccountCard({
    super.key,
    required this.account,
    required this.balanceAsync,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;

    final accountColor = account.color != null
        ? Color(account.color!)
        : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
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
                color: accountColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Ícone
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accountColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconForType(account.type),
                      color: accountColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Nome e tipo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: AppTextStyles.bodyBold(textPrimary),
                        ),
                        const SizedBox(height: 4),
                        AccountTypeBadge(type: account.type),
                      ],
                    ),
                  ),
                  // Saldo real
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      balanceAsync.when(
                        data: (balance) => Text(
                          CurrencyUtils.format(balance),
                          style: AppTextStyles.value(
                            balance < 0
                                ? AppColors.danger
                                : textPrimary,
                          ),
                        ),
                        loading: () => const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'saldo atual',
                        style: AppTextStyles.label(textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Menu
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 18, color: textSecondary),
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
                                style: TextStyle(
                                    color: AppColors.danger)),
                          ],
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

  IconData _iconForType(String type) => switch (type) {
        'checking' => Icons.account_balance_outlined,
        'savings' => Icons.savings_outlined,
        'cash' => Icons.wallet_outlined,
        'credit' => Icons.credit_card_outlined,
        _ => Icons.account_balance_wallet_outlined,
      };
}