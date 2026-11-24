import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/finance_models.dart';

class FinanceStorage {
  static const String _txKey = 'fluxo_transactions_v1';
  static const String _catKey = 'fluxo_categories_v1';

  Future<List<FinanceCategory>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_catKey);
    if (raw == null || raw.isEmpty) {
      return List<FinanceCategory>.from(kDefaultCategories);
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final loaded = decoded
          .map((e) => FinanceCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      // Ensure all default categories exist even after upgrades
      final existingIds = loaded.map((c) => c.id).toSet();
      for (final def in kDefaultCategories) {
        if (!existingIds.contains(def.id)) {
          loaded.add(def);
        }
      }
      return loaded;
    } catch (_) {
      return List<FinanceCategory>.from(kDefaultCategories);
    }
  }

  Future<void> saveCategories(List<FinanceCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(categories.map((c) => c.toJson()).toList());
    await prefs.setString(_catKey, encoded);
  }

  Future<List<FinanceTransaction>> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_txKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => FinanceTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTransactions(List<FinanceTransaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(transactions.map((t) => t.toJson()).toList());
    await prefs.setString(_txKey, encoded);
  }

  static List<FinanceTransaction> buildSampleTransactions(DateTime anchor) {
    final year = anchor.year;
    final month = anchor.month;
    DateTime day(int d) => DateTime(year, month, d.clamp(1, 28), 10, 0);

    return [
      FinanceTransaction(
        id: 'sample_1',
        type: TransactionType.income,
        categoryId: 'cat_salarios',
        amount: 4200.00,
        date: day(5),
        note: 'Salário mensal',
      ),
      FinanceTransaction(
        id: 'sample_2',
        type: TransactionType.income,
        categoryId: 'cat_renda_extra',
        amount: 850.00,
        date: day(12),
        note: 'Serviço extra / freelance',
      ),
      FinanceTransaction(
        id: 'sample_3',
        type: TransactionType.expense,
        categoryId: 'cat_cartoes',
        amount: 1180.00,
        date: day(10),
        note: 'Fatura principal do mês',
      ),
      FinanceTransaction(
        id: 'sample_4',
        type: TransactionType.expense,
        categoryId: 'cat_gasolina',
        amount: 420.00,
        date: day(14),
        note: 'Abastecimentos da semana',
      ),
      FinanceTransaction(
        id: 'sample_5',
        type: TransactionType.expense,
        categoryId: 'cat_energia',
        amount: 265.50,
        date: day(16),
        note: 'Conta de energia elétrica',
      ),
      FinanceTransaction(
        id: 'sample_6',
        type: TransactionType.expense,
        categoryId: 'cat_internet',
        amount: 129.90,
        date: day(18),
        note: 'Internet fibra residencial',
      ),
    ];
  }
}
