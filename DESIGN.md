---
name: Padua Training
description: Gestão de treino individual com clareza, privacidade e ritmo.
colors:
  light-background: "#F8F4F6"
  light-surface: "#FFFBFD"
  light-elevated: "#F0E9ED"
  dark-background: "#191719"
  dark-surface: "#242125"
  dark-elevated: "#302B30"
  primary: "#9E365F"
  primary-dark: "#B95078"
  text-light: "#2D252A"
  text-dark: "#F3EEF1"
  border-light: "#D8CCD2"
  border-dark: "#494149"
  success: "#39795D"
  danger: "#B84250"
typography:
  display:
    fontFamily: "Lato"
    fontSize: "34px"
    fontWeight: 900
    lineHeight: 39
    letterSpacing: "-0.02em"
  body:
    fontFamily: "Lato"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 24
  label:
    fontFamily: "Lato"
    fontSize: "15px"
    fontWeight: 700
rounded:
  control: "12px"
  surface: "16px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "24px"
  xl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "#FFF8FB"
    rounded: "{rounded.control}"
    height: "48px"
  button-secondary:
    backgroundColor: "{colors.light-elevated}"
    textColor: "{colors.text-light}"
    rounded: "{rounded.control}"
    height: "48px"
---

# Design System: Padua Training

## Overview

**Creative North Star: "Precisão em movimento"**

Padua Training traz a disciplina silenciosa do treino bem orientado: cada tela prioriza a próxima ação, remove ruído e respeita a concentração de quem está em movimento. A sofisticação vem de tipografia firme, contraste controlado e uma paleta vinho usada com intenção, nunca de ornamento.

As superfícies operam em camadas tonais, adequadas tanto à iluminação de uma academia quanto a uma sessão administrativa prolongada. O sistema é mobile-first para o aluno e amplia a densidade para fluxos administrativos sem perder legibilidade.

**Key Characteristics:**

- Clareza operacional antes de decoração.
- Acento vinho reservado para ações e decisões importantes.
- Linguagem direta, humana e sem promessas não verificadas.

## Colors

A paleta mistura vinho atlético, superfícies rosadas neutras e sinais de estado contidos.

### Primary

- **Vinho de impulso:** cor de ações primárias, seleção e foco de decisão. Em tema escuro, a variação mais clara mantém contraste.

### Neutral

- **Superfícies de recuperação:** fundo, superfície e superfície elevada criam hierarquia por tom em vez de sombras decorativas.
- **Texto de leitura:** primário e secundário preservam ritmo e legibilidade em ambos os temas.

**The Accent Discipline Rule.** O vinho aparece para ação, estado selecionado ou informação decisiva; não colore estruturas inteiras da tela.

## Typography

**Display Font:** Lato
**Body Font:** Lato
**Label/Mono Font:** Lato

**Character:** Títulos em Black dão impulso sem recorrer a uma fonte ostensiva; corpo em Regular facilita leitura rápida; ações e rótulos em Bold sinalizam decisão.

### Hierarchy

- **Display:** Black, 34px, 39px; título de chegada e momentos de orientação.
- **Headline:** Black, 28px; títulos de fluxo.
- **Body:** Regular, 16px, 24px; instruções e estados.
- **Label:** Bold, 15px; campos, ações e informação operacional.

**The Direct Label Rule.** Todo controle recebe uma ação ou campo explícito; não há rótulos decorativos acima de títulos.

## Layout

O aluno encontra uma coluna central com leitura curta, respiro de 24px entre grupos e controles com ao menos 48px de altura. Em telas maiores, a mesma superfície mantém largura de leitura controlada antes de ganhar grades administrativas; nenhum fluxo deve depender de rolagem horizontal.

## Elevation & Depth

O sistema é tonal por padrão: fundo, superfície e superfície elevada distinguem contexto sem sombreamento ornamental. Bordas de 1px aparecem apenas para separar uma superfície ou definir campos editáveis.

**The Tonal Hierarchy Rule.** Uma mudança de contexto usa primeiro tom e espaçamento; elevação física só será introduzida quando uma interação realmente precisar flutuar.

## Shapes

Controles têm curvas firmes de 12px; superfícies agrupadoras usam 16px. O desenho evita pílulas em blocos de conteúdo e não empilha cartões dentro de cartões.

## Components

### Buttons

- **Shape:** retângulo suavemente curvo (12px), sempre com 48px mínimos de altura.
- **Primary:** vinho, texto claro em Bold; reservado para a próxima ação inequívoca.
- **Secondary:** superfície elevada, borda de 1px e texto primário; usado para retorno e ações auxiliares.
- **Focus:** anel visível em cor de marca com contraste contra a superfície.

### Cards / Containers

- **Corner Style:** superfície de 16px.
- **Background:** superfície base, nunca vidro ou gradiente.
- **Border:** 1px sem sombra; padding de 24px na primeira camada.

### Inputs / Fields

- **Style:** superfície elevada, traço de 1px e altura mínima de 48px.
- **Focus:** o traço muda para marca; erro usa danger e uma mensagem textual persistente.

## Do's and Don'ts

### Do:

- **Do** usar Lato Black somente em títulos de destaque e Lato Bold em ações e rótulos.
- **Do** manter labels persistentes e mensagens de erro que expliquem a recuperação.
- **Do** oferecer temas claro e escuro a partir da preferência do dispositivo.

### Don't:

- **Don't** usar preto ou branco absolutos como fundo principal.
- **Don't** usar gradiente em texto, vidro decorativo, ícones emoji ou sombras como estrutura.
- **Don't** tratar informação clínica como conteúdo de demonstração visual.
