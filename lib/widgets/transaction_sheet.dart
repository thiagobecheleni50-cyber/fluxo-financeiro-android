import 'package:material_ui/material_ui.dart';

import '../models/finance_models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'category_manager_sheet.dart';

class TransactionSheet extends StatefulWidget {
  const TransactionSheet({
    super.key,
    required this.initialType,
    required this.categories,
    required this.onAddCategory,
    required this.onDeleteCategory,
    this.existing,
  });

  final TransactionType initialType;
  final List<FinanceCategory> categories;
  final ValueChanged<FinanceCategory> onAddCategory;
  final ValueChanged<String> onDeleteCategory;
  final FinanceTransaction? existing;

  @override
  State<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<TransactionSheet> {
  late TransactionType _type;
  late String _selectedCategoryId;
  late DateTime _selectedDate;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late List<FinanceCategory> _localCategories;

  @override
  void initState() {
    super.initState();
    _localCategories = List<FinanceCategory>.from(widget.categories);
    _type = widget.existing?.type ?? widget.initialType;
    _selectedDate = widget.existing?.date ?? DateTime.now();
    _amountController = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.amount.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    _noteController = TextEditingController(text: widget.existing?.note ?? '');

    final matching = _categoriesFor(_type);
    if (widget.existing != null &&
        matching.any((c) => c.id == widget.existing!.categoryId)) {
      _selectedCategoryId = widget.existing!.categoryId;
    } else {
      _selectedCategoryId = matching.isNotEmpty ? matching.first.id : '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<FinanceCategory> _categoriesFor(TransactionType type) =>
      _localCategories.where((c) => c.type == type).toList();

  void _switchType(TransactionType newType) {
    if (_type == newType) return;
    setState(() {
      _type = newType;
      final cats = _categoriesFor(newType);
      _selectedCategoryId = cats.isNotEmpty ? cats.first.id : '';
    });
  }

  void _addQuickAmount(double delta) {
    final current = parseBrazilianAmount(_amountController.text) ?? 0;
    final next = current + delta;
    _amountController.text = next.toStringAsFixed(2).replaceAll('.', ',');
    setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Selecionar data',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _openCreateCategory() async {
    final created = await showModalBottomSheet<FinanceCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryManagerSheet(
        categories: _localCategories,
        initialType: _type,
        openCreateDirectly: true,
        onAddCategory: (cat) {
          widget.onAddCategory(cat);
          setState(() {
            _localCategories.add(cat);
          });
        },
        onDeleteCategory: widget.onDeleteCategory,
      ),
    );
    if (created != null && mounted) {
      setState(() {
        _type = created.type;
        _selectedCategoryId = created.id;
      });
    }
  }

  void _save() {
    final parsed = parseBrazilianAmount(_amountController.text);
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor válido maior que zero.'),
        ),
      );
      return;
    }

    if (_selectedCategoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria.')),
      );
      return;
    }

    final tx = FinanceTransaction(
      id: widget.existing?.id ??
          'tx_${DateTime.now().microsecondsSinceEpoch}',
      type: _type,
      categoryId: _selectedCategoryId,
      amount: double.parse(parsed.toStringAsFixed(2)),
      date: _selectedDate,
      note: _noteController.text.trim(),
    );

    Navigator.of(context).pop(tx);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final cats = _categoriesFor(_type);
    final isIncome = _type == TransactionType.income;
    final accentColor = isIncome ? AppColors.income : AppColors.expense;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existing != null
                        ? 'Editar Lançamento'
                        : (isIncome ? 'Nova Entrada' : 'Nova Saída'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Entrada / Saída switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _typePill(
                      label: 'Entrada (+)',
                      selected: isIncome,
                      activeColor: AppColors.income,
                      onTap: () => _switchType(TransactionType.income),
                    ),
                    _typePill(
                      label: 'Saída (−)',
                      selected: !isIncome,
                      activeColor: AppColors.expense,
                      onTap: () => _switchType(TransactionType.expense),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Valor (R\$)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: widget.existing == null,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  prefixText: 'R\$ ',
                  prefixStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: accentColor.withValues(alpha: 0.75),
                  ),
                  hintText: '0,00',
                  hintStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: AppColors.pageTop,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: accentColor, width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Quick increment pills
              Row(
                children: [50.0, 100.0, 250.0, 500.0].map((v) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: OutlinedButton(
                        onPressed: () => _addQuickAmount(v),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: const BorderSide(color: AppColors.border),
                          backgroundColor: AppColors.pageTop,
                          foregroundColor: AppColors.textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: Text(
                          '+${v.toInt()}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Categoria',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Flexible(
                    child: TextButton.icon(
                      onPressed: _openCreateCategory,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: const Text(
                        'Nova categoria',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...cats.map((cat) {
                    final selected = _selectedCategoryId == cat.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _selectedCategoryId = cat.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? cat.color.withValues(alpha: 0.16)
                              : AppColors.pageTop,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? cat.color : AppColors.border,
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat.icon,
                              size: 17,
                              color: selected
                                  ? cat.color
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  // Inline "+ Novo" chip
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _openCreateCategory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 17,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Adicionar',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Description & Date
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _noteController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Descrição (opcional)',
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.pageTop,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickDate,
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.pageTop,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  formatDateNumeric(_selectedDate),
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: isIncome
                        ? AppGradients.incomeAction
                        : AppGradients.expenseAction,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: Icon(
                      widget.existing != null
                          ? Icons.check_rounded
                          : (isIncome
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded),
                    ),
                    label: Text(
                      widget.existing != null
                          ? 'Salvar Alterações'
                          : (isIncome ? 'Salvar Entrada' : 'Salvar Saída'),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typePill({
    required String label,
    required bool selected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? activeColor : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
