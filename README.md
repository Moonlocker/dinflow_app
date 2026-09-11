# DinFlow App

Aplicativo mobile do **DinFlow** — controle financeiro pessoal com integração
WhatsApp, assinaturas, painel administrativo e conteúdo educacional.

Mesmo backend do webapp: **Supabase** (Postgres + Auth + Storage + Realtime +
Edge Functions). O app fala direto com o Supabase (PostgREST/RPC) e invoca as
Edge Functions via `supabase.functions.invoke`.

## Stack

| Camada | Tecnologia |
| --- | --- |
| UI | Flutter (Material 3) + `provider` |
| Backend | Supabase (Postgres/RLS/Auth/Storage/Realtime/Edge Functions) |
| Gráficos | `fl_chart` |
| Relatórios | `pdf` + `excel` + `share_plus` + `path_provider` |
| Mídia | `image_picker` |
| 2FA | `otp` + `qr_flutter` |
| Links | `url_launcher` |

## Como rodar

```bash
flutter pub get
flutter run
# build de produção
flutter build apk --release
```

Configuração opcional por `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<projeto>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=WEB_APP_URL=https://dinflow.com.br
```

## Funcionalidades implementadas

- **Auth**: login, cadastro, recuperação de senha, alterar senha, login social
  (Google/Apple via OAuth + deep link), 2FA (TOTP).
- **Navegação configurável**: respeita `page_visibility_settings` (páginas
  ocultas/ordem) definida pelo superadmin, com Realtime.
- **Dashboard**: resumo do mês, comparação, filtro por autor, transações e
  metas recentes, contas do mês, ações rápidas e gráficos por categoria.
- **Transações**: CRUD, parcelamento, busca, filtros (tipo/categoria/autor/
  período) e paginação.
- **Relatórios**: períodos, resumo, insights, saúde financeira, gráficos
  (barras, saldo acumulado, categorias), comparação mensal e exportação
  **PDF/Excel**.
- **Metas**: CRUD, orçamento por categoria (cálculo automático), adicionar valor
  e filtros.
- **Contas fixas**: CRUD, pagar/desfazer, lançamento em transações e navegação
  por mês.
- **Educação**: listagem, abertura de link e registro de cliques.
- **Notificações**: sino com badge, lista, detalhe e marcar como lida.
- **Assistente (Chat IA)**: parser local de lançamentos em português.
- **Assinatura**: planos, ciclo Mensal/Anual, checkout/portal/cancelamento
  (Stripe) e histórico de pagamentos.
- **Configurações**: perfil (nome/país/WhatsApp/avatar), categorias,
  preferências, números WhatsApp extras, segurança (2FA + zona de perigo),
  afiliação ("Indique e Ganhe"), WhatsApp oficial e assinatura.
- **Afiliação**: código/link, estatísticas, indicações e saque via PIX.
- **Modo demonstração**: tela com dados fictícios acessível pelo login.
- **Impersonation**: superadmin pode "acessar como" um usuário.
- **Realtime**: transações, metas, categorias, contas, pagamentos,
  notificações, educação e visibilidade de páginas.
- **Painel SuperAdmin**: visão geral com gráficos, usuários (editar/excluir em
  lote/impersonate), planos, pagamentos, comunicação (e-mail/notificação),
  webhooks (config/logs/contas/instruções), WhatsApp (chat + editar usuário),
  afiliados, analytics, educação e configurações globais (incl. uploads de
  mídia, visibilidade de páginas e diagnóstico do sistema).

## Configuração externa necessária

1. **Migration de RLS** (no repositório do webapp):
   aplicar `supabase/migrations/20260911000000_user_whatsapp_numbers_superadmin_policy.sql`
   (policy de superadmin em `user_whatsapp_numbers` — necessária para a
   impersonation).
2. **Supabase Auth → URL Configuration**:
   - Adicionar `io.dinflow.app://login-callback` em *Redirect URLs*.
   - Habilitar os provedores **Google** e **Apple**.
3. Buckets usados pelos uploads já existem no webapp (`logos`, `education`,
   `hero-media`, `landing-media`, `testimonials`, `avatars`).

## Pendências / próximos passos

Itens menores ainda não implementados (ou implementados de forma simplificada):

- [ ] **Modo demo "app completo"**: hoje é uma tela de preview self-contained.
      Avaliar reutilizar todo o shell com um `DemoProvider` (dados fictícios)
      interceptando os providers, como no webapp.
- [ ] **Abas de método de pagamento** (Cartão/PIX) na tela de assinatura — no
      webapp é apenas informativo; o checkout é Stripe.
- [ ] **Leitor interno de conteúdo educacional** — hoje abre o link externo
      (mesmo comportamento do webapp).
- [ ] **Analytics de páginas públicas** (Pixel/GTM) — não se aplica ao app
      autenticado; sem instrumentação.
- [ ] **Instalação PWA / landing page** — itens inerentemente web.
- [ ] **2FA obrigatório no login** — o webapp apenas armazena o flag; não há
      verificação no login em nenhum dos dois.
- [ ] **Diagnóstico do sistema**: funções que não aceitam corpo `{test:true}`
      podem aparecer como "indisponível" (comportamento esperado do teste).
- [ ] **Uploads de mídia**: logos/favicon no webapp também geram ícones PWA
      (192/512); no app apenas o upload simples é feito.
