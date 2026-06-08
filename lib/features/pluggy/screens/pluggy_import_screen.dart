import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../settings/providers/categories_provider.dart';
import '../../../core/services/sync_service_provider.dart';

const _prefPluggyLastImport = 'pluggy_last_import';
const _prefPluggySeenIdsDate = 'pluggy_seen_ids_date';
const _prefPluggySeenIds = 'pluggy_seen_ids';

class PluggyImportScreen extends ConsumerStatefulWidget {
  /// Transações brutas vindas da API do Pluggy
  final List<Map<String, dynamic>> transactions;

  const PluggyImportScreen({super.key, required this.transactions});

  @override
  ConsumerState<PluggyImportScreen> createState() => _PluggyImportScreenState();
}

class _PluggyImportScreenState extends ConsumerState<PluggyImportScreen> {
  // Lista mutável — o usuário pode descartar itens
  late List<_TxRow> _rows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rows = widget.transactions.map((tx) => _TxRow(raw: tx)).toList();
  }

  bool get _allValid => _rows.every((r) => r.isValid);

  Future<void> _save() async {
    if (!_allValid) return;
    setState(() => _saving = true);

    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      for (final row in _rows) {
        final amount = (row.raw['amount'] as num?)?.toDouble().abs() ?? 0.0;
        final pluggyType = row.raw['type'] as String? ?? 'DEBIT';
        final type = pluggyType == 'CREDIT' ? 'income' : 'expense';

        final dateStr = row.raw['date'] as String? ?? '';
        int dateTs = now;
        try {
          dateTs = DateTime.parse(dateStr).millisecondsSinceEpoch;
        } catch (_) {}

        await db.transactionsDao.createTransaction(
          TransactionsCompanion.insert(
            id: AppDatabase.newId(),
            accountId: row.selectedAccountId!,
            categoryId: Value(row.selectedCategoryId),
            type: Value(type),
            amount: amount,
            date: dateTs,
            description: Value(
              row.description.trim().isNotEmpty
                  ? row.description.trim()
                  : (row.raw['description'] as String?),
            ),
            paymentMethod: Value(
              row.paymentMethod.isNotEmpty ? row.paymentMethod : null,
            ),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      await _saveImportState(widget.transactions);

      ref.read(syncServiceProvider).scheduleUpload();

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _skipAll() async {
    await _saveImportState(widget.transactions);
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _saveImportState(List<Map<String, dynamic>> transactions) async {
    if (transactions.isEmpty) return;

    DateTime? latestDay;
    for (final tx in transactions) {
      try {
        final d = DateTime.parse(tx['date'] as String? ?? '');
        if (latestDay == null || d.isAfter(latestDay)) latestDay = d;
      } catch (_) {}
    }

    if (latestDay == null) return;

    final lastImportMs = DateTime(latestDay.year, latestDay.month, latestDay.day)
        .millisecondsSinceEpoch;

    final latestDateStr =
        '${latestDay.year}-${latestDay.month.toString().padLeft(2, '0')}-${latestDay.day.toString().padLeft(2, '0')}';

    // Coleta IDs de todas as transações do dia mais recente neste lote
    final newIds = <String>{};
    for (final tx in transactions) {
      try {
        final d = DateTime.parse(tx['date'] as String? ?? '');
        final dateStr =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        if (dateStr == latestDateStr) {
          final id = tx['id'] as String?;
          if (id != null && id.isNotEmpty) newIds.add(id);
        }
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();

    // Se o dia salvo for o mesmo, faz UNIÃO com os IDs já existentes
    final savedDate = prefs.getString(_prefPluggySeenIdsDate) ?? '';
    final existingIds = savedDate == latestDateStr
        ? (prefs.getStringList(_prefPluggySeenIds) ?? []).toSet()
        : <String>{};

    final allIds = existingIds.union(newIds).toList();

    await prefs.setInt(_prefPluggyLastImport, lastImportMs);
    await prefs.setString(_prefPluggySeenIdsDate, latestDateStr);
    await prefs.setStringList(_prefPluggySeenIds, allIds);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  
    final accountsAsync = ref.watch(accountsProvider);
    final expenseCatsAsync = ref.watch(expenseCategoriesProvider);
    final incomeCatsAsync = ref.watch(incomeCategoriesProvider);
  
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Novas transações (${_rows.length})',
          style: AppTextStyles.sectionTitle(textPrimary),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _saving ? null : _skipAll,
            child: Text(
              'Ignorar tudo',
              style: AppTextStyles.bodyBold(AppColors.danger),
            ),
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          // Auto-seleciona a conta se houver apenas uma
          if (accounts.length == 1) {
            for (final row in _rows) {
              row.selectedAccountId ??= accounts.first.id;
            }
          }
  
          return expenseCatsAsync.when(
            data: (expenseCats) => incomeCatsAsync.when(
              data: (incomeCats) {
                if (_rows.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    await _skipAll();
                  });
                  return const Center(child: CircularProgressIndicator());
                }
  
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          final pluggyType =
                              row.raw['type'] as String? ?? 'DEBIT';
                          final isCredit = pluggyType == 'CREDIT';
                          final cats = isCredit ? incomeCats : expenseCats;
  
                          return _TxCard(
                            row: row,
                            accounts: accounts,
                            categories: cats,
                            isDark: isDark,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onChanged: () => setState(() {}),
                            onDiscard: () =>
                                setState(() => _rows.removeAt(index)),
                          );
                        },
                      ),
                    ),
  
                    // Botão salvar
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: (_allValid && !_saving) ? _save : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Salvar ${_rows.length} transaç${_rows.length == 1 ? 'ão' : 'ões'}',
                                    style:
                                        AppTextStyles.bodyBold(Colors.white),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

// ── Card de cada transação ──

class _TxCard extends StatefulWidget {
  final _TxRow row;
  final List<Account> accounts;
  final List<Category> categories;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onChanged;
  final VoidCallback onDiscard;

  const _TxCard({
    required this.row,
    required this.accounts,
    required this.categories,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.onChanged,
    required this.onDiscard,
  });

  @override
  State<_TxCard> createState() => _TxCardState();
}

class _TxCardState extends State<_TxCard> {
  final _descController = TextEditingController();

  static const _paymentMethods = [
    '', 'Débito', 'Crédito', 'Pix', 'Dinheiro', 'TED/DOC', 'Boleto',
  ];

  @override
  void initState() {
    super.initState();
    _descController.text = widget.row.description;
    _descController.addListener(() {
      widget.row.description = _descController.text;
      widget.onChanged();
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final raw = row.raw;

    final pluggyName = raw['description'] as String? ?? 'Transação';
    final amount = (raw['amount'] as num?)?.toDouble().abs() ?? 0.0;
    final pluggyType = raw['type'] as String? ?? 'DEBIT';
    final isCredit = pluggyType == 'CREDIT';
    final color = isCredit ? AppColors.success : AppColors.danger;
    final dateStr = raw['date'] as String?;
    final isPending = (raw['status'] as String?) == 'PENDING';

    String formattedDate = '';
    if (dateStr != null) {
      try {
        formattedDate = AppDateUtils.toFullDate(DateTime.parse(dateStr));
      } catch (_) {}
    }

    final borderColor = widget.isDark ? AppColors.borderDark : AppColors.borderLight;
    final surfaceColor = widget.isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.15 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Linha 1: info do Pluggy ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isCredit
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pluggyName,
                              style: AppTextStyles.bodyBold(widget.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPending)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'pendente',
                                style: AppTextStyles.dmSans(
                                    fontSize: 10, color: AppColors.accent),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '$formattedDate · ${raw['_accountName'] ?? ''}',
                        style: AppTextStyles.label(widget.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${isCredit ? '+' : '-'} ${CurrencyUtils.format(amount)}',
                  style: AppTextStyles.bodyBold(color),
                ),
                IconButton(
                  onPressed: widget.onDiscard,
                  icon: Icon(Icons.close, size: 18, color: widget.textSecondary),
                  tooltip: 'Descartar',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          const Divider(height: 16, indent: 14, endIndent: 14),

          // ── Linha 2: inputs ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                // Conta + Categoria
                Row(
                  children: [
                    Expanded(
                      child: _CompactDropdown<String>(
                        label: 'Conta *',
                        value: row.selectedAccountId,
                        isDark: widget.isDark,
                        items: widget.accounts
                            .map((a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(a.name,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() => row.selectedAccountId = v);
                          widget.onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactDropdown<String>(
                        label: 'Categoria *',
                        value: row.selectedCategoryId,
                        isDark: widget.isDark,
                        items: widget.categories
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() => row.selectedCategoryId = v);
                          widget.onChanged();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Descrição + Método de pagamento
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _CompactTextField(
                        label: 'Descrição',
                        controller: _descController,
                        isDark: widget.isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _CompactDropdown<String>(
                        label: 'Pagamento',
                        value: row.paymentMethod.isEmpty ? null : row.paymentMethod,
                        isDark: widget.isDark,
                        items: _paymentMethods
                            .where((m) => m.isNotEmpty)
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) {
                          setState(() => row.paymentMethod = v ?? '');
                          widget.onChanged();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dropdown compacto ──

class _CompactDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isDark;

  const _CompactDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(label,
              style: AppTextStyles.dmSans(fontSize: 12, color: textSecondary),
              overflow: TextOverflow.ellipsis),
          isExpanded: true,
          isDense: true,
          dropdownColor: surfaceColor,
          style: AppTextStyles.dmSans(
            fontSize: 13,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── TextField compacto ──

class _CompactTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isDark;

  const _CompactTextField({
    required this.label,
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return TextField(
      controller: controller,
      style: AppTextStyles.dmSans(
        fontSize: 13,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: AppTextStyles.dmSans(
          fontSize: 12,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ── Model de linha ──

class _TxRow {
  final Map<String, dynamic> raw;
  String? selectedAccountId;
  String? selectedCategoryId;
  String description = '';
  String paymentMethod = '';

  _TxRow({required this.raw});

  bool get isValid => selectedAccountId != null && selectedCategoryId != null;
}