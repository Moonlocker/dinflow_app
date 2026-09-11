/// Configuração central do aplicativo DinFlow.
///
/// Os valores padrão são as chaves públicas já publicadas no bundle web do
/// DinFlow (protegidas por RLS). Podem ser sobrescritos no build com
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vqdhhoicxnvkpgwvipom.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZGhob2ljeG52a3Bnd3ZpcG9tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc3OTUxNDAsImV4cCI6MjA3MzM3MTE0MH0.w4YttVmNha_V57cwOP6vzKc47uJ8FLxhYqpkRcoejNI',
  );

  static const String appName = 'DinFlow';
  static const String authStorageKey = 'dinflow-auth-token';
  static const String supportEmail = 'contato@dinflow.com.br';

  /// URL pública do webapp (usada em links de indicação/afiliados).
  static const String webAppUrl = String.fromEnvironment(
    'WEB_APP_URL',
    defaultValue: 'https://dinflow.com.br',
  );

  static const String avatarsBucket = 'avatars';
  static const String logosBucket = 'logos';

  /// Deep link usado no retorno do OAuth (Google/Apple).
  /// Deve estar cadastrado em Supabase Auth > URL Configuration.
  static const String oauthRedirectUrl = 'io.dinflow.app://login-callback';
}
