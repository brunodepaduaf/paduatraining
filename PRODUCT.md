# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

Expo + React Native + TypeScript, Expo Router, React Native Web, Supabase, TanStack Query, React Hook Form, Zod and pnpm.

## Users

- **Aluno:** consulta e executa seu treino, responde à anamnese e acompanha seu próprio histórico em contexto principalmente mobile.
- **Trainer:** acompanha somente os alunos ativos da própria carteira, com ações essenciais no mobile e produtividade no navegador.
- **Owner:** administra a organização, membros, períodos de acesso e formulários.

## Product Purpose

Padua Training é uma plataforma para personal trainers prescreverem e acompanharem o desenvolvimento de alunos, com dados de saúde tratados como informação sensível.

## Positioning

Combina controle manual de acesso, isolamento por organização no banco e experiência mobile-first para transformar uma prescrição em acompanhamento individual seguro.

## Operating Context

Alunos usam o celular durante sua rotina de treino. Trainers e owners usam também o navegador para consultar listas, formulários e ações administrativas.

## Capabilities and Constraints

- Autorização é aplicada no PostgreSQL com RLS; a interface não decide permissões.
- Papéis vêm de `organization_members`, nunca de metadados de autenticação.
- Dados clínicos e fotos são privados, minimizados e auditados sem conteúdo sensível.
- A primeira sprint cobre fundação, acesso e estados de autenticação; treino, avaliações e pagamentos permanecem fora desta entrega.

## Brand Commitments

Nome: Padua Training. A experiência é premium, esportiva, sóbria e objetiva. A fonte é Lato; cores e temas foram definidos no brief fornecido.

## Evidence on Hand

Não há logo, dados reais, credenciais, URLs, chaves nem conteúdo clínico fornecidos. Dados de demonstração devem ser sintéticos e identificados como tal.

## Product Principles

1. Segurança e privacidade são requisitos do domínio, não escolhas de interface.
2. Ações frequentes do aluno devem ser legíveis e rápidas no celular.
3. Administração deve expor somente o contexto que cada papel precisa operar.
4. Histórico publicado e clínico é preservado, nunca removido por conveniência.

## Accessibility & Inclusion

Suporte a tema do sistema, contraste acessível, foco visível no web, teclado navegável, labels persistentes e alvos de toque mínimos de 44 px.
