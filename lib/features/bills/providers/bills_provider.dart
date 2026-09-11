import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../../models/bill.dart';
import '../../../repositories/bills_repository.dart';
import '../../../repositories/payments_repository.dart';

/// Estado das contas fixas e seus pagamentos mensais.
class BillsProvider extends ChangeNotifier {
  BillsProvider({
    BillsRepository? billsRepository,
    PaymentsRepository? paymentsRepository,
  })  : _billsRepo = billsRepository ?? BillsRepository(),
        _paymentsRepo = paymentsRepository ?? PaymentsRepository();

  final BillsRepository _billsRepo;
  final PaymentsRepository _paymentsRepo;

  String? _userId;
  List<Bill> _allBills = [];
  List<BillPayment> _payments = [];
  DateTime _currentDate = DateTime.now();
  bool _loading = false;
  String? _error;

  List<Bill> get bills => _allBills;
  List<BillPayment> get payments => _payments;
  DateTime get currentDate => _currentDate;
  bool get loading => _loading;
  String? get error => _error;

  String get currentMonthYear =>
      '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}';

  BillPayment? paymentFor(String billId) {
    for (final payment in _payments) {
      if (payment.billReminderId == billId) return payment;
    }
    return null;
  }

  bool isPaid(String billId) => paymentFor(billId) != null;

  Future<void> load(String userId, {bool force = false}) async {
    if (_loading) return;
    if (!force && _userId == userId && _allBills.isNotEmpty) return;

    _userId = userId;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _billsRepo.fetchBills(userId),
        _paymentsRepo.fetchPayments(userId, currentMonthYear),
      ]);
      _allBills = results[0] as List<Bill>;
      _payments = results[1] as List<BillPayment>;
    } catch (_) {
      _error = 'Não foi possível carregar suas contas. Tente novamente.';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> reload() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId, force: true);
  }

  Future<void> nextMonth() async {
    _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
    await _reloadPayments();
  }

  Future<void> previousMonth() async {
    _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
    await _reloadPayments();
  }

  Future<void> _reloadPayments() async {
    final userId = _userId;
    if (userId == null) return;
    _payments = await _paymentsRepo.fetchPayments(userId, currentMonthYear);
    notifyListeners();
  }

  Future<void> addBill(Map<String, dynamic> values) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    await _billsRepo.createBill(userId, values);
    await _reloadBills(userId);
  }

  Future<void> updateBill({required String id, required Map<String, dynamic> values}) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    await _billsRepo.updateBill(id: id, userId: userId, values: values);
    await _reloadBills(userId);
  }

  Future<void> deleteBill(String id) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    await _billsRepo.deleteBill(id: id, userId: userId);
    await _reloadBills(userId);
  }

  Future<void> markAsPaid({required String billId, required double amount}) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    await _paymentsRepo.markAsPaid(
      userId: userId,
      billId: billId,
      monthYear: currentMonthYear,
      amount: amount,
    );
    await _reloadPayments();
  }

  Future<void> _reloadBills(String userId) async {
    _allBills = await _billsRepo.fetchBills(userId);
    notifyListeners();
  }
}
