import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_pages.dart';
import '../../../../repositories/admin_repository.dart';
import '../../../../repositories/storage_repository.dart';
import '../../widgets/admin_diagnostics.dart';
import '../../widgets/admin_media_upload.dart';
import '../../widgets/admin_widgets.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../page_visibility/providers/page_visibility_provider.dart';

/// Configurações globais do app, incluindo visibilidade/ordem das páginas.
class AdminSettingsSection extends StatefulWidget {
  const AdminSettingsSection({super.key});

  @override
  State<AdminSettingsSection> createState() => _AdminSettingsSectionState();
}

class _AdminSettingsSectionState extends State<AdminSettingsSection>
    with SingleTickerProviderStateMixin {
  final _repo = AdminRepository();
  late final TabController _tabController;

  final _appNameController = TextEditingController();
  final _trialDaysController = TextEditingController();
  final _logoLightController = TextEditingController();
  final _logoDarkController = TextEditingController();
  final _faviconController = TextEditingController();
  final _educationImageController = TextEditingController();
  final _whatsappController = TextEditingController();

  bool _trialEnabled = true;
  String _whatsappCountry = 'BR';
  String? _heroMediaUrl;
  String _heroMediaType = 'image';
  List<String> _testimonialImages = [];
  String? _whatsappDemoUrl;
  String _whatsappDemoType = 'image';
  String? _dashboardDemoUrl;
  String _dashboardDemoType = 'image';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _countries = ['BR', 'US', 'PT', 'ES', 'AR', 'MX', 'CA', 'FR', 'DE', 'IT'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PageVisibilityProvider>().load(force: true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appNameController.dispose();
    _trialDaysController.dispose();
    _logoLightController.dispose();
    _logoDarkController.dispose();
    _faviconController.dispose();
    _educationImageController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.fetchGlobalSettings();
      if (data != null) {
        _appNameController.text = '${data['app_name'] ?? 'DinFlow'}';
        _trialEnabled = (data['trial_enabled'] ?? true) as bool;
        _trialDaysController.text = '${data['trial_days'] ?? 15}';
        _logoLightController.text = '${data['logo_url'] ?? ''}';
        _logoDarkController.text = '${data['logo_url_dark'] ?? ''}';
        _faviconController.text = '${data['favicon_url'] ?? ''}';
        _educationImageController.text =
            '${data['default_education_image'] ?? ''}';
        _whatsappController.text = '${data['whatsapp'] ?? ''}';
        _whatsappCountry = '${data['whatsapp_country'] ?? 'BR'}';
        _heroMediaUrl = data['hero_media_url'] as String?;
        _heroMediaType = '${data['hero_media_type'] ?? 'image'}';
        final testimonials = data['testimonial_images'];
        _testimonialImages = testimonials is List
            ? testimonials.map((item) => item.toString()).toList()
            : [];
        _whatsappDemoUrl = data['whatsapp_demo_media_url'] as String?;
        _whatsappDemoType = '${data['whatsapp_demo_media_type'] ?? 'image'}';
        _dashboardDemoUrl = data['dashboard_demo_media_url'] as String?;
        _dashboardDemoType = '${data['dashboard_demo_media_type'] ?? 'image'}';
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar as configurações.';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    setState(() => _saving = true);
    try {
      await _repo.updateGlobalSettings({
        'app_name': _appNameController.text.trim(),
        'trial_enabled': _trialEnabled,
        'trial_days': int.tryParse(_trialDaysController.text) ?? 15,
        'logo_url': _nullIfEmpty(_logoLightController.text),
        'logo_url_dark': _nullIfEmpty(_logoDarkController.text),
        'favicon_url': _nullIfEmpty(_faviconController.text),
        'default_education_image': _nullIfEmpty(_educationImageController.text),
        'whatsapp': _nullIfEmpty(_whatsappController.text.replaceAll(RegExp(r'\D'), '')),
        'whatsapp_country': _whatsappCountry,
        'hero_media_url': _heroMediaUrl,
        'hero_media_type': _heroMediaType,
        'testimonial_images': _testimonialImages,
        'whatsapp_demo_media_url': _whatsappDemoUrl,
        'whatsapp_demo_media_type': _whatsappDemoType,
        'dashboard_demo_media_url': _dashboardDemoUrl,
        'dashboard_demo_media_type': _dashboardDemoType,
      });
      if (!mounted) return;
      showAdminSnack(context, 'Configurações salvas.');
      await auth.refresh();
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Erro ao salvar as configurações.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar todos os dados?'),
        content: const Text(
          'Transações, metas, notificações e categorias de todos os usuários '
          'serão removidas. Esta ação é irreversível.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final adminId = context.read<AuthProvider>().user?.id;
    if (adminId == null) return;
    try {
      await _repo.clearUserData(adminId);
      if (!mounted) return;
      showAdminSnack(context, 'Dados limpos.');
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Erro ao limpar os dados.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AdminLoading();
    if (_error != null) return AdminError(message: _error!, onRetry: _load);

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Geral'),
            Tab(text: 'Identidade'),
            Tab(text: 'Landing'),
            Tab(text: 'WhatsApp'),
            Tab(text: 'Visibilidade'),
            Tab(text: 'Sistema'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _generalTab(),
              _identityTab(),
              _landingTab(),
              _whatsappTab(),
              const _VisibilityTab(),
              _systemTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _generalTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        AdminSectionCard(
          title: 'Geral',
          child: Column(
            children: [
              TextField(
                controller: _appNameController,
                decoration: const InputDecoration(labelText: 'Nome da Plataforma'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _trialEnabled,
                onChanged: (value) => setState(() => _trialEnabled = value),
                title: const Text('Teste Grátis'),
                subtitle: const Text('Habilitar período de teste'),
              ),
              if (_trialEnabled)
                TextField(
                  controller: _trialDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Dias de Teste Gratuito',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _saveButton(),
      ],
    );
  }

  Widget _identityTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        AdminSectionCard(
          title: 'Identidade Visual',
          subtitle: 'Envie as imagens de marca da plataforma.',
          child: Column(
            children: [
              AdminMediaUpload(
                label: 'Logo (Fundo Claro)',
                bucket: 'logos',
                pathPrefix: 'logo_light',
                currentUrl: _logoLightController.text,
                onChanged: (url, _) =>
                    setState(() => _logoLightController.text = url),
                onRemove: () =>
                    setState(() => _logoLightController.text = ''),
              ),
              const SizedBox(height: 16),
              AdminMediaUpload(
                label: 'Logo (Fundo Escuro)',
                bucket: 'logos',
                pathPrefix: 'logo_dark',
                currentUrl: _logoDarkController.text,
                onChanged: (url, _) =>
                    setState(() => _logoDarkController.text = url),
                onRemove: () => setState(() => _logoDarkController.text = ''),
              ),
              const SizedBox(height: 16),
              AdminMediaUpload(
                label: 'Favicon',
                bucket: 'logos',
                pathPrefix: 'favicon',
                currentUrl: _faviconController.text,
                onChanged: (url, _) =>
                    setState(() => _faviconController.text = url),
                onRemove: () => setState(() => _faviconController.text = ''),
              ),
              const SizedBox(height: 16),
              AdminMediaUpload(
                label: 'Imagem padrão de Educação',
                bucket: 'education',
                pathPrefix: 'default_education',
                currentUrl: _educationImageController.text,
                onChanged: (url, _) =>
                    setState(() => _educationImageController.text = url),
                onRemove: () =>
                    setState(() => _educationImageController.text = ''),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _saveButton(),
      ],
    );
  }

  Widget _landingTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        AdminSectionCard(
          title: 'Mídias da Landing Page',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminMediaUpload(
                label: 'Hero (imagem ou vídeo)',
                bucket: 'hero-media',
                pathPrefix: 'hero',
                acceptVideo: true,
                currentUrl: _heroMediaUrl,
                onChanged: (url, type) => setState(() {
                  _heroMediaUrl = url;
                  _heroMediaType = type;
                }),
                onRemove: () => setState(() {
                  _heroMediaUrl = null;
                  _heroMediaType = 'image';
                }),
              ),
              const SizedBox(height: 16),
              AdminMediaUpload(
                label: 'Demonstração do WhatsApp (imagem ou vídeo)',
                bucket: 'landing-media',
                pathPrefix: 'whatsapp-demo',
                acceptVideo: true,
                currentUrl: _whatsappDemoUrl,
                onChanged: (url, type) => setState(() {
                  _whatsappDemoUrl = url;
                  _whatsappDemoType = type;
                }),
                onRemove: () => setState(() {
                  _whatsappDemoUrl = null;
                  _whatsappDemoType = 'image';
                }),
              ),
              const SizedBox(height: 16),
              AdminMediaUpload(
                label: 'Demonstração do Dashboard (imagem ou vídeo)',
                bucket: 'landing-media',
                pathPrefix: 'dashboard-demo',
                acceptVideo: true,
                currentUrl: _dashboardDemoUrl,
                onChanged: (url, type) => setState(() {
                  _dashboardDemoUrl = url;
                  _dashboardDemoType = type;
                }),
                onRemove: () => setState(() {
                  _dashboardDemoUrl = null;
                  _dashboardDemoType = 'image';
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdminSectionCard(
          title: 'Depoimentos (Testimonials)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_testimonialImages.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final image in _testimonialImages)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              image,
                              width: 90,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 90,
                                height: 120,
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.cancel, size: 18),
                              onPressed: () => setState(
                                () => _testimonialImages.remove(image),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _addTestimonials,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Adicionar depoimentos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _saveButton(),
      ],
    );
  }

  Future<void> _addTestimonials() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() => _saving = true);
    try {
      final storage = StorageRepository();
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final extension = file.name.contains('.')
            ? file.name.split('.').last.toLowerCase()
            : 'jpg';
        final path =
            'testimonial-${DateTime.now().millisecondsSinceEpoch}-${_testimonialImages.length}.$extension';
        final url = await storage.uploadPublic(
          bucket: 'testimonials',
          path: path,
          bytes: bytes,
          contentType: 'image/${extension == 'jpg' ? 'jpeg' : extension}',
        );
        _testimonialImages.add(url);
      }
      if (!mounted) return;
      setState(() {});
      showAdminSnack(context, 'Depoimentos adicionados.');
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Erro ao enviar os depoimentos.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _whatsappTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        AdminSectionCard(
          title: 'WhatsApp',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _whatsappCountry,
                decoration: const InputDecoration(labelText: 'País do WhatsApp'),
                items: [
                  for (final country in _countries)
                    DropdownMenuItem(value: country, child: Text(country)),
                ],
                onChanged: (value) =>
                    setState(() => _whatsappCountry = value ?? 'BR'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Número WhatsApp da Plataforma',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _saveButton(),
      ],
    );
  }

  Widget _systemTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        const AdminDiagnostics(),
        const SizedBox(height: 16),
        AdminSectionCard(
          title: 'Zona de Perigo',
          subtitle: 'Ações irreversíveis sobre os dados da plataforma.',
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearData,
              icon: Icon(Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error),
              label: Text(
                'Limpar Todos os Dados',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Salvar Configurações'),
      ),
    );
  }
}

/// Aba de visibilidade/ordem das páginas (espelha o webapp).
class _VisibilityTab extends StatelessWidget {
  const _VisibilityTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PageVisibilityProvider>();

    if (provider.loading && !provider.loaded) {
      return const AdminLoading();
    }

    final keys = kAppPageKeys
      ..sort((a, b) =>
          provider.settings.orderOf(a).compareTo(provider.settings.orderOf(b)));

    return ReorderableListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      header: Text(
        'Controle quais páginas aparecem no menu do usuário e a ordem delas.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      onReorderItem: (oldIndex, newIndex) {
        final reordered = List<String>.from(keys);
        final item = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, item);
        provider.setOrder(reordered);
      },
      children: [
        for (final key in keys)
          _VisibilityTile(
            key: ValueKey(key),
            pageKey: key,
            desktop: provider.settings.desktopVisible(key),
            mobile: provider.settings.mobileVisible(key),
            onDesktopChanged: (value) =>
                provider.setDesktopVisible(key, value),
            onMobileChanged: (value) => provider.setMobileVisible(key, value),
          ),
      ],
    );
  }
}

class _VisibilityTile extends StatelessWidget {
  const _VisibilityTile({
    super.key,
    required this.pageKey,
    required this.desktop,
    required this.mobile,
    required this.onDesktopChanged,
    required this.onMobileChanged,
  });

  final String pageKey;
  final bool desktop;
  final bool mobile;
  final ValueChanged<bool> onDesktopChanged;
  final ValueChanged<bool> onMobileChanged;

  @override
  Widget build(BuildContext context) {
    final page = appPageByKey(pageKey);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.drag_handle, size: 20),
                const SizedBox(width: 8),
                Icon(page.icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    page.label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: desktop,
                    onChanged: onDesktopChanged,
                    title: const Text('Desktop', style: TextStyle(fontSize: 13)),
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: mobile,
                    onChanged: onMobileChanged,
                    title: const Text('Mobile', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
