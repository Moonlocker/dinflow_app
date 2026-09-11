import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../../models/category.dart';
import '../../../models/goal.dart';
import '../../../models/transaction.dart';
import '../../../repositories/categories_repository.dart';
import '../../../repositories/goals_repository.dart';
import '../../../repositories/transactions_repository.dart';

/// Total acumulado por categoria, usado nos gráficos do dashboard/relatórios.
class CategoryTotal {
  const CategoryTotal({required this.category, required this.total});

  final Category category;
  final double total;
}

/// Fonte única de transações, metas e categorias do usuário.
///
/// Concentra os cálculos do dashboard e as operações de CRUD, evitando
/// duplicar estado entre as telas de Início, Transações e Metas.
class FinanceProvider extends ChangeNotifier {
  FinanceProvider({
    TransactionsRepository? transactionsRepository,
    GoalsRepository? goalsRepository,
    CategoriesRepository? categoriesRepository,
  })  : _transactions = transactionsRepository ?? TransactionsRepository(),
        _goals = goalsRepository ?? GoalsRepository(),
        _categories = categoriesRepository ?? CategoriesRepository();

  final TransactionsRepository _transactions;
  final GoalsRepository _goals;
  final CategoriesRepository _categories;

  String? _userId;
  List<Transaction> _allTransactions = [];
  List<Goal> _allGoals = [];
  List<Category> _allCategories = [];
  DateTime _currentDate = DateTime.now();
  bool _loading = false;
  String? _error;

  List<Transaction> get transactions => _allTransactions;
  List<Goal> get goals => _allGoals;
  List<Category> get categories => _allCategories;
  DateTime get currentDate => _currentDate;
  bool get loading => _loading;
  String? get error => _error;
  String? get userId => _userId;
  bool get hasData =>
      _allTransactions.isNotEmpty || _allGoals.isNotEmpty || _allCategories.isNotEmpty;

