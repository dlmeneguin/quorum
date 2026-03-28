import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';

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
      if (c.color != null) _selectedColor = Color(c.color!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final db = ref.read(databaseProvider);

    final companion = CategoriesCompanion(
      id: widget.category != null
          ? Value(widget.category!.id)
          : const Value.absent(),
      name: Value(_nameController.text.trim()),
      type: Value(_selectedType),
      color: Value(_selectedColor.value),
      isDefault: const Value(false),
    );

    if (widget.category == null) {
      await db.categoriesDao.createCategory(companion);
    } else {
      await db.categoriesDao.updateCategory(companion);
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
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