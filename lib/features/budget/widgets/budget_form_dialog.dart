import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/currency.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../settings/providers/categories_provider.dart';
import '../../../core/services/sync_service_provider.dart';

// Provider declarado fora da classe — recebe (year, month) como chave
final _budgetsByMonthProvider = StreamProvider.autoDispose
    .family<List<Budget>, (int, int)>((ref, key) {
  final db = ref.watch(databaseProvider);
  return db.budgetsDao.watchBudgetsByMonth(key.$1, key.$2);
});

class BudgetFormDialog extends ConsumerStatefulWidget {
  final Budget? budget;
  final int year;
  final int month;

  const BudgetFormDialog({
    super.key,
    this.budget,
    required this.year,
    required this.month,
  });

  @override
  ConsumerState<BudgetFormDialog> createState() =>
      _BudgetFormDialogState();
}

class _BudgetFormDialogState extends ConsumerState<BudgetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  int _amountCents = 0;
  String? _selectedCategoryId;
  bool _isSaving = false;

  String _formatCents(int cents) {
    final value = cents / 100;
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  void _onAmountChanged(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    _amountCents = int.tryParse(digits) ?? 0;
    final formatted = _formatCents(_amountCents);
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _amountCents = (widget.budget!.limitAmount * 100).round();
      _amountController.text = _formatCents(_amountCents);
      _selectedCategoryId = widget.budget!.categoryId;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma categoria'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (_amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor maior que zero'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);
    final amount = _amountCents / 100;

    final companion = BudgetsCompanion(
      id: widget.budget != null
          ? Value(widget.budget!.id)
          : Value(AppDatabase.newId()),
      categoryId: Value(_selectedCategoryId!),
      year: Value(widget.year),
      month: Value(widget.month),
      limitAmount: Value(amount),
      createdAt: widget.budget == null
          ? Value(DateTime.now().millisecondsSinceEpoch)
          : const Value.absent(),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );

    if (widget.budget == null) {
      await db.budgetsDao.createBudget(companion);
    } else {
      await db.budgetsDao.updateBudget(companion);
    }

    ref.read(syncServiceProvider).scheduleUpload();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final isEditing = widget.budget != null;

    final existingBudgetsAsync =
        ref.watch(_budgetsByMonthProvider((widget.year, widget.month)));
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Editar orçamento' : 'Novo orçamento',
                style: AppTextStyles.sectionTitle(textPrimary),
              ),
              const SizedBox(height: 24),

              Text('Categoria',
                  style: AppTextStyles.label(textSecondary)),
              const SizedBox(height: 8),
              categoriesAsync.when(
                data: (categories) {
                  final availableCategories = isEditing
                      ? categories
                      : existingBudgetsAsync.whenOrNull(
                              data: (budgets) {
                                final usedIds = budgets.map((b) => b.categoryId).toSet();
                                return categories.where((c) => !usedIds.contains(c.id)).toList();
                              }) ??
                          categories;

                  final uniqueCategories = {
                    for (final c in availableCategories) c.id: c
                  }.values.toList();

                  // Se o value atual não existe na lista, reseta para null
                  // Isso evita o assert do DropdownButton
                  final safeValue = uniqueCategories.any((c) => c.id == _selectedCategoryId)
                      ? _selectedCategoryId
                      : null;
                
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: safeValue,
                        hint: Text(
                          uniqueCategories.isEmpty && !isEditing
                              ? 'Todas as categorias já têm orçamento'
                              : 'Selecione a categoria',
                          style: AppTextStyles.body(textSecondary),
                        ),
                        isExpanded: true,
                        dropdownColor: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        onChanged: isEditing || uniqueCategories.isEmpty
                            ? null
                            : (v) => setState(() => _selectedCategoryId = v),
                        items: uniqueCategories    // <-- aqui
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: c.color != null
                                              ? Color(c.color!)
                                              : AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(c.name,
                                          style: AppTextStyles.body(textPrimary)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),

              Text('Limite mensal',
                  style: AppTextStyles.label(textSecondary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                onChanged: _onAmountChanged,
                validator: (_) => _amountCents <= 0
                    ? 'Informe um valor maior que zero'
                    : null,
                decoration: InputDecoration(
                  hintText: '0,00',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Text(
                      'R\$',
                      style:
                          AppTextStyles.bodyBold(AppColors.primary),
                    ),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
                style: AppTextStyles.splineSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
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
                      onPressed: _isSaving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isEditing ? 'Salvar' : 'Criar',
                              style:
                                  AppTextStyles.bodyBold(Colors.white),
                            ),
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
}