import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../../core/config/app_config.dart';
import '../../../models/open_finance.dart';
import '../../../repositories/open_finance_repository.dart';

/// Estado do módulo Open Finance no aplicativo.
///
/// Quando [isEnabled] é false, nada é carregado e nenhuma tela é exibida.
class OpenFinanceProvider extends ChangeNotifier {
  OpenFinanceProvider({OpenFinanceRepository? repository})
      : _repository = repository ?? OpenFinanceRepository();

  final OpenFinanceRepository _repository;

  String? _userId;
  bool _loading = false;
  String? _error;
  List<OpenFinanceConnection> _connections = [];
  List<OpenFinanceAccount> _accounts = [];
  List<OpenFinanceCard> _cards = [];
  List<OpenFinanceBill> _bills = [];
  List<OpenFinanceTransaction> _transactions = [];

  bool get isEnabled => AppConfig.openFinanceEnabled;
  bool get loading => _loading;
  String? get error => _error;
  List<OpenFinanceConnection> get connections => _connections;
  List<OpenFinanceAccount> get accounts => _accounts;
  List<OpenFinanceCard> get cards => _cards;
  List<OpenFinanceBill> get bills => _bills;
  List<OpenFinanceTransaction> get transactions => _transactions;

  Future<void> load(String userId, {bool force = false}) async {
    if (!isEnabled) return;
    if (_loading) return;
    if (!force && _userId == userId) return;

    _userId = userId;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.fetchConnections(userId),
        _repository.fetchAccounts(userId),
        _repository.fetchCards(userId),
        _repository.fetchBills(userId),
        _repository.fetchTransactions(userId),
      ]);
      _connections = results[0] as List<OpenFinanceConnection>;
      _accounts = results[1] as List<OpenFinanceAccount>;
      _cards = results[2] as List<OpenFinanceCard>;
      _bills = results[3] as List<OpenFinanceBill>;
      _transactions = results[4] as List<OpenFinanceTransaction>;
    } catch (_) {
      _error = 'Não foi possível carregar suas contas conectadas.';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> reload() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId, force: true);
  }

  Future<String> createConnectToken({String? itemId}) {
    return _repository.createConnectToken(itemId: itemId);
  }

  Future<void> sync({String? connectionId}) async {
    await _repository.sync(connectionId: connectionId);
    await reload();
  }

  Future<void> disconnect(String connectionId) async {
    await _repository.disconnect(connectionId);
    await reload();
  }
}
