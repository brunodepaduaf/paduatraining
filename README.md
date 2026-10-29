# Padua Training

Aplicação Expo/React Native para gestão segura de alunos de personal trainers. A aplicação inclui onboarding retomável e anamnese dinâmica, além da fundação de autenticação e acesso protegido por RLS.

## Pré-requisitos

- Node.js 24+
- pnpm 10+
- Um projeto Supabase para aplicar as migrations (opcional para navegar pelas telas locais)

## Executar

```bash
cp .env.example .env
pnpm install --frozen-lockfile
pnpm start
```

Preencha somente `EXPO_PUBLIC_SUPABASE_URL` e `EXPO_PUBLIC_SUPABASE_ANON_KEY` no `.env`. Nunca crie, copie ou exponha uma `service_role` no app.

## Validação

```bash
pnpm lint
pnpm typecheck
pnpm test
pnpm exec expo export --platform web
```

## Banco de dados

As migrations vivem em `supabase/migrations`. A migration inicial habilita RLS para todas as tabelas de `public`, usa papéis em `organization_members`, protege respostas clínicas de leitura direta por owner/trainer e registra acesso a anamnese sem gravar o conteúdo no log.

Antes de aplicar em uma instância compartilhada, execute os testes transacionais de RLS contra uma instância Supabase local ou de staging. Não há migration destrutiva nesta sprint.

## CI e previews

O GitHub Actions executa lint, tipagem, testes e export web em pull requests e pushes. O Vercel usa `vercel.json` para publicar o conteúdo estático de `dist`; conecte o repositório no painel do Vercel para ativar previews. Os perfis `development`, `preview` e `production` estão declarados em `eas.json`, mas o uso de EAS exige uma conta e projeto Expo configurados fora deste repositório.

## Onboarding e anamnese

Após entrar, selecione a organização quando houver mais de uma. O aluno com acesso ativo pode retomar o tour, escolher uma anamnese publicada, salvar respostas incompletas como rascunho e enviar quando preencher os campos obrigatórios. O envio é definitivo. Um formulário arquivado deixa de aparecer para novos preenchimentos; publique uma nova versão para alterações.

O owner cria formulários em rascunho, define perguntas e opções, publica, arquiva e duplica versões. Apenas rascunhos podem ser excluídos. Formulários publicados e respostas enviadas são protegidos no banco; a interface não substitui RLS. As informações de acesso e os papéis vêm de `access_periods` e `organization_members`. Não use dados reais nos testes.

Para executar o teste transacional de isolamento, use uma base PostgreSQL **vazia e descartável**, com permissão para criar roles e extensões, e execute a partir da raiz do repositório:

```bash
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls-isolation.sql
```

O teste cria um esquema mínimo de autenticação, aplica as migrations, usa apenas dados sintéticos e termina com `ROLLBACK`. Ele verifica owner, trainer vinculado, aluno ativo e bloqueado, organizações distintas e imutabilidade. Execute também em uma instância Supabase local ou staging antes de implantar migrations em ambiente compartilhado.
