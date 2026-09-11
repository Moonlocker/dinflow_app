import 'package:dinflow_app/core/utils/formatters.dart';
import 'package:dinflow_app/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCurrency', () {
    String normalize(String value) => value.replaceAll('\u00A0', ' ');

    test('formata valores em Real brasileiro', () {
      expect(normalize(formatCurrency(1234.5)), r'R$ 1.234,50');
      expect(normalize(formatCurrency(0)), r'R$ 0,00');
      expect(normalize(formatCurrency(null)), r'R$ 0,00');
    });
  });

  group('Profile', () {
    test('considera trial ativo quando a data é futura', () {
      final profile = Profile(
        id: '1',
        email: 'teste@dinflow.com.br',
        name: 'Ana Souza',
        subscriptionStatus: 'trial',
        trialEndsAt: DateTime.now().add(const Duration(days: 5)),
      );

      expect(profile.isSubscriptionActive, isTrue);
      expect(profile.firstName, 'Ana');
    });
  });
}
