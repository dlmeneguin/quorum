import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../core/services/sync_service_provider.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  final Category? category;

  const CategoryFormScreen({super.key, this.category});

  @override
  ConsumerState<CategoryFormScreen> createState() =>
      _CategoryFormScreenState();
}

class _CategoryFormScreenState
    extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _selectedType = 'expense';
  Color _selectedColor = AppColors.danger;
  // Cor customizada escolhida pelo usuário (null = nenhuma)
  Color? _customColor;
  bool _isSaving = false;

  final _colors = [
    AppColors.danger,
    AppColors.success,
    AppColors.primary,
    AppColors.accent,
    const Color(0xFF6366F1),
    const Color(0xFF8B5CF6),
    const Color(0xFF0EA5E9),
    const Color(0xFFEC4899),
    const Color(0xFF6B7280),
    const Color(0xFFF97316),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      final c = widget.category!;
      _nameController.text = c.name;
      _selectedType = c.type;
      if (c.color != null) {
        final savedColor = Color(c.color!);
        // Verifica se a cor salva está na paleta padrão
        final isDefault = _colors.any((col) => col.value == savedColor.value);
        if (isDefault) {
          _selectedColor = savedColor;
        } else {
          // Cor customizada — exibe ela e marca como customizada
          _customColor = savedColor;
          _selectedColor = savedColor;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Abre o diálogo de seleção de cor customizada
  Future<void> _openColorPicker() async {
    // Inicializa com a cor customizada atual ou uma cor de base
    Color tempColor = _customColor ?? const Color(0xFF1A6B4A);

    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surfaceColor =
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

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
                            255,
                            v.round(),
                            tempColor.green,
                            tempColor.blue,
                          )),
                    ),
                    const SizedBox(height: 8),
                    _ColorSlider(
                      label: 'G',
                      value: tempColor.green.toDouble(),
                      color: Colors.green,
                      onChanged: (v) => setS(() => tempColor = Color.fromARGB(
                            255,
                            tempColor.red,
                            v.round(),
                            tempColor.blue,
                          )),
                    ),
                    const SizedBox(height: 8),
                    _ColorSlider(
                      label: 'B',
                      value: tempColor.blue.toDouble(),
                      color: Colors.blue,
                      onChanged: (v) => setS(() => tempColor = Color.fromARGB(
                            255,
                            tempColor.red,
                            tempColor.green,
                            v.round(),
                          )),
                    ),
                    const SizedBox(height: 16),
                    // Grade de cores pré-definidas adicionais
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
    setState(() => _isSaving = true);

    final db = ref.read(databaseProvider);

    final companion = CategoriesCompanion(
      id: widget.category != null
          ? Value(widget.category!.id)
          : Value(AppDatabase.newId()),
      name: Value(_nameController.text.trim()),
      type: Value(_selectedType),
      color: Value(_selectedColor.value),
      isDefault: const Value(false),
      createdAt: widget.category == null
          ? Value(DateTime.now().millisecondsSinceEpoch)
          : const Value.absent(),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );

    if (widget.category == null) {
      await db.categoriesDao.createCategory(companion);
    } else {
      await db.categoriesDao.updateCategory(companion);
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
    final isEditing = widget.category != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Categoria' : 'Nova Categoria',
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
              Text('Nome da categoria',
                  style: AppTextStyles.label(textSecondary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                validator: Validators.required,
                decoration: const InputDecoration(
                  hintText: 'Ex: Alimentação, Salário...',
                ),
                style: AppTextStyles.body(textPrimary),
              ),
              const SizedBox(height: 24),

              // Tipo
              Text('Tipo', style: AppTextStyles.label(textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: 'Despesa',
                      icon: Icons.arrow_upward_rounded,
                      color: AppColors.danger,
                      isSelected: _selectedType == 'expense',
                      onTap: () =>
                          setState(() => _selectedType = 'expense'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TypeButton(
                      label: 'Receita',
                      icon: Icons.arrow_downward_rounded,
                      color: AppColors.success,
                      isSelected: _selectedType == 'income',
                      onTap: () =>
                          setState(() => _selectedType = 'income'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Cor
              Text('Cor', style: AppTextStyles.label(textSecondary)),
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
                      onTap: () => setState(() {
                        _selectedColor = color;
                        // Não limpa _customColor para ela continuar aparecendo
                      }),
                    );
                  }),

                  // Cor customizada (se existir, aparece persistentemente)
                  if (_customColor != null) ...[
                    _ColorCircle(
                      color: _customColor!,
                      isSelected: _selectedColor.value == _customColor!.value,
                      onTap: () => setState(() => _selectedColor = _customColor!),
                      isCustom: false,
                    ),
                  ],

                  // Botão para abrir o picker
                  _CustomColorButton(onTap: _openColorPicker),
                ],
              ),
              const SizedBox(height: 16),

              // Preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectedColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _selectedColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _selectedColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.circle,
                          color: _selectedColor, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _nameController.text.isEmpty
                          ? 'Prévia da categoria'
                          : _nameController.text,
                      style: AppTextStyles.bodyBold(textPrimary),
                    ),
                  ],
                ),
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
                          isEditing
                              ? 'Salvar alterações'
                              : 'Criar categoria',
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
  final bool isCustom;

  const _ColorCircle({
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.isCustom = false,
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppColors.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodyBold(
                  isSelected ? color : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}