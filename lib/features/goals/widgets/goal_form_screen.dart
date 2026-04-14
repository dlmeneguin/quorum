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
import '../../../core/services/sync_service_provider.dart';

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
  String? _selectedAccountId;
  Color _selectedColor = AppColors.accent;
  // Cor customizada (null = nenhuma selecionada ainda)
  Color? _customColor;
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
      if (g.color != null) {
        final savedColor = Color(g.color!);
        final isDefault = _colors.any((col) => col.value == savedColor.value);
        if (isDefault) {
          _selectedColor = savedColor;
        } else {
          _customColor = savedColor;
          _selectedColor = savedColor;
        }
      }
      if (g.targetDate != null) {
        _targetDate = DateTime.fromMillisecondsSinceEpoch(g.targetDate!);
      }
    }

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

  /// Abre o diálogo de seleção de cor customizada
  Future<void> _openColorPicker() async {
    Color tempColor = _customColor ?? const Color(0xFFF0A500);

    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: const Text('Cor personalizada'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Preview da cor
                    Container(
                      height: 56,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: tempColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '#${tempColor.value.toRadixString(16).substring(2).toUpperCase()}',
                          style: AppTextStyles.bodyBold(Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Sliders RGB
                    _ColorSlider(
                      label: 'R',
                      value: tempColor.red.toDouble(),
                      color: Colors.red,
                      onChanged: (v) => setS(() => tempColor = Color.fromARGB(
                            255, v.round(), tempColor.green, tempColor.blue)),
                    ),
                    const SizedBox(height: 8),
                    _ColorSlider(
                      label: 'G',
                      value: tempColor.green.toDouble(),
                      color: Colors.green,
                      onChanged: (v) => setS(() => tempColor = Color.fromARGB(
                            255, tempColor.red, v.round(), tempColor.blue)),
                    ),
                    const SizedBox(height: 8),
                    _ColorSlider(
                      label: 'B',
                      value: tempColor.blue.toDouble(),
                      color: Colors.blue,
                      onChanged: (v) => setS(() => tempColor = Color.fromARGB(
                            255, tempColor.red, tempColor.green, v.round())),
                    ),
                    const SizedBox(height: 16),
                    // Grade de cores adicionais
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const Color(0xFF9C27B0),
                        const Color(0xFF3F51B5),
                        const Color(0xFF009688),
                        const Color(0xFF4CAF50),
                        const Color(0xFFFF9800),
                        const Color(0xFF795548),
                        const Color(0xFF607D8B),
                        const Color(0xFFE91E63),
                        const Color(0xFF00BCD4),
                        const Color(0xFFCDDC39),
                        const Color(0xFFFF5722),
                        const Color(0xFF673AB7),
                      ].map((c) => GestureDetector(
                            onTap: () => setS(() => tempColor = c),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: tempColor.value == c.value
                                    ? Border.all(
                                        color: Colors.white, width: 2)
                                    : null,
                                boxShadow: tempColor.value == c.value
                                    ? [
                                        BoxShadow(
                                          color: c.withOpacity(0.5),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: tempColor.value == c.value
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 16)
                                  : null,
                            ),
                          )).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, tempColor),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _customColor = result;
        _selectedColor = result;
      });
    }
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
          : Value(AppDatabase.newId()),
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
      updatedAt: Value(now),
    );

    if (widget.goal == null) {
      await db.goalsDao.createGoal(companion);
    } else {
      await db.goalsDao.updateGoal(companion);
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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                    child: DropdownButton<String>(
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
                          .map((a) => DropdownMenuItem<String>(
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

              // Cor de identificação
              Text('Cor de identificação',
                  style: AppTextStyles.label(textSecondary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  // Cores padrão
                  ..._colors.map((color) {
                    final isSelected = _selectedColor.value == color.value &&
                        _customColor?.value != color.value;
                    return _ColorCircle(
                      color: color,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedColor = color),
                    );
                  }),

                  // Cor customizada persistente (se existir)
                  if (_customColor != null)
                    _ColorCircle(
                      color: _customColor!,
                      isSelected:
                          _selectedColor.value == _customColor!.value,
                      onTap: () =>
                          setState(() => _selectedColor = _customColor!),
                    ),

                  // Botão picker
                  _CustomColorButton(onTap: _openColorPicker),
                ],
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
      ),
    );
  }
}

// ── Widgets auxiliares ──

class _ColorCircle extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorCircle({
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
          border: isSelected
              ? Border.all(color: Colors.white, width: 2)
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : null,
      ),
    );
  }
}

class _CustomColorButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CustomColorButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.5,
          ),
          gradient: const SweepGradient(
            colors: [
              Color(0xFFFF0000),
              Color(0xFFFFFF00),
              Color(0xFF00FF00),
              Color(0xFF00FFFF),
              Color(0xFF0000FF),
              Color(0xFFFF00FF),
              Color(0xFFFF0000),
            ],
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.edit,
            size: 14,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}

class _ColorSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  const _ColorSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(label,
              style: AppTextStyles.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
              overlayColor: color.withOpacity(0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 255,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            value.round().toString(),
            style: AppTextStyles.dmSans(fontSize: 11),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}