  Future<void> load(String userId, {bool force = false}) async {
    if (_loading) return;
    if (!force && _userId == userId && hasData) return;

    _userId = userId;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _transactions.fetchTransactions(userId),
        _goals.fetchGoals(userId),
        _categories.fetchCategories(userId),
      ]);
      _allTransactions = results[0] as List<Transaction>;
      _allGoals = results[1] as List<Goal>;
      _allCategories = results[2] as List<Category>;
    } catch (_) {
      _error = 'Não foi possível carregar seus dados. Tente novamente.';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> reload() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId, force: true);
  }

  void nextMonth() {
    _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
    notifyListeners();
  }

  void previousMonth() {
    _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
    notifyListeners();
  }

  // ---------------------------------------------------------------- Transações

  Future<void> addTransaction({
    required double amount,
    required String type,
    required DateTime date,
    required String description,
    String? categoryId,
    String? authorNumber,
    int installments = 1,
  }) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');

    if (installments > 1) {
      final installmentAmount = amount / installments;
      for (var i = 0; i < installments; i++) {
        final installmentDate = DateTime(date.year, date.month + i, date.day);
        await _transactions.createTransaction(
          userId: userId,
          amount: installmentAmount,
          type: type,
          date: installmentDate,
          description: '$description (${i + 1}/$installments)',
          categoryId: categoryId,
          authorNumber: authorNumber,
        );
      }
    } else {
      await _transactions.createTransaction(
        userId: userId,
        amount: amount,
        type: type,
        date: date,
        description: description,
        categoryId: categoryId,
        authorNumber: authorNumber,
      );
    }

    await _reloadTransactions(userId);
  }

  Future<void> updateTransaction({
    required String id,
    required double amount,
    required String type,
    required DateTime date,
    required String description,
    String? categoryId,
  }) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');

    await _transactions.updateTransaction(
      id: id,
      userId: userId,
      values: {
        'amount': amount,
        'type': type,
        'date': _dateOnly(date),
        'description': description,
        'category_id': categoryId,
      },
    );
    await _reloadTransactions(userId);
  }

  Future<void> deleteTransaction(String id) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    await _transactions.deleteTransaction(id: id, userId: userId);
    await _reloadTransactions(userId);
  }

  Future<void> _reloadTransactions(String userId) async {
    _allTransactions = await _transactions.fetchTransactions(userId);
    notifyListeners();
  }

  // --------------------------------------------------------------------- Metas

  Future<void> addGoal(Map<String, dynamic> values) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    await _goals.createGoal(userId, values);
    await _reloadGoals(userId);
  }

  Future<void> updateGoal({required String id, required Map<String, dynamic> values}) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    await _goals.updateGoal(id: id, userId: userId, values: values);
    await _reloadGoals(userId);
  }

  Future<void> deleteGoal(String id) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    await _goals.deleteGoal(id: id, userId: userId);
    await _reloadGoals(userId);
  }

  Future<void> _reloadGoals(String userId) async {
    _allGoals = await _goals.fetchGoals(userId);
    notifyListeners();
  }

  // ---------------------------------------------------------------- Categorias

  Future<void> addCategory(Map<String, dynamic> values) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    await _categories.createCategory(userId, values);
    await _reloadCategories(userId);
  }

  Future<void> updateCategory({required String id, required Map<String, dynamic> values}) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    await _categories.updateCategory(id: id, userId: userId, values: values);
    await _reloadCategories(userId);
  }

  Future<void> deleteCategory(String id) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    await _categories.deleteCategory(id: id, userId: userId, categories: _allCategories);
    await _reloadCategories(userId);
    _allTransactions = await _transactions.fetchTransactions(userId);
    notifyListeners();
  }

  Future<void> _reloadCategories(String userId) async {
    _allCategories = await _categories.fetchCategories(userId);
    notifyListeners();
  }

  // ------------------------------------------------------- Cálculos dashboard

  List<Transaction> get _monthTransactions =>
      _transactionsFor(_currentDate.year, _currentDate.month);

  List<Transaction> _transactionsFor(int year, int month) {
    return _allTransactions.where((transaction) {
      return transaction.date.year == year && transaction.date.month == month;
    }).toList();
  }

  double get monthlyIncome => _sumByType(_monthTransactions, 'income');
  double get monthlyExpenses => _sumByType(_monthTransactions, 'expense');
  double get monthlyBalance => monthlyIncome - monthlyExpenses;

  double get previousMonthIncome {
    final previous = DateTime(_currentDate.year, _currentDate.month - 1, 1);
    return _sumByType(_transactionsFor(previous.year, previous.month), 'income');
  }

  double get previousMonthExpenses {
    final previous = DateTime(_currentDate.year, _currentDate.month - 1, 1);
    return _sumByType(_transactionsFor(previous.year, previous.month), 'expense');
  }

  double get previousMonthBalance => previousMonthIncome - previousMonthExpenses;

  double _sumByType(List<Transaction> list, String type) {
    return list
        .where((transaction) => transaction.type == type)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double comparison(double current, double previous) {
    if (previous == 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous) * 100;
  }

  List<Transaction> get recentTransactions => _allTransactions.take(5).toList();

  List<Goal> get activeGoals => _allGoals
      .where((goal) => !goal.isCompleted && goal.currentAmount < goal.targetAmount)
      .take(3)
      .toList();

  int get completedGoalsCount => _allGoals.where((goal) => goal.isCompleted).length;

  int get totalGoals => _allGoals.length;

  double get goalsCompletionRate =>
      _allGoals.isEmpty ? 0 : completedGoalsCount / _allGoals.length;

  List<CategoryTotal> get expenseCategories => _categoryTotals('expense');

  List<CategoryTotal> get incomeCategories => _categoryTotals('income');

  List<CategoryTotal> _categoryTotals(String type) {
    final monthTransactions = _monthTransactions;
    final totals = <CategoryTotal>[];
    for (final category in _allCategories) {
      if (category.type != type) continue;
      final total = monthTransactions
          .where((transaction) => transaction.categoryId == category.id)
          .fold(0.0, (sum, transaction) => sum + transaction.amount);
      if (total > 0) {
        totals.add(CategoryTotal(category: category, total: total));
      }
    }
    totals.sort((a, b) => b.total.compareTo(a.total));
    return totals;
  }

  Category? categoryById(String? id) {
    if (id == null) return null;
    for (final category in _allCategories) {
      if (category.id == id) return category;
    }
    return null;
  }

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
