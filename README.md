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

## Recuperação de senha

Na entrada, informe o e-mail e selecione “Esqueci minha senha”. O Supabase envia o link de recuperação conforme sua configuração de autenticação. Configure nas URLs de redirecionamento permitidas do Supabase o endereço web de `/reset-password` e o deep link `paduatraining://reset-password` antes de disponibilizar o fluxo; provedores de e-mail e limites do plano também precisam estar configurados. Não use contas reais nos testes.

## Validação

```bash
pnpm lint
pnpm typecheck
pnpm test
pnpm test:browser # requer Chromium ou Chrome; CHROMIUM_PATH é opcional
pnpm exec expo export --platform web
```

## Banco de dados

O aplicativo usa o esquema do projeto Supabase de teste existente, cujo histórico é diferente da fundação originalmente criada neste repositório. `supabase/reconciliation/remote-history.sql` é uma cópia do SQL das 11 migrations anteriores desse projeto, para reprodução local. Os demais arquivos numerados em `supabase/reconciliation` registram as migrations complementares aplicadas ao projeto de teste, em ordem de versão.

Os arquivos originais em `supabase/migrations` foram preservados como histórico de uma fundação alternativa. **Não execute `supabase db push` com essa pasta contra o projeto de teste**: ela não corresponde ao histórico remoto e tentaria recriar objetos existentes. Para alterações futuras, compare o histórico remoto e crie migrations aditivas específicas para esse esquema; não reescreva migrations já aplicadas.

RLS protege todas as tabelas públicas e os papéis vêm de `organization_members`. Owner e trainer consultam respostas clínicas por funções auditadas, sem acesso direto às respostas. Antes de aplicar alterações em outra instância, compare seu esquema e histórico e execute os testes transacionais.

## CI e previews

O GitHub Actions executa lint, tipagem, testes unitários, navegação com API sintética, testes transacionais de RLS e export web em pull requests e pushes. O Vercel usa `vercel.json` para publicar o conteúdo estático de `dist`; conecte o repositório no painel do Vercel para ativar previews. Os perfis `development`, `preview` e `production` estão declarados em `eas.json`, mas o uso de EAS exige uma conta e projeto Expo configurados fora deste repositório.

## Onboarding e anamnese

Após entrar, selecione a organização quando houver mais de uma. O aluno com acesso ativo pode retomar o tour, escolher uma anamnese publicada, salvar respostas incompletas como rascunho e enviar quando preencher os campos obrigatórios. Campos numéricos aceitam ponto ou vírgula decimal. Ao voltar à lista, trocar de organização ou sair da conta com alterações não salvas, o aluno recebe uma confirmação. O envio é definitivo. Um formulário arquivado deixa de aparecer para novos preenchimentos; publique uma nova versão para alterações.

Owner e trainer vinculado podem consultar anamneses enviadas; a leitura dos detalhes é auditada pelo banco.

O owner cria formulários em rascunho, define perguntas e opções, publica, arquiva e duplica versões. Apenas rascunhos podem ser excluídos. Formulários publicados e respostas enviadas são protegidos no banco; a interface não substitui RLS. As informações de acesso e os papéis vêm de `access_periods` e `organization_members`. O período mais recente já iniciado determina o acesso; seu vencimento não reativa um período antigo. Não use dados reais nos testes.

Para executar o teste transacional de isolamento, use uma base PostgreSQL **vazia e descartável**, com permissão para criar roles e extensões, e execute a partir da raiz do repositório:

```bash
psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/reconciliation.sql
```

O teste cria esquemas mínimos de autenticação e storage, reproduz o histórico remoto e aplica a migration complementar, usa apenas dados sintéticos e termina com `ROLLBACK`. O teste `rls-isolation.sql` cobre a fundação alternativa e não descreve o projeto de teste atual. Ele verifica owner, trainer vinculado, aluno ativo e bloqueado, organizações distintas e imutabilidade. Execute também em uma instância Supabase local ou staging antes de implantar migrations em ambiente compartilhado.

## Catálogo de exercícios

Owner e trainer podem cadastrar, editar e arquivar exercícios da própria organização. Exercícios arquivados permanecem disponíveis para preservar referências futuras; não há exclusão pela aplicação. Alunos não recebem acesso direto ao catálogo.

## Prescrição de treinos

Owner e trainer podem criar fichas em rascunho para alunos autorizados, adicionar exercícios com séries e repetições e publicar a versão. Trainers trabalham somente com alunos vinculados e com acesso ativo; o aluno acessa apenas as próprias fichas publicadas quando seu acesso está ativo. Ao adicionar um exercício, a ficha guarda uma cópia do nome e das instruções para preservar o conteúdo publicado. Versões publicadas não podem ser editadas ou excluídas; podem ser arquivadas. O aluno pode iniciar uma sessão, marcar os exercícios realizados e concluí-la; as últimas sessões ficam no histórico da ficha. A equipe consulta o histórico pela função auditada, respeitando os vínculos e o acesso ativo.

## Avaliações físicas

Owner e trainer autorizado podem registrar medidas de peso, altura e cintura. Cada registro é imutável, não faz diagnóstico e contém somente as medidas preenchidas; as consultas da equipe são auditadas sem valores no log. O aluno ativo pode consultar as próprias avaliações. Fotografias e outros tipos de avaliação ainda não estão disponíveis.

## Mensagens

Alunos com acesso ativo e trainers vinculados podem trocar mensagens de texto. Somente os participantes atuais têm acesso; bloquear o aluno, arquivar o vínculo ou remover um papel encerra o acesso. As consultas e os envios são auditados sem incluir o texto no log. A tela exibe as últimas 100 mensagens e tem atualização manual; não há notificações ou anexos nesta etapa.

## Controle de acesso

Owner e trainer vinculado podem registrar um novo período ativo, pendente ou bloqueado para um aluno autorizado. A liberação pode ter um último dia opcional, interpretado no fuso local de quem a registra. O horário de início é definido pelo banco e cada alteração é auditada; o histórico anterior é preservado. A tela ainda não cadastra contas nem cria vínculos entre trainer e aluno.

## Vínculos de treino

O owner pode vincular ou encerrar o vínculo entre membros existentes. Trainers não podem atribuir alunos a si mesmos; ao remover o vínculo ou arquivar o papel, o acesso associado deixa de existir. O cadastro de novas contas ainda não está disponível.
