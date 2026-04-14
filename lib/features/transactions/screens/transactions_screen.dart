import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/fuzzy_search.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../dashboard/widgets/month_selector.dart';
import '../providers/transactions_provider.dart';
import 'transaction_form_screen.dart';
import '../../accounts/screens/account_form_screen.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../settings/providers/categories_provider.dart';
import '../../../shared/widgets/alberto_widgets.dart';
import '../../../core/services/sync_service_provider.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  bool _searchActive = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterCategoryId;
  String? _filterPaymentMethod;

  final _paymentMethods = ['Débito', 'Crédito', 'Pix', 'Dinheiro', 'TED/DOC', 'Boleto'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _filterCategoryId != null || _filterPaymentMethod != null;

  List<Transaction> _applyFilters(List<Transaction> transactions) {
    return transactions.where((t) {
      if (_filterCategoryId != null && t.categoryId != _filterCategoryId) {
        return false;
      }
      if (_filterPaymentMethod != null &&
          t.paymentMethod != _filterPaymentMethod) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final searchTarget =
            '${t.description ?? ''} ${t.paymentMethod ?? ''}';
        if (!FuzzySearch.matches(_searchQuery, searchTarget)) return false;
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _filterCategoryId = null;
      _filterPaymentMethod = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;

    final filter = ref.watch(transactionTypeFilterProvider);

    // Se há busca ativa, usa todas as transações; senão usa o mês selecionado
    final isSearching = _searchQuery.isNotEmpty;
    final allAsync = ref.watch(allTransactionsProvider);
    final monthAsync = ref.watch(filteredTransactionsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: _searchActive
                  ? _SearchBar(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      onClose: () => setState(() {
                        _searchActive = false;
                        _searchQuery = '';
                        _searchController.clear();
                      }),
                    )
                  : Row(
                      children: [
                        Text('Transações',
                            style: AppTextStyles.splineSans(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            )),
                        const Spacer(),
                        IconButton(
                          onPressed: () =>
                              setState(() => _searchActive = true),
                          icon: Icon(Icons.search, color: textSecondary),
                          tooltip: 'Buscar transações',
                        ),
                        if (!isSearching) const MonthSelector(),
                      ],
                    ),
            ),
          ),

          // ── Filtros de tipo (ocultos durante busca global) ──
          if (!isSearching)
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

          // ── Filtros avançados: categoria + método ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: _AdvancedFilters(
                selectedCategoryId: _filterCategoryId,
                selectedPaymentMethod: _filterPaymentMethod,
                paymentMethods: _paymentMethods,
                hasActiveFilters: _hasActiveFilters,
                isDark: isDark,
                textSecondary: textSecondary,
                onCategoryChanged: (v) =>
                    setState(() => _filterCategoryId = v),
                onPaymentChanged: (v) =>
                    setState(() => _filterPaymentMethod = v),
                onClear: _clearFilters,
              ),
            ),
          ),

          // ── Aviso de busca global ──
          if (isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Buscando em todas as transações',
                      style: AppTextStyles.label(AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),

          // ── Lista ──
          Builder(builder: (context) {
            final source = isSearching ? allAsync : monthAsync;
            return source.when(
              data: (transactions) {
                final filtered = _applyFilters(transactions);

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Builder(builder: (ctx) {
                            final isSnoopy =
                                Theme.of(ctx).colorScheme.primary ==
                                    AppColors.snoopyPrimary;
                            if (isSnoopy) {
                              return Column(
                                children: [
                                  const AlbertoSittingWidget(size: 90),
                                  const SizedBox(height: 8),
                                  ThoughtBubbleWidget(
                                    text: isSearching
                                        ? 'Nenhum resultado...'
                                        : 'Nenhuma transação aqui...',
                                    bubbleColor: AppColors.snoopySurface,
                                    textColor: AppColors.snoopyTextPrimary,
                                  ),
                                ],
                              );
                            }
                            return Icon(Icons.receipt_long_outlined,
                                size: 48, color: textSecondary);
                          }),
                          const SizedBox(height: 16),
                          Text(
                            isSearching
                                ? 'Nenhuma transação encontrada'
                                : 'Nenhuma transação no período',
                            style: AppTextStyles.body(textSecondary),
                          ),
                          if (!isSearching) ...[
                            const SizedBox(height: 8),
                            Text('Toque em + para adicionar',
                                style: AppTextStyles.label(textSecondary)),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                final grouped = _groupByDate(filtered);
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
                            final isIn = t.isTransferOut == false;
                            return isIn
                                ? sum + t.amount
                                : sum - t.amount;
                          }
                          return sum;
                        });

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Text(
                                    _formatDateHeader(date),
                                    style:
                                        AppTextStyles.bodyBold(textSecondary),
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
            );
          }),
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
              final controller = messenger.showSnackBar(
                SnackBar(
                  content: const Text(
                      'Crie uma conta antes de adicionar transações'),
                  backgroundColor: AppColors.danger,
                  duration: const Duration(days: 1),
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
              Timer(const Duration(seconds: 6), () {
                controller.close();
              });
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
      BuildContext context, WidgetRef ref, String id) async {
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
      ref.read(syncServiceProvider).scheduleUpload();
    }
  }
}

