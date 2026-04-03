import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  final Account? account; // null = criação, preenchido = edição

  const AccountFormScreen({super.key, this.account});

  @override
  ConsumerState<AccountFormScreen> createState() =>
      _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();

  String _selectedType = 'checking';
  Color _selectedColor = AppColors.primary;
  bool _isSaving = false;

  final _types = [
    ('checking', 'Conta Corrente', Icons.account_balance_outlined),
    ('savings', 'Poupança', Icons.savings_outlined),
    ('cash', 'Carteira', Icons.wallet_outlined),
    ('credit', 'Cartão de Crédito', Icons.credit_card_outlined),
  ];

  final _colors = [
    AppColors.primary,
    const Color(0xFF6366F1),
    AppColors.accent,
    AppColors.danger,
    AppColors.success,
    const Color(0xFF8B5CF6),
    const Color(0xFF0EA5E9),
    const Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      final a = widget.account!;
      _nameController.text = a.name;
      _balanceController.text =
          CurrencyUtils.format(a.initialBalance);
      _selectedType = a.type;
      if (a.color != null) _selectedColor = Color(a.color!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final db = ref.read(databaseProvider);
    final amount =
        CurrencyUtils.parse(_balanceController.text) ?? 0.0;

    final companion = AccountsCompanion(
      id: widget.account != null
          ? Value(widget.account!.id)
          : Value(AppDatabase.newId()),
      name: Value(_nameController.text.trim()),
      type: Value(_selectedType),
      initialBalance: Value(amount),
      color: Value(_selectedColor.value),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );

    if (widget.account == null) {
      await db.accountsDao.createAccount(companion);
    } else {
      await db.accountsDao.updateAccount(companion);
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
    final isEditing = widget.account != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Conta' : 'Nova Conta',
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
            _SectionLabel('Nome da conta', textSecondary),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              validator: Validators.required,
              decoration: const InputDecoration(
                hintText: 'Ex: Nubank, Bradesco, Carteira...',
              ),
              style: AppTextStyles.body(textPrimary),
            ),
            const SizedBox(height: 24),

            // Tipo de conta
            _SectionLabel('Tipo de conta', textSecondary),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final (value, label, icon) = t;
                final isSelected = _selectedType == value;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedType = value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLight
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 16,
                            color: isSelected
                                ? AppColors.primary
                                : textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: AppTextStyles.dmSans(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? AppColors.primary
                                : textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Saldo inicial
            _SectionLabel('Saldo inicial', textSecondary),
            const SizedBox(height: 8),
            TextFormField(
              controller: _balanceController,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final parsed = CurrencyUtils.parse(v);
                if (parsed == null) return 'Valor inválido';
                return null;
              },
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: const InputDecoration(
                hintText: 'R\$ 0,00',
                prefixText: 'R\$ ',
              ),
              style: AppTextStyles.body(textPrimary),
            ),
            const SizedBox(height: 24),

            // Cor
            _SectionLabel('Cor de identificação', textSecondary),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: color,
                              width: 3,
                            )
                          : null,
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
                        isEditing ? 'Salvar alterações' : 'Criar conta',
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

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.label(color),
    );
  }
}