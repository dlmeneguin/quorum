import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../settings/providers/categories_provider.dart';
import '../../accounts/providers/accounts_provider.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final Transaction? transaction;

  const TransactionFormScreen({super.key, this.transaction});

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState
    extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedType = 'expense';
  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId;
  int? _selectedAccountId;
  int? _selectedToAccountId; // Para transferência
  String? _selectedPaymentMethod;
  bool _isRecurring = false;
  bool _isInstallment = false;
  int _installmentCount = 2;
  int _amountCents = 0;
  bool _isSaving = false;

  final _paymentMethods = [
    'Débito',
    'Crédito',
    'Pix',
    'Dinheiro',
    'TED/DOC',
    'Boleto',
  ];

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
    if (widget.transaction != null) {
      final t = widget.transaction!;
      if (widget.transaction != null) {
        _amountCents = (widget.transaction!.amount * 100).round();
        _amountController.text = _formatCents(_amountCents);
      }
      _descriptionController.text = t.description ?? '';
      _selectedType = t.type;
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(t.date);
      _selectedCategoryId = t.categoryId;
      _selectedAccountId = t.accountId;
      _selectedPaymentMethod = t.paymentMethod;
      _isRecurring = t.isRecurring;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      _showError('Selecione uma conta');
      return;
    }
    if (_selectedType != 'transfer' && _selectedCategoryId == null) {
      _showError('Selecione uma categoria');
      return;
    }
    if (_selectedType == 'transfer' && _selectedToAccountId == null) {
      _showError('Selecione a conta de destino');
      return;
    }

    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);
    final amount = _amountCents / 100;
    final dateTs = _selectedDate.millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      if (_selectedType == 'transfer') {
        // Transferência: gera dois lançamentos vinculados
        await _saveTransfer(db, amount, dateTs, now);
      } else if (_isInstallment && widget.transaction == null) {
        // Parcelamento: gera N lançamentos
        await _saveInstallments(db, amount, dateTs, now);
      } else if (_isRecurring && widget.transaction == null) {
        // Recorrente: salva o primeiro e marca como recorrente
        await _saveRecurring(db, amount, dateTs, now);
      } else {
        // Transação simples
        await _saveSimple(db, amount, dateTs, now);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Erro ao salvar: $e');
    }
  }

  Future<void> _saveSimple(
      AppDatabase db, double amount, int dateTs, int now) async {
    final companion = TransactionsCompanion.insert(
      accountId: _selectedAccountId!,
      categoryId: Value(_selectedCategoryId),
      type: Value(_selectedType),
      amount: amount,
      date: dateTs,
      description: Value(_descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim()),
      paymentMethod: Value(_selectedPaymentMethod),
      isRecurring: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    if (widget.transaction == null) {
      await db.transactionsDao.createTransaction(companion);
    } else {
      await db.transactionsDao.updateTransaction(
        companion.copyWith(id: Value(widget.transaction!.id)),
      );
    }
  }

  Future<void> _saveInstallments(
      AppDatabase db, double amount, int dateTs, int now) async {
    final installmentAmount = amount / _installmentCount;
    final groupId =
        'inst_${DateTime.now().millisecondsSinceEpoch}';
    final baseDate = DateTime.fromMillisecondsSinceEpoch(dateTs);

    for (int i = 0; i < _installmentCount; i++) {
      final installmentDate =
          DateTime(baseDate.year, baseDate.month + i, baseDate.day);
      await db.transactionsDao.createTransaction(
        TransactionsCompanion.insert(
          accountId: _selectedAccountId!,
          categoryId: Value(_selectedCategoryId),
          type: Value(_selectedType),
          amount: installmentAmount,
          date: installmentDate.millisecondsSinceEpoch,
          description: Value(
            '${_descriptionController.text.trim().isEmpty ? 'Parcela' : _descriptionController.text.trim()} ${i + 1}/$_installmentCount',
          ),
          paymentMethod: Value(_selectedPaymentMethod),
          installmentTotal: Value(_installmentCount),
          installmentCurrent: Value(i + 1),
          installmentGroupId: Value(groupId),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> _saveRecurring(
      AppDatabase db, double amount, int dateTs, int now) async {
    final id = await db.transactionsDao.createTransaction(
      TransactionsCompanion.insert(
        accountId: _selectedAccountId!,
        categoryId: Value(_selectedCategoryId),
        type: Value(_selectedType),
        amount: amount,
        date: dateTs,
        description: Value(_descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim()),
        paymentMethod: Value(_selectedPaymentMethod),
        isRecurring: const Value(true),
        recurrenceType: const Value('monthly'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // Gera os próximos 11 meses automaticamente
    final baseDate = DateTime.fromMillisecondsSinceEpoch(dateTs);
    for (int i = 1; i <= 11; i++) {
      final nextDate =
          DateTime(baseDate.year, baseDate.month + i, baseDate.day);
      await db.transactionsDao.createTransaction(
        TransactionsCompanion.insert(
          accountId: _selectedAccountId!,
          categoryId: Value(_selectedCategoryId),
          type: Value(_selectedType),
          amount: amount,
          date: nextDate.millisecondsSinceEpoch,
          description: Value(_descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim()),
          paymentMethod: Value(_selectedPaymentMethod),
          isRecurring: const Value(true),
          recurrenceType: const Value('monthly'),
          recurrenceParentId: Value(id),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> _saveTransfer(
      AppDatabase db, double amount, int dateTs, int now) async {
    // Saída da conta origem
    final outId = await db.transactionsDao.createTransaction(
      TransactionsCompanion.insert(
        accountId: _selectedAccountId!,
        type: const Value('transfer'),
        amount: amount,
        date: dateTs,
        description: Value(_descriptionController.text.trim().isEmpty
            ? 'Transferência'
            : _descriptionController.text.trim()),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // Entrada na conta destino
    await db.transactionsDao.createTransaction(
      TransactionsCompanion.insert(
        accountId: _selectedToAccountId!,
        type: const Value('transfer'),
        amount: amount,
        date: dateTs,
        description: Value(_descriptionController.text.trim().isEmpty
            ? 'Transferência'
            : _descriptionController.text.trim()),
        transferPairId: Value(outId),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // Vincula o pair no primeiro registro
    await db.transactionsDao.updateTransaction(
      TransactionsCompanion(
        id: Value(outId),
        accountId: Value(_selectedAccountId!),
        amount: Value(amount),
        date: Value(dateTs),
        type: const Value('transfer'),
        transferPairId: Value(outId + 1),
        updatedAt: Value(now),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final isEditing = widget.transaction != null;

    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = _selectedType == 'income'
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(expenseCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Transação' : 'Nova Transação',
          style: AppTextStyles.sectionTitle(textPrimary),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Seletor de tipo
            _SectionLabel('Tipo', textSecondary),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    label: 'Despesa',
                    icon: Icons.arrow_upward_rounded,
                    color: AppColors.danger,
                    isSelected: _selectedType == 'expense',
                    onTap: () => setState(() {
                      _selectedType = 'expense';
                      _selectedCategoryId = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypeButton(
                    label: 'Receita',
                    icon: Icons.arrow_downward_rounded,
                    color: AppColors.success,
                    isSelected: _selectedType == 'income',
                    onTap: () => setState(() {
                      _selectedType = 'income';
                      _selectedCategoryId = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypeButton(
                    label: 'Transferência',
                    icon: Icons.swap_horiz_rounded,
                    color: AppColors.accent,
                    isSelected: _selectedType == 'transfer',
                    onTap: () => setState(() {
                      _selectedType = 'transfer';
                      _selectedCategoryId = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Valor
            _SectionLabel('Valor', textSecondary),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              onChanged: _onAmountChanged,
              validator: (_) =>
                  _amountCents <= 0 ? 'Informe um valor maior que zero' : null,
              decoration: InputDecoration(
                hintText: '0,00',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Text(
                    'R\$',
                    style: AppTextStyles.bodyBold(
                      _selectedType == 'income'
                          ? AppColors.success
                          : _selectedType == 'transfer'
                              ? AppColors.accent
                              : AppColors.danger,
                    ),
                  ),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _selectedType == 'income'
                        ? AppColors.success
                        : _selectedType == 'transfer'
                            ? AppColors.accent
                            : AppColors.danger,
                    width: 2,
                  ),
                ),
              ),
              style: AppTextStyles.splineSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _selectedType == 'income'
                    ? AppColors.success
                    : _selectedType == 'transfer'
                        ? AppColors.accent
                        : AppColors.danger,
              ),
            ),
            const SizedBox(height: 24),

            // Data
            _SectionLabel('Data', textSecondary),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
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
                        size: 18, color: textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      AppDateUtils.toFullDate(_selectedDate),
                      style: AppTextStyles.body(textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Conta origem
            _SectionLabel(
              _selectedType == 'transfer' ? 'Conta de origem' : 'Conta',
              textSecondary,
            ),
            const SizedBox(height: 8),
            accountsAsync.when(
              data: (accounts) => _DropdownField<int>(
                value: _selectedAccountId,
                hint: 'Selecione a conta',
                items: accounts
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name,
                              style: AppTextStyles.body(textPrimary)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedAccountId = v),
                isDark: isDark,
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // Conta destino (só para transferência)
            if (_selectedType == 'transfer') ...[
              _SectionLabel('Conta de destino', textSecondary),
              const SizedBox(height: 8),
              accountsAsync.when(
                data: (accounts) => _DropdownField<int>(
                  value: _selectedToAccountId,
                  hint: 'Selecione a conta destino',
                  items: accounts
                      .where((a) => a.id != _selectedAccountId)
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name,
                                style: AppTextStyles.body(textPrimary)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedToAccountId = v),
                  isDark: isDark,
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
            ],

            // Categoria (não aparece em transferência)
            if (_selectedType != 'transfer') ...[
              _SectionLabel('Categoria', textSecondary),
              const SizedBox(height: 8),
              categoriesAsync.when(
                data: (categories) => _DropdownField<int>(
                  value: _selectedCategoryId,
                  hint: 'Selecione a categoria',
                  items: categories
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
                                    style:
                                        AppTextStyles.body(textPrimary)),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedCategoryId = v),
                  isDark: isDark,
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
            ],

            // Descrição
            _SectionLabel('Descrição (opcional)', textSecondary),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: 'Ex: Supermercado Extra...',
              ),
              style: AppTextStyles.body(textPrimary),
            ),
            const SizedBox(height: 24),

            // Método de pagamento (não aparece em transferência)
            if (_selectedType != 'transfer') ...[
              _SectionLabel(
                  'Método de pagamento (opcional)', textSecondary),
              const SizedBox(height: 8),
              _DropdownField<String>(
                value: _selectedPaymentMethod,
                hint: 'Selecione o método',
                items: _paymentMethods
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m,
                              style: AppTextStyles.body(textPrimary)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedPaymentMethod = v),
                isDark: isDark,
              ),
              const SizedBox(height: 24),
            ],

            // Opções avançadas (só para criação, não edição)
            if (!isEditing && _selectedType != 'transfer') ...[
              _SectionLabel('Opções', textSecondary),
              const SizedBox(height: 8),

              // Recorrente
              _OptionTile(
                icon: Icons.repeat_rounded,
                label: 'Recorrente mensal',
                subtitle: 'Repete automaticamente todo mês por 12 meses',
                value: _isRecurring,
                color: AppColors.primary,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onChanged: (v) => setState(() {
                  _isRecurring = v;
                  if (v) _isInstallment = false;
                }),
              ),
              const SizedBox(height: 8),

              // Parcelado
              _OptionTile(
                icon: Icons.credit_card_outlined,
                label: 'Parcelado',
                subtitle: 'Divide o valor em parcelas mensais',
                value: _isInstallment,
                color: const Color(0xFF6366F1),
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onChanged: (v) => setState(() {
                  _isInstallment = v;
                  if (v) _isRecurring = false;
                }),
              ),

              // Número de parcelas
              if (_isInstallment) ...[
                const SizedBox(height: 16),
                _SectionLabel('Número de parcelas', textSecondary),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: _installmentCount > 2
                          ? () => setState(() => _installmentCount--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppColors.primary,
                    ),
                    Container(
                      width: 60,
                      alignment: Alignment.center,
                      child: Text(
                        '$_installmentCount x',
                        style: AppTextStyles.splineSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _installmentCount < 48
                          ? () => setState(() => _installmentCount++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                         _amountCents > 0
                            ? '${CurrencyUtils.format(_amountCents / 100 / _installmentCount)} / parcela'
                            : '',
                        style: AppTextStyles.label(textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
            ],

            // Botão salvar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEditing ? 'Salvar alterações' : 'Adicionar',
                        style: AppTextStyles.bodyBold(Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widgets auxiliares

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.label(color));
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppColors.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isSelected ? color : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.dmSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isDark;

  const _DropdownField({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint,
              style: AppTextStyles.body(isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight)),
          isExpanded: true,
          dropdownColor:
              isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final Color color;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final ValueChanged<bool> onChanged;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: value
            ? color.withOpacity(0.06)
            : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? color.withOpacity(0.4)
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyBold(textPrimary)),
                Text(subtitle, style: AppTextStyles.label(textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }
}