// ── Barra de busca ──

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            style: AppTextStyles.body(
              isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar transações...',
              hintStyle: AppTextStyles.body(
                isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              prefixIcon: const Icon(Icons.search, size: 20),
              prefixIconColor: AppColors.primary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor:
                  isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close),
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ],
    );
  }
}

// ── Filtros avançados ──

class _AdvancedFilters extends ConsumerWidget {
  final String? selectedCategoryId;
  final String? selectedPaymentMethod;
  final List<String> paymentMethods;
  final bool hasActiveFilters;
  final bool isDark;
  final Color textSecondary;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onPaymentChanged;
  final VoidCallback onClear;

  const _AdvancedFilters({
    required this.selectedCategoryId,
    required this.selectedPaymentMethod,
    required this.paymentMethods,
    required this.hasActiveFilters,
    required this.isDark,
    required this.textSecondary,
    required this.onCategoryChanged,
    required this.onPaymentChanged,
    required this.onClear,
  });

  List<DropdownMenuItem<String>> _buildCategoryItems(
    List<Category> categories,
  ) {
    final expenses = categories.where((c) => c.type == 'expense').toList();
    final incomes = categories.where((c) => c.type == 'income').toList();
    final tpColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    final items = <DropdownMenuItem<String>>[];

    // Opção "Todas"
    items.add(DropdownMenuItem(
      value: null,
      child: Text('Todas as categorias',
          style: AppTextStyles.label(textSecondary)),
    ));

    // ── Cabeçalho Despesas ──
    if (expenses.isNotEmpty) {
      items.add(DropdownMenuItem(
        enabled: false,
        value: '__header_expense__',
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Row(children: [
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.danger, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('DESPESAS',
                style: AppTextStyles.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger)),
          ]),
        ),
      ));
      for (final c in expenses) {
        items.add(DropdownMenuItem(
          value: c.id,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c.color != null ? Color(c.color!) : AppColors.primary,
                    shape: BoxShape.circle,
                  )),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(c.name,
                      style: AppTextStyles.label(tpColor),
                      overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ));
      }
    }

    // ── Separador visual ──
    if (expenses.isNotEmpty && incomes.isNotEmpty) {
      items.add(DropdownMenuItem(
        enabled: false,
        value: '__divider__',
        child: const Divider(height: 8, thickness: 1),
      ));
    }

    // ── Cabeçalho Receitas ──
    if (incomes.isNotEmpty) {
      items.add(DropdownMenuItem(
        enabled: false,
        value: '__header_income__',
        child: Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: Row(children: [
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.success, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('RECEITAS',
                style: AppTextStyles.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success)),
          ]),
        ),
      ));
      for (final c in incomes) {
        items.add(DropdownMenuItem(
          value: c.id,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c.color != null ? Color(c.color!) : AppColors.primary,
                    shape: BoxShape.circle,
                  )),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(c.name,
                      style: AppTextStyles.label(tpColor),
                      overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ));
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final surfaceColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;

    return categoriesAsync.when(
      data: (categories) => Row(
        children: [
          // Dropdown categoria com grupos
          Expanded(
            child: _CompactDropdown<String>(
              hint: 'Categoria',
              value: selectedCategoryId,
              isDark: isDark,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textSecondary: textSecondary,
              items: _buildCategoryItems(categories),
              onChanged: onCategoryChanged,
            ),
          ),
          const SizedBox(width: 8),
          // Dropdown método de pagamento
          Expanded(
            child: _CompactDropdown<String>(
              hint: 'Pagamento',
              value: selectedPaymentMethod,
              isDark: isDark,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textSecondary: textSecondary,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text('Todos',
                      style: AppTextStyles.label(textSecondary)),
                ),
                ...paymentMethods.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m,
                          style: AppTextStyles.label(
                            isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          )),
                    )),
              ],
              onChanged: onPaymentChanged,
            ),
          ),
          // Botão limpar filtros
          if (hasActiveFilters) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              color: AppColors.danger,
              tooltip: 'Limpar filtros',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.danger.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _CompactDropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isDark;
  final Color surfaceColor;
  final Color borderColor;
  final Color textSecondary;

  const _CompactDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.isDark,
    required this.surfaceColor,
    required this.borderColor,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: value != null
            ? AppColors.primary.withOpacity(0.08)
            : surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value != null
              ? AppColors.primary.withOpacity(0.4)
              : borderColor,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint,
              style: AppTextStyles.dmSans(fontSize: 12, color: textSecondary),
              overflow: TextOverflow.ellipsis),
          isExpanded: true,
          isDense: true,
          dropdownColor: surfaceColor,
          style: AppTextStyles.dmSans(
            fontSize: 12,
            color: value != null
                ? AppColors.primary
                : (isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight),
            fontWeight:
                value != null ? FontWeight.w600 : FontWeight.w400,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Chip de filtro de tipo ──

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? color : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}

// ── Tile de uma transação ──

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
    final isTransferIn = isTransfer && (transaction.isTransferOut == false);
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