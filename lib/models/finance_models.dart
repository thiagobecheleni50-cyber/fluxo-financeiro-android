import 'package:material_ui/material_ui.dart';

enum TransactionType { income, expense }

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.colorValue,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final TransactionType type;
  final String iconKey;
  final int colorValue;
  final bool isDefault;

  Color get color => Color(colorValue);
  IconData get icon => categoryIconFromKey(iconKey);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'iconKey': iconKey,
        'colorValue': colorValue,
        'isDefault': isDefault,
      };

  factory FinanceCategory.fromJson(Map<String, dynamic> json) {
    return FinanceCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      iconKey: (json['iconKey'] as String?) ?? 'category',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF0D9488,
      isDefault: (json['isDefault'] as bool?) ?? false,
    );
  }
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.categoryId,
    required this.amount,
    required this.date,
    this.note = '',
  });

  final String id;
  final TransactionType type;
  final String categoryId;
  final double amount;
  final DateTime date;
  final String note;

  FinanceTransaction copyWith({
    String? id,
    TransactionType? type,
    String? categoryId,
    double? amount,
    DateTime? date,
    String? note,
  }) {
    return FinanceTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'categoryId': categoryId,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    return FinanceTransaction(
      id: json['id'] as String,
      type: json['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      categoryId: json['categoryId'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      note: (json['note'] as String?) ?? '',
    );
  }
}

const Map<String, IconData> kCategoryIcons = {
  'wallet': Icons.account_balance_wallet_rounded,
  'trending_up': Icons.trending_up_rounded,
  'bolt': Icons.bolt_rounded,
  'credit_card': Icons.credit_card_rounded,
  'wifi': Icons.wifi_rounded,
  'gas': Icons.local_gas_station_rounded,
  'shopping': Icons.shopping_cart_rounded,
  'home': Icons.home_rounded,
  'restaurant': Icons.restaurant_rounded,
  'health': Icons.medical_services_rounded,
  'school': Icons.school_rounded,
  'directions_car': Icons.directions_car_rounded,
  'water': Icons.water_drop_rounded,
  'savings': Icons.savings_rounded,
  'celebration': Icons.celebration_rounded,
  'phone': Icons.smartphone_rounded,
  'pets': Icons.pets_rounded,
  'category': Icons.label_rounded,
};

IconData categoryIconFromKey(String key) =>
    kCategoryIcons[key] ?? Icons.label_rounded;

const List<int> kCategoryPalette = [
  0xFF0D9488, // Teal
  0xFF0891B2, // Cyan Teal
  0xFF0284C7, // Ocean Blue
  0xFF0F766E, // Deep Teal
  0xFF14B8A6, // Mint Teal
  0xFF2B8A9C, // Soft Petrol
  0xFFD97706, // Soft Amber
  0xFFDF6B72, // Soft Coral
  0xFF4F7CAC, // Steel Blue
  0xFF5A9A7F, // Sage Green
  0xFFC87D55, // Soft Terracotta
  0xFF5D7B9D, // Slate Blue
];

final List<FinanceCategory> kDefaultCategories = [
  // Entradas
  const FinanceCategory(
    id: 'cat_salarios',
    name: 'Salários',
    type: TransactionType.income,
    iconKey: 'wallet',
    colorValue: 0xFF0D9488,
    isDefault: true,
  ),
  const FinanceCategory(
    id: 'cat_renda_extra',
    name: 'Renda Extra',
    type: TransactionType.income,
    iconKey: 'trending_up',
    colorValue: 0xFF0891B2,
    isDefault: true,
  ),
  // Saídas
  const FinanceCategory(
    id: 'cat_energia',
    name: 'Energia',
    type: TransactionType.expense,
    iconKey: 'bolt',
    colorValue: 0xFFD9822B,
    isDefault: true,
  ),
  const FinanceCategory(
    id: 'cat_cartoes',
    name: 'Cartões de Crédito',
    type: TransactionType.expense,
    iconKey: 'credit_card',
    colorValue: 0xFFD96B72,
    isDefault: true,
  ),
  const FinanceCategory(
    id: 'cat_internet',
    name: 'Internet',
    type: TransactionType.expense,
    iconKey: 'wifi',
    colorValue: 0xFF0E87A8,
    isDefault: true,
  ),
  const FinanceCategory(
    id: 'cat_gasolina',
    name: 'Gasolina',
    type: TransactionType.expense,
    iconKey: 'gas',
    colorValue: 0xFF2F8F83,
    isDefault: true,
  ),
];
