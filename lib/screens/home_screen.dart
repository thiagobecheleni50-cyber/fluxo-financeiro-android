import 'package:material_ui/material_ui.dart';

import '../models/finance_models.dart';
import '../services/finance_storage.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/category_manager_sheet.dart';
import '../widgets/percentage_donut_chart.dart';
import '../widgets/transaction_sheet.dart';

enum _PeriodMode { month, all }

enum _ChartMode { expenses, incomes, flow }

enum _ListFilter { all, income, expense }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FinanceStorage _storage = FinanceStorage();

  List<FinanceCategory> _categories = List<FinanceCategory>.from(
    kDefaultCategories,
  );
  List<FinanceTransaction> _transactions = [];
  bool _loading = true;

  _PeriodMode _periodMode = _PeriodMode.month;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  _ChartMode _chartMode = _ChartMode.expenses;
  _ListFilter _listFilter = _ListFilter.all;
  String? _selectedSliceId;
  bool _hideValues = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cats = await _storage.loadCategories();
    final txs = await _storage.loadTransactions();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _transactions = txs..sort((a, b) => b.date.compareTo(a.date));
      _loading = false;
    });
  }

  Future<void> _persistTransactions() async {
    await _storage.saveTransactions(_transactions);
  }

  Future<void> _persistCategories() async {
    await _storage.saveCategories(_categories);
  }

  FinanceCategory _categoryFor(String categoryId, TransactionType fallbackType) {
    return _categories.where((c) => c.id == categoryId).firstOrNull ??
        FinanceCategory(
          id: categoryId,
          name: fallbackType == TransactionType.income ? 'Entrada' : 'Outros',
          type: fallbackType,
          iconKey: 'category',
          colorValue: fallbackType == TransactionType.income
              ? AppColors.income.toARGB32()
              : AppColors.expense.toARGB32(),
        );
  }

  List<FinanceTransaction> get _periodTransactions {
    if (_periodMode == _PeriodMode.all) {
      return _transactions;
    }
    return _transactions
        .where(
          (t) =>
              t.date.year == _selectedMonth.year &&
              t.date.month == _selectedMonth.month,
        )
        .toList();
  }

  List<FinanceTransaction> get _filteredTransactions {
    final base = _periodTransactions;
    switch (_listFilter) {
      case _ListFilter.all:
        return base;
      case _ListFilter.income:
        return base.where((t) => t.type == TransactionType.income).toList();
      case _ListFilter.expense:
        return base.where((t) => t.type == TransactionType.expense).toList();
    }
  }

  double get _totalIncome => _periodTransactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _totalExpense => _periodTransactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _balance => _totalIncome - _totalExpense;

  List<ChartSlice> _buildChartSlices() {
    if (_chartMode == _ChartMode.flow) {
      final total = _totalIncome + _totalExpense;
      if (total <= 0) return [];
      final slices = <ChartSlice>[];
      if (_totalIncome > 0) {
        slices.add(
          ChartSlice(
            id: 'flow_income',
            label: 'Entradas',
            value: _totalIncome,
            percent: (_totalIncome / total) * 100,
            color: AppColors.income,
            icon: Icons.arrow_upward_rounded,
          ),
        );
      }
      if (_totalExpense > 0) {
        slices.add(
          ChartSlice(
            id: 'flow_expense',
            label: 'Saídas',
            value: _totalExpense,
            percent: (_totalExpense / total) * 100,
            color: AppColors.expense,
            icon: Icons.arrow_downward_rounded,
          ),
        );
      }
      return slices;
    }

    final targetType = _chartMode == _ChartMode.expenses
        ? TransactionType.expense
        : TransactionType.income;
    final items = _periodTransactions
        .where((t) => t.type == targetType)
        .toList();
    final total = items.fold(0.0, (sum, t) => sum + t.amount);
    if (total <= 0) return [];

    final Map<String, double> sums = {};
    for (final tx in items) {
      sums[tx.categoryId] = (sums[tx.categoryId] ?? 0) + tx.amount;
    }

    final entries = sums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.map((entry) {
      final cat = _categoryFor(entry.key, targetType);
      return ChartSlice(
        id: cat.id,
        label: cat.name,
        value: entry.value,
        percent: (entry.value / total) * 100,
        color: cat.color,
        icon: cat.icon,
      );
    }).toList();
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
      _selectedSliceId = null;
    });
  }

  Future<void> _openTransactionSheet({
    required TransactionType initialType,
    FinanceTransaction? existing,
  }) async {
    final result = await showModalBottomSheet<FinanceTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionSheet(
        initialType: initialType,
        categories: _categories,
        existing: existing,
        onAddCategory: _handleAddCategory,
        onDeleteCategory: _handleDeleteCategory,
      ),
    );

    if (result == null) return;

    setState(() {
      if (existing != null) {
        final idx = _transactions.indexWhere((t) => t.id == existing.id);
        if (idx >= 0) {
          _transactions[idx] = result;
        }
      } else {
        _transactions.insert(0, result);
        // Jump to the transaction's month if in month mode so user sees it right away
        if (_periodMode == _PeriodMode.month) {
          _selectedMonth = DateTime(result.date.year, result.date.month);
        }
      }
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      _selectedSliceId = null;
    });
    await _persistTransactions();
  }

  Future<void> _openCategoryManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryManagerSheet(
        categories: _categories,
        onAddCategory: _handleAddCategory,
        onDeleteCategory: _handleDeleteCategory,
      ),
    );
  }

  void _handleAddCategory(FinanceCategory cat) {
    setState(() {
      _categories.add(cat);
    });
    _persistCategories();
  }

  void _handleDeleteCategory(String id) {
    setState(() {
      _categories.removeWhere((c) => c.id == id && !c.isDefault);
    });
    _persistCategories();
  }

  Future<void> _deleteTransaction(FinanceTransaction tx) async {
    final removedIndex = _transactions.indexWhere((t) => t.id == tx.id);
    if (removedIndex < 0) return;

    setState(() {
      _transactions.removeAt(removedIndex);
      _selectedSliceId = null;
    });
    await _persistTransactions();

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Lançamento excluído (${formatCurrency(tx.amount)}).',
        ),
        action: SnackBarAction(
          label: 'Desfazer',
          textColor: const Color(0xFF6FE3D8),
          onPressed: () async {
            setState(() {
              _transactions.insert(
                removedIndex.clamp(0, _transactions.length),
                tx,
              );
              _transactions.sort((a, b) => b.date.compareTo(a.date));
            });
            await _persistTransactions();
          },
        ),
      ),
    );
  }

  Future<void> _loadSampleData() async {
    final samples = FinanceStorage.buildSampleTransactions(_selectedMonth);
    setState(() {
      _transactions.addAll(samples);
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      _selectedSliceId = null;
    });
    await _persistTransactions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dados de exemplo carregados. Você pode editar ou excluir.'),
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    if (_transactions.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Limpar movimentações?'),
        content: const Text(
          'Todas as entradas e saídas cadastradas serão removidas deste aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Limpar tudo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _transactions.clear();
        _selectedSliceId = null;
      });
      await _persistTransactions();
    }
  }

  String _displayAmount(double value, {bool showSign = false}) {
    if (_hideValues) return 'R\$ •••••';
    return formatCurrency(value, showSign: showSign);
  }

  @override
  Widget build(BuildContext context) {
    final slices = _buildChartSlices();
    final chartTotal = slices.fold(0.0, (sum, s) => sum + s.value);
    final commitmentRatio = _totalIncome > 0
        ? (_totalExpense / _totalIncome).clamp(0.0, 1.0)
        : (_totalExpense > 0 ? 1.0 : 0.0);
    final commitmentPct = _totalIncome > 0
        ? (_totalExpense / _totalIncome) * 100
        : (_totalExpense > 0 ? 100.0 : 0.0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.pageBackground),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildHeader(),
                          const SizedBox(height: 16),
                          _buildPeriodBar(),
                          const SizedBox(height: 16),
                          _buildHeroBalanceCard(
                            commitmentRatio: commitmentRatio,
                            commitmentPct: commitmentPct,
                          ),
                          const SizedBox(height: 16),
                          _buildActionButtons(),
                          const SizedBox(height: 20),
                          _buildPercentageChartCard(
                            slices: slices,
                            chartTotal: chartTotal,
                          ),
                          const SizedBox(height: 20),
                          _buildTransactionsCard(),
                        ]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppGradients.heroCard,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealMid.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fluxo Financeiro',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Acompanhamento de dinheiro',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _openCategoryManager,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Text(
                  'Categorias',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _periodToggleChip(
                  label: 'Mês',
                  selected: _periodMode == _PeriodMode.month,
                  onTap: () => setState(() {
                    _periodMode = _PeriodMode.month;
                    _selectedSliceId = null;
                  }),
                ),
                _periodToggleChip(
                  label: 'Total',
                  selected: _periodMode == _PeriodMode.all,
                  onTap: () => setState(() {
                    _periodMode = _PeriodMode.all;
                    _selectedSliceId = null;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _periodMode == _PeriodMode.month
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _smallIconBtn(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => _changeMonth(-1),
                      ),
                      Expanded(
                        child: Text(
                          formatMonthYear(_selectedMonth),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _smallIconBtn(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => _changeMonth(1),
                      ),
                    ],
                  )
                : const Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Text(
                        'Fluxo total acumulado',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _periodToggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.tealDeep.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _smallIconBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.pageTop,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
    );
  }

  Widget _buildHeroBalanceCard({
    required double commitmentRatio,
    required double commitmentPct,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.heroCard,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDeep.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _periodMode == _PeriodMode.month
                    ? 'Saldo do mês'
                    : 'Saldo total',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _hideValues = !_hideValues),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _hideValues
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _displayAmount(_balance),
            style: const TextStyle(
              fontSize: 33,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _heroMetricTile(
                  icon: Icons.arrow_upward_rounded,
                  iconBg: const Color(0xFF4CE0CF).withValues(alpha: 0.22),
                  iconColor: const Color(0xFFB5FFF6),
                  label: 'Entradas',
                  value: _displayAmount(_totalIncome),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _heroMetricTile(
                  icon: Icons.arrow_downward_rounded,
                  iconBg: const Color(0xFFFFB4B8).withValues(alpha: 0.22),
                  iconColor: const Color(0xFFFFD6D8),
                  label: 'Saídas',
                  value: _displayAmount(_totalExpense),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Commitment / Cash-flow bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Comprometimento das entradas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatPercent(commitmentPct),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: commitmentRatio,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                commitmentPct > 85
                    ? const Color(0xFFFFC1C4)
                    : const Color(0xFF9DF7EC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetricTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _gradientActionButton(
            label: 'Entrada',
            subtitle: 'Adicionar ganho',
            icon: Icons.add_circle_rounded,
            gradient: AppGradients.incomeAction,
            shadowColor: AppColors.income,
            onTap: () => _openTransactionSheet(
              initialType: TransactionType.income,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _gradientActionButton(
            label: 'Saída',
            subtitle: 'Adicionar gasto',
            icon: Icons.remove_circle_rounded,
            gradient: AppGradients.expenseAction,
            shadowColor: AppColors.expense,
            onTap: () => _openTransactionSheet(
              initialType: TransactionType.expense,
            ),
          ),
        ),
      ],
    );
  }

  Widget _gradientActionButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPercentageChartCard({
    required List<ChartSlice> slices,
    required double chartTotal,
  }) {
    final centerSubtitle = switch (_chartMode) {
      _ChartMode.expenses => 'Total Saídas',
      _ChartMode.incomes => 'Total Entradas',
      _ChartMode.flow => 'Fluxo Total',
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDeep.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Gráfico em Porcentagem',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_selectedSliceId != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _selectedSliceId = null),
                  child: const Text(
                    'Limpar seleção',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Chart mode switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _chartTab('Saídas %', _ChartMode.expenses),
                _chartTab('Entradas %', _ChartMode.incomes),
                _chartTab('Fluxo %', _ChartMode.flow),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (slices.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.pageTop,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.donut_large_rounded,
                    size: 40,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Nenhum dado neste período ainda',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Adicione uma entrada ou saída para ver a porcentagem por categoria.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Center(
              child: PercentageDonutChart(
                slices: slices,
                total: chartTotal,
                centerSubtitle: centerSubtitle,
                selectedId: _selectedSliceId,
                onSelect: (id) => setState(() => _selectedSliceId = id),
              ),
            ),
            const SizedBox(height: 18),
            ...slices.map((slice) {
              final selected = _selectedSliceId == slice.id;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() {
                  _selectedSliceId = selected ? null : slice.id;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? slice.color.withValues(alpha: 0.1)
                        : AppColors.pageTop,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? slice.color : AppColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: slice.color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              slice.icon,
                              size: 17,
                              color: slice.color,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              slice.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            _displayAmount(slice.value),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: slice.color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              formatPercent(slice.percent),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: slice.color,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (slice.percent / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: Colors.white,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            slice.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _chartTab(String label, _ChartMode mode) {
    final selected = _chartMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _chartMode = mode;
          _selectedSliceId = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.tealDeep.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsCard() {
    final items = _filteredTransactions;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDeep.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Fluxo de Movimentações',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_transactions.isNotEmpty)
                TextButton(
                  onPressed: _confirmClearAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(
                    'Limpar',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Filter chips
          Row(
            children: [
              _filterChip('Todos', _ListFilter.all),
              const SizedBox(width: 8),
              _filterChip('Entradas', _ListFilter.income),
              const SizedBox(width: 8),
              _filterChip('Saídas', _ListFilter.expense),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.pageTop,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    size: 38,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nenhuma movimentação registrada',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Use os botões Entrada ou Saída acima para começar seu controle.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (_transactions.isEmpty) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _loadSampleData,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                      label: const Text(
                        'Carregar exemplo para testar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final tx = items[index];
                final cat = _categoryFor(tx.categoryId, tx.type);
                final isIncome = tx.type == TransactionType.income;

                return Dismissible(
                  key: ValueKey(tx.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 18),
                    decoration: BoxDecoration(
                      color: AppColors.expense,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (_) => _deleteTransaction(tx),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openTransactionSheet(
                      initialType: tx.type,
                      existing: tx,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pageTop,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: cat.color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(cat.icon, size: 20, color: cat.color),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tx.note.isNotEmpty
                                      ? '${tx.note} • ${formatDateShort(tx.date)}'
                                      : formatDateShort(tx.date),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _displayAmount(
                                  isIncome ? tx.amount : -tx.amount,
                                  showSign: true,
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isIncome
                                      ? AppColors.income
                                      : AppColors.expense,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => _deleteTransaction(tx),
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                            ),
                            color: AppColors.textMuted,
                            tooltip: 'Excluir lançamento',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _ListFilter filter) {
    final selected = _listFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _listFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.pageTop,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
