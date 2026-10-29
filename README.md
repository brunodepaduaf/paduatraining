# Padua Training

Aplicação Expo/React Native para gestão segura de alunos de personal trainers. A primeira sprint entrega a fundação: tema, navegação, autenticação e modelo Supabase protegido por RLS.

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

## Sprint 2 em andamento

A validação de respostas dinâmicas em `lib/anamnesis/validation.ts` cobre os tipos previstos e campos obrigatórios, mas ainda não está conectada a telas ou à persistência. Ela não substitui validação e autorização no banco. O tour, a administração e o preenchimento da anamnese ainda não estão disponíveis.

A migration de fundação ainda precisa de reforços antes de receber dados clínicos: a imutabilidade de perguntas publicadas e de respostas enviadas deve ser aplicada no banco, e as políticas de acesso e isolamento devem ser ampliadas e testadas transacionalmente. Use somente dados sintéticos até que esses controles sejam implementados e verificados.
