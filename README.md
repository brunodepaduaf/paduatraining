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

O aplicativo usa o esquema do projeto Supabase de teste existente, cujo histórico é diferente da fundação originalmente criada neste repositório. `supabase/reconciliation/remote-history.sql` é uma cópia do SQL das 11 migrations já registradas nesse projeto, para reprodução local; a migration complementar `20261029023003_reconcile_existing_anamnesis.sql` foi aplicada ao projeto de teste com essa versão.

Os arquivos originais em `supabase/migrations` foram preservados como histórico de uma fundação alternativa. **Não execute `supabase db push` com essa pasta contra o projeto de teste**: ela não corresponde ao histórico remoto e tentaria recriar objetos existentes. Para alterações futuras, compare o histórico remoto e crie migrations aditivas específicas para esse esquema; não reescreva migrations já aplicadas.

RLS protege todas as tabelas públicas e os papéis vêm de `organization_members`. Owner e trainer consultam respostas clínicas por funções auditadas, sem acesso direto às respostas. Antes de aplicar alterações em outra instância, compare seu esquema e histórico e execute os testes transacionais.
## CI e previews

O GitHub Actions executa lint, tipagem, testes e export web em pull requests e pushes. O Vercel usa `vercel.json` para publicar o conteúdo estático de `dist`; conecte o repositório no painel do Vercel para ativar previews. Os perfis `development`, `preview` e `production` estão declarados em `eas.json`, mas o uso de EAS exige uma conta e projeto Expo configurados fora deste repositório.

## Onboarding e anamnese

Após entrar, selecione a organização quando houver mais de uma. O aluno com acesso ativo pode retomar o tour, escolher uma anamnese publicada, salvar respostas incompletas como rascunho e enviar quando preencher os campos obrigatórios. O envio é definitivo. Um formulário arquivado deixa de aparecer para novos preenchimentos; publique uma nova versão para alterações.

O owner cria formulários em rascunho, define perguntas e opções, publica, arquiva e duplica versões. Apenas rascunhos podem ser excluídos. Formulários publicados e respostas enviadas são protegidos no banco; a interface não substitui RLS. As informações de acesso e os papéis vêm de `access_periods` e `organization_members`. Não use dados reais nos testes.

Para executar o teste transacional de isolamento, use uma base PostgreSQL **vazia e descartável**, com permissão para criar roles e extensões, e execute a partir da raiz do repositório:

```bash
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/reconciliation.sql
```

O teste cria esquemas mínimos de autenticação e storage, reproduz o histórico remoto e aplica a migration complementar, usa apenas dados sintéticos e termina com `ROLLBACK`. O teste `rls-isolation.sql` cobre a fundação alternativa e não descreve o projeto de teste atual. Ele verifica owner, trainer vinculado, aluno ativo e bloqueado, organizações distintas e imutabilidade. Execute também em uma instância Supabase local ou staging antes de implantar migrations em ambiente compartilhado.
