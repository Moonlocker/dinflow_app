import 'package:flutter/material.dart';

/// Metadados de uma página navegável do aplicativo.
///
/// As chaves (`key`) são exatamente as usadas no webapp e na tabela
/// `page_visibility_settings` (`dashboard`, `transactions`, ...), garantindo
/// que as configurações de visibilidade/ordem feitas no webapp sejam
/// respeitadas no aplicativo.
class AppPage {
  const AppPage({
    required this.key,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String key;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Todas as páginas internas, na ordem padrão do webapp.
const List<AppPage> kAppPages = [
  AppPage(
    key: 'dashboard',
    label: 'Início',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
  ),
  AppPage(
    key: 'transactions',
    label: 'Transações',
    icon: Icons.credit_card_outlined,
    activeIcon: Icons.credit_card,
  ),
  AppPage(
    key: 'reports',
    label: 'Relatórios',
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart,
  ),
  AppPage(
    key: 'goals',
    label: 'Metas',
    icon: Icons.flag_outlined,
    activeIcon: Icons.flag,
  ),
  AppPage(
    key: 'education',
    label: 'Educação',
    icon: Icons.menu_book_outlined,
    activeIcon: Icons.menu_book,
  ),
  AppPage(
    key: 'bills',
    label: 'Contas',
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
  ),
  AppPage(
    key: 'settings',
    label: 'Ajustes',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
  ),
];

/// Chaves de todas as páginas, na ordem padrão.
List<String> get kAppPageKeys => kAppPages.map((page) => page.key).toList();

AppPage appPageByKey(String key) {
  for (final page in kAppPages) {
    if (page.key == key) return page;
  }
  return kAppPages.first;
}
