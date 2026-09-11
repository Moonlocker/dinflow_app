import 'package:flutter/material.dart';

import '../../../../repositories/admin_repository.dart';
import '../../widgets/admin_widgets.dart';

/// Configurações de Analytics & Tracking (Facebook Pixel, GTM, GA4).
class AdminAnalyticsSection extends StatefulWidget {
  const AdminAnalyticsSection({super.key});

  @override
  State<AdminAnalyticsSection> createState() => _AdminAnalyticsSectionState();
}

class _AdminAnalyticsSectionState extends State<AdminAnalyticsSection> {
  final _repo = AdminRepository();
  final _pixelController = TextEditingController();
  final _gtmController = TextEditingController();
  final _gaController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pixelController.dispose();
    _gtmController.dispose();
    _gaController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.fetchAnalyticsSettings();
      _pixelController.text = (data?['facebook_pixel_id'] ?? '') as String;
      _gtmController.text = (data?['gtm_id'] ?? '') as String;
      _gaController.text = (data?['google_analytics_id'] ?? '') as String;
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
    setState(() => _saving = true);
    try {
      await _repo.saveAnalyticsSettings(
        facebookPixelId: _emptyToNull(_pixelController.text),
        gtmId: _emptyToNull(_gtmController.text),
        googleAnalyticsId: _emptyToNull(_gaController.text),
      );
      if (!mounted) return;
      showAdminSnack(context, 'Configurações salvas.');
    } catch (_) {
      if (!mounted) return;
      showAdminSnack(context, 'Erro ao salvar as configurações.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AdminLoading();
    if (_error != null) return AdminError(message: _error!, onRetry: _load);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        AdminSectionCard(
          title: 'Configurações de Analytics & Tracking',
          child: Column(
            children: [
              TextField(
                controller: _pixelController,
                decoration: const InputDecoration(
                  labelText: 'Facebook Pixel',
                  hintText: 'Ex: 829754783215698',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _gtmController,
                decoration: const InputDecoration(
                  labelText: 'Google Tag Manager',
                  hintText: 'GTM-XXXXXXX',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _gaController,
                decoration: const InputDecoration(
                  labelText: 'Google Analytics 4',
                  hintText: 'G-XXXXXXXXXX',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const AdminSectionCard(
          title: 'Eventos rastreados automaticamente',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• PageView'),
              Text('• CompleteRegistration'),
              Text('• StartTrial'),
              Text('• InitiateCheckout'),
              Text('• Purchase'),
            ],
          ),
        ),
      ],
    );
  }
}
