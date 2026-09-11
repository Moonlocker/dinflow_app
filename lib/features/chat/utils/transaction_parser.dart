import '../../../models/category.dart';

/// Resultado do parsing de um lançamento em linguagem natural.
class ParsedTransaction {
  const ParsedTransaction({
    required this.amount,
    required this.description,
    required this.type,
    required this.date,
    this.categoryId,
  });

  final double? amount;
  final String description;
  final String type;
  final DateTime date;
  final String? categoryId;

  ParsedTransaction copyWith({
    String? type,
    String? categoryId,
  }) {
    return ParsedTransaction(
      amount: amount,
      description: description,
      type: type ?? this.type,
      date: date,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}

const Map<String, String> _synonyms = {
  // Alimentação
  'supermercado': 'Alimentação',
  'mercado': 'Alimentação',
  'feira': 'Alimentação',
  'padaria': 'Alimentação',
  'restaurante': 'Alimentação',
  'lanche': 'Alimentação',
  'almoco': 'Alimentação',
  'jantar': 'Alimentação',
  'cafe': 'Alimentação',
  'pizza': 'Alimentação',
  'ifood': 'Alimentação',
  'mcdonalds': 'Alimentação',
  'hamburguer': 'Alimentação',
  // Transporte
  'uber': 'Transporte',
  'taxi': 'Transporte',
  'combustivel': 'Transporte',
  'gasolina': 'Transporte',
  'etanol': 'Transporte',
  'onibus': 'Transporte',
  'metro': 'Transporte',
  'trem': 'Transporte',
  'estacionamento': 'Transporte',
  'pedagio': 'Transporte',
  // Lazer
  'shopping': 'Lazer',
  'cinema': 'Lazer',
  'netflix': 'Lazer',
  'spotify': 'Lazer',
  'show': 'Lazer',
  'bar': 'Lazer',
  'balada': 'Lazer',
  'festa': 'Lazer',
  'viagem': 'Lazer',
  'hotel': 'Lazer',
  'jogo': 'Lazer',
  // Saúde
  'farmacia': 'Saúde',
  'drogaria': 'Saúde',
  'remedio': 'Saúde',
  'medicamento': 'Saúde',
  'consulta': 'Saúde',
  'medico': 'Saúde',
  'dentista': 'Saúde',
  'exame': 'Saúde',
  'hospital': 'Saúde',
  // Educação
  'escola': 'Educação',
  'faculdade': 'Educação',
  'universidade': 'Educação',
  'curso': 'Educação',
  'livro': 'Educação',
  'mensalidade': 'Educação',
  // Casa
  'aluguel': 'Casa',
  'condominio': 'Casa',
  'agua': 'Casa',
  'luz': 'Casa',
  'energia': 'Casa',
  'internet': 'Casa',
  'telefone': 'Casa',
  'celular': 'Casa',
  // Renda
  'salario': 'Salário',
  'pagamento': 'Salário',
  'bonus': 'Salário',
  'comissao': 'Salário',
  'freela': 'Freelance',
  'freelance': 'Freelance',
  'trabalho': 'Freelance',
  'pix': 'Outros',
  'transferencia': 'Outros',
  'venda': 'Outros',
  'emprestimo': 'Outros',
  'investimento': 'Investimentos',
  'dividendo': 'Investimentos',
  'rendimento': 'Investimentos',
};

const List<String> _cleanupWords = [
  'gastei', 'ganhei', 'recebi', 'comprei', 'paguei', 'no', 'na', 'em', 'com',
  'de', 'um', 'uma', 'do', 'da', 'dos', 'das', 'para', 'por', 'hoje', 'ontem',
  'anteontem', 'reais', 'real', 'r\$',
];

/// Interpreta uma frase em português e devolve um lançamento sugerido.
ParsedTransaction parseTransactionInput(String input, List<Category> categories) {
  final text = input.toLowerCase();
  var description = text;
  var type = (text.contains('gastei') ||
          text.contains('comprei') ||
          text.contains('paguei'))
      ? 'expense'
      : 'income';
  var date = DateTime.now();

  // Data
  if (text.contains('anteontem') || text.contains('antes de ontem')) {
    date = DateTime.now().subtract(const Duration(days: 2));
    description = description
        .replaceAll(RegExp(r'antes de ontem|anteontem'), '')
        .trim();
  } else if (text.contains('ontem')) {
    date = DateTime.now().subtract(const Duration(days: 1));
    description = description.replaceAll('ontem', '').trim();
  } else {
    final dateMatch = RegExp(r'(\d{1,2})/(\d{1,2})').firstMatch(text);
    if (dateMatch != null) {
      final day = int.tryParse(dateMatch.group(1)!);
      final month = int.tryParse(dateMatch.group(2)!);
      if (day != null && month != null && month >= 1 && month <= 12) {
        final now = DateTime.now();
        date = DateTime(now.year, month, day);
        description = description.replaceAll(dateMatch.group(0)!, '').trim();
      }
    }
  }

  // Valor
  double? amount;
  final amountMatch =
      RegExp(r'(?:r\$?\s*)?(\d+(?:[,.]\d{1,2})?)\s*(?:reais?)?', caseSensitive: false)
          .firstMatch(text);
  if (amountMatch != null) {
    amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '.'));
    description = description.replaceAll(amountMatch.group(0)!, '').trim();
  }

  // Limpeza da descrição
  description = description
      .split(' ')
      .where((word) => !_cleanupWords.contains(word.toLowerCase()))
      .join(' ')
      .trim();
  if (description.isNotEmpty) {
    description =
        description[0].toUpperCase() + description.substring(1);
  }

  final textNorm = _normalize(text);

  String? categoryId;
  for (final category in categories) {
    if (textNorm.contains(_normalize(category.name))) {
      categoryId = category.id;
      type = category.type;
      break;
    }
  }

  if (categoryId == null) {
    for (final entry in _synonyms.entries) {
      if (textNorm.contains(entry.key)) {
        for (final category in categories) {
          if (_normalize(category.name) == _normalize(entry.value) &&
              category.type == type) {
            categoryId = category.id;
            break;
          }
        }
        if (categoryId != null) break;
      }
    }
  }

  if (categoryId == null) {
    for (final category in categories) {
      if (_normalize(category.name) == 'outros' && category.type == type) {
        categoryId = category.id;
        break;
      }
    }
  }

  return ParsedTransaction(
    amount: amount,
    description: description,
    type: type,
    date: date,
    categoryId: categoryId,
  );
}

String _normalize(String input) {
  const accents = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const plain = 'aaaaaeeeeiiiiooooouuuuc';
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final char = lower[i];
    final index = accents.indexOf(char);
    buffer.write(index >= 0 ? plain[index] : char);
  }
  return buffer.toString();
}
