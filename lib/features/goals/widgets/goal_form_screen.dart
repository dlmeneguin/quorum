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
import '../../accounts/providers/accounts_provider.dart';

class GoalFormScreen extends ConsumerStatefulWidget {
  final Goal? goal;

  const GoalFormScreen({super.key, this.goal});

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  int _amountCents = 0;

  DateTime? _targetDate;
  int? _selectedAccountId;
  Color _selectedColor = AppColors.accent;
  bool _isSaving = false;

  final _colors = [
    AppColors.accent,
    AppColors.primary,
    AppColors.success,
    AppColors.danger,
    const Color(0xFF6366F1),
    const Color(0xFF8B5CF6),
    const Color(0xFF0EA5E9),
    const Color(0xFFEC4899),
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
    if (widget.goal != null) {
      final g = widget.goal!;
      _nameController.text = g.name;
      _amountCents = (g.targetAmount * 100).round();
      _amountController.text = _formatCents(_amountCents);
      _selectedAccountId = g.accountId;
      if (g.color != null) _selectedColor = Color(g.color!);
      if (g.targetDate != null) {
        _targetDate = DateTime.fromMillisecondsSinceEpoch(g.targetDate!);
      }
    }
    
    // Auto-seleciona a conta se houver apenas uma cadastrada
    if (widget.goal == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final accounts = ref.read(accountsProvider);
        accounts.whenData((list) {
          if (list.length == 1 && _selectedAccountId == null) {
            setState(() => _selectedAccountId = list.first.id);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(now.year, now.month + 6),
      firstDate: DateTime(now.year, now.month + 1),
      lastDate: DateTime(now.year + 20),
      locale: const Locale('pt', 'BR'),
      helpText: 'Selecione a data alvo',
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor alvo maior que zero'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma conta para associar à meta'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);
    final amount = _amountCents / 100;
    final now = DateTime.now().millisecondsSinceEpoch;

    final companion = GoalsCompanion(
      id: widget.goal != null
          ? Value(widget.goal!.id)
          : const Value.absent(),
      name: Value(_nameController.text.trim()),
      targetAmount: Value(amount),
      currentAmount: widget.goal != null
          ? Value(widget.goal!.currentAmount)
          : const Value.absent(),
      targetDate: Value(
          _targetDate != null ? _targetDate!.millisecondsSinceEpoch : null),
      accountId: Value(_selectedAccountId),
      color: Value(_selectedColor.value),
      status: widget.goal != null
          ? Value(widget.goal!.status)
          : const Value.absent(),
      createdAt: widget.goal != null
          ? Value(widget.goal!.createdAt)
          : Value(now),
    );

    if (widget.goal == null) {
      await db.goalsDao.createGoal(companion);
    } else {
      await db.goalsDao.updateGoal(companion);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final isEditing = widget.goal != null;
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Meta' : 'Nova Meta',
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
            // Nome
            Text('Nome da meta', style: AppTextStyles.label(textSecondary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              validator: Validators.required,
              decoration: const InputDecoration(
                hintText: 'Ex: Viagem ao Japão, Reserva de emergência...',
              ),
              style: AppTextStyles.body(textPrimary),
            ),
            const SizedBox(height: 24),

            // Valor alvo
            Text('Valor alvo', style: AppTextStyles.label(textSecondary)),
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
                    style: AppTextStyles.bodyBold(_selectedColor),
                  ),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
              style: AppTextStyles.splineSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _selectedColor,
              ),
            ),
            const SizedBox(height: 24),

            // Data alvo (opcional)
            Text('Data alvo (opcional)',
                style: AppTextStyles.label(textSecondary)),
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
                    color:
                        isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 18, color: textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _targetDate != null
                            ? AppDateUtils.toFullDate(_targetDate!)
                            : 'Sem data definida',
                        style: AppTextStyles.body(
                          _targetDate != null ? textPrimary : textSecondary,
                        ),
                      ),
                    ),
                    if (_targetDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _targetDate = null),
                        child: Icon(Icons.close,
                            size: 18, color: textSecondary),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Conta vinculada (obrigatória)
            Text('Conta vinculada *',
                style: AppTextStyles.label(textSecondary)),
            const SizedBox(height: 8),
            accountsAsync.when(
              data: (accounts) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedAccountId,
                    hint: Text(
                      'Selecione uma conta',
                      style: AppTextStyles.body(textSecondary),
                    ),
                    isExpanded: true,
                    dropdownColor: isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    onChanged: (v) =>
                        setState(() => _selectedAccountId = v),
                    items: accounts
                        .map((a) => DropdownMenuItem<int>(
                              value: a.id,
                              child: Text(a.name,
                                  style: AppTextStyles.body(textPrimary)),
                            ))
                        .toList(),
                  ),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // Cor
            Text('Cor de identificação',
                style: AppTextStyles.label(textSecondary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

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
                        isEditing ? 'Salvar alterações' : 'Criar meta',
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