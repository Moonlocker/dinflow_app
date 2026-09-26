/// Modelos do módulo Open Finance (tabelas `open_finance_*`).
///
/// Módulo isolado e opcional: nada aqui altera o núcleo financeiro existente.
library;

class OpenFinanceConnection {
  const OpenFinanceConnection({
    required this.id,
    required this.institutionName,
    required this.status,
    required this.isActive,
    this.lastSyncAt,
    this.lastSyncStatus,
    this.lastError,
    this.externalConnectionId = '',
  });

  final String id;
  final String? institutionName;
  final String? status;
  final bool isActive;
  final DateTime? lastSyncAt;
  final String? lastSyncStatus;
  final String? lastError;
  final String externalConnectionId;

  /// Rótulo amigável, sem termos técnicos.
  String get statusLabel {
    switch (status) {
      case 'UPDATED':
        return 'Conectado';
      case 'UPDATING':
        return 'Atualizando…';
      case 'WAITING_USER_INPUT':
      case 'WAITING_USER_ACTION':
      case 'USER_AUTHORIZATION_PENDING':
        return 'Aguardando você';
      case 'LOGIN_ERROR':
      case 'ERROR':
        return 'Precisa conectar de novo';
      case 'OUTDATED':
        return 'Precisa atualizar';
      case 'DISCONNECTED':
        return 'Desconectado';
      default:
        return 'Conectado';
    }
  }

  bool get needsAttention =>
      status == 'WAITING_USER_INPUT' ||
      status == 'WAITING_USER_ACTION' ||
      status == 'USER_AUTHORIZATION_PENDING' ||
      status == 'LOGIN_ERROR' ||
      status == 'ERROR' ||
      status == 'OUTDATED';

  factory OpenFinanceConnection.fromMap(Map<String, dynamic> map) {
    return OpenFinanceConnection(
      id: map['id'] as String,
      institutionName: map['institution_name'] as String?,
      status: map['status'] as String?,
      isActive: (map['is_active'] as bool?) ?? true,
      lastSyncAt: _parseDate(map['last_sync_at']),
      lastSyncStatus: map['last_sync_status'] as String?,
      lastError: map['last_error'] as String?,
      externalConnectionId: (map['external_connection_id'] as String?) ?? '',
    );
  }
}

class OpenFinanceAccount {
  const OpenFinanceAccount({
    required this.id,
    required this.connectionId,
    required this.name,
    this.bankName,
    this.balance,
    this.subtype,
  });

  final String id;
  final String connectionId;
  final String? name;
  final String? bankName;
  final double? balance;
  final String? subtype;

  factory OpenFinanceAccount.fromMap(Map<String, dynamic> map) {
    return OpenFinanceAccount(
      id: map['id'] as String,
      connectionId: map['connection_id'] as String,
      name: map['account_name'] as String?,
      bankName: map['bank_name'] as String?,
      balance: _parseDouble(map['balance']),
      subtype: map['account_subtype'] as String?,
    );
  }
}

class OpenFinanceCard {
  const OpenFinanceCard({
    required this.id,
    required this.connectionId,
    required this.name,
    this.brand,
    this.creditLimit,
    this.availableLimit,
    this.dueDate,
  });

  final String id;
  final String connectionId;
  final String? name;
  final String? brand;
  final double? creditLimit;
  final double? availableLimit;
  final DateTime? dueDate;

  factory OpenFinanceCard.fromMap(Map<String, dynamic> map) {
    return OpenFinanceCard(
      id: map['id'] as String,
      connectionId: map['connection_id'] as String,
      name: map['card_name'] as String?,
      brand: map['brand'] as String?,
      creditLimit: _parseDouble(map['credit_limit']),
      availableLimit: _parseDouble(map['available_limit']),
      dueDate: _parseDate(map['due_date']),
    );
  }
}

class OpenFinanceBill {
  const OpenFinanceBill({
    required this.id,
    required this.cardId,
    this.totalAmount,
    this.minimumAmount,
    this.dueDate,
  });

  final String id;
  final String cardId;
  final double? totalAmount;
  final double? minimumAmount;
  final DateTime? dueDate;

  factory OpenFinanceBill.fromMap(Map<String, dynamic> map) {
    return OpenFinanceBill(
      id: map['id'] as String,
      cardId: map['card_id'] as String,
      totalAmount: _parseDouble(map['total_amount']),
      minimumAmount: _parseDouble(map['minimum_amount']),
      dueDate: _parseDate(map['due_date']),
    );
  }
}

class OpenFinanceTransaction {
  const OpenFinanceTransaction({
    required this.id,
    required this.connectionId,
    this.cardId,
    this.description,
    this.merchantName,
    this.amount = 0,
    this.date,
    this.status,
    this.installmentNumber,
    this.installmentsTotal,
  });

  final String id;
  final String connectionId;
  final String? cardId;
  final String? description;
  final String? merchantName;
  final double amount;
  final DateTime? date;
  final String? status;
  final int? installmentNumber;
  final int? installmentsTotal;

  factory OpenFinanceTransaction.fromMap(Map<String, dynamic> map) {
    return OpenFinanceTransaction(
      id: map['id'] as String,
      connectionId: map['connection_id'] as String,
      cardId: map['card_id'] as String?,
      description: map['description'] as String?,
      merchantName: map['merchant_name'] as String?,
      amount: _parseDouble(map['amount']) ?? 0,
      date: _parseDate(map['transaction_date']),
      status: map['status'] as String?,
      installmentNumber: (map['installment_number'] as num?)?.toInt(),
      installmentsTotal: (map['installments_total'] as num?)?.toInt(),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
