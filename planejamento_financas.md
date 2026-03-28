# Planejamento — Aplicativo de Finanças Pessoais
> Documento vivo. Versão 1.1 — Março 2026

---

## 1. Visão Geral

Um aplicativo **local-first** de finanças pessoais para **Windows** e **Android**, com um único codebase em Flutter/Dart. O app oferece controle completo de gastos, orçamento mensal e metas financeiras — sem depender de nenhum servidor externo ou conta em nuvem. Os dados pertencem ao usuário e ficam no dispositivo dele.

**Perfil de desenvolvimento:**
- Desenvolvedor com experiência prévia em programação, novo em Dart/Flutter
- Abordagem: desenvolvimento conjunto, com explicação de cada decisão
- Ritmo: um módulo por vez, com revisão antes de avançar

---

## 2. Decisão de Stack

### Por que Flutter?

| Critério | Flutter | .NET MAUI | Electron | Tauri |
|---|---|---|---|---|
| Windows nativo | ✅ | ✅ | ✅ | ✅ |
| Android nativo | ✅ | ✅ | ❌ | ❌ |
| Codebase único | ✅ | ✅ | — | — |
| Sem Chromium | ✅ | ✅ | ❌ | ⚠️* |
| UI rica e customizável | ✅✅ | ✅ | ✅ | ✅ |
| Curva de aprendizado | Suave | Média | Suave (JS) | Média |

*Tauri no Windows usa WebView2 (Edge/Chromium). Flutter renderiza com Skia/Impeller — sem dependência de browser engine.

**Flutter vence porque:** um projeto → Windows + Android, compilação nativa, excelente para UIs ricas, e Dart é fácil de aprender para quem já programou (sintaxe próxima de Java/TypeScript/Kotlin).

### Stack completa

| Camada | Tecnologia | Função |
|---|---|---|
| UI + Lógica | Flutter + Dart | Telas, componentes, lógica de negócio |
| Banco de dados | SQLite via `drift` | Persistência local, tipo-segura |
| Gerenciamento de estado | `flutter_riverpod` | Compartilhar estado entre telas |
| Gráficos | `fl_chart` | Charts nativos, sem WebView |
| Tipografia | `google_fonts` | DM Sans + Spline Sans |
| Ícones | `lucide_icons` | Ícones modernos e consistentes |
| Formatação | `intl` | Moeda (R$), datas em pt-BR |
| PDF Export | `pdf` + `printing` | Relatórios exportáveis |
| Backup | `file_picker` + `share_plus` | Import/export de arquivo JSON |

---

## 3. Escopo do MVP (validado)

### ✅ Dentro do MVP

#### Módulo 1 — Transações (Core)
- Registrar receitas e despesas
- Campos: data, valor, categoria, conta, descrição, método de pagamento
- Transações recorrentes (mensal principalmente)
- Parcelamento (gera N lançamentos futuros)
- Filtros por período e categoria
- Edição e exclusão

#### Módulo 2 — Contas e Carteiras
- Múltiplas contas: corrente, poupança, carteira física, cartão de crédito
- Saldo inicial configurável
- Transferência entre contas
- Saldo consolidado (patrimônio líquido)

#### Módulo 3 — Orçamento Mensal
- Definir limite de gasto por categoria no mês
- Barra de progresso visual (quanto foi usado do orçamento)
- Alerta visual ao atingir 80% e 100%
- Comparativo mês a mês

#### Módulo 4 — Metas Financeiras
- Criar meta com nome, valor alvo, data alvo, conta vinculada
- Progresso visual (valor atual vs. meta)
- Contribuição manual
- Projeção simples de data de conclusão (com base no ritmo de contribuição)

#### Dashboard
- Saldo total consolidado
- Resumo do mês: receitas, despesas, resultado
- Gastos por categoria (donut chart)
- Evolução do saldo (line chart — 6 meses)
- Metas em andamento (cards)
- Próximas contas recorrentes

#### Configurações
- Categorias customizáveis (nome, cor, ícone)
- Tema claro / escuro / sistema
- Backup manual (export/import JSON)
- Moeda padrão

### ❌ Fora do MVP (versão futura)

- Módulo de investimentos completo
- Importação de extrato OFX/CSV do banco
- Sincronização automática entre dispositivos
- Cotação automática de ativos
- Notificações/lembretes
- Anexar foto de comprovante
- Biometria/PIN de segurança
- Multi-perfil (família)

---

## 4. Arquitetura do Projeto

```
finance_app/
├── lib/
│   ├── main.dart                  # Ponto de entrada
│   ├── app.dart                   # MaterialApp, tema, rotas
│   │
│   ├── core/
│   │   ├── database/
│   │   │   ├── app_database.dart  # Configuração Drift
│   │   │   ├── tables/            # Definição das tabelas
│   │   │   └── daos/              # Queries por domínio
│   │   ├── models/                # Classes de domínio puras
│   │   ├── services/              # Lógica de negócio (cálculos)
│   │   └── utils/
│   │       ├── currency.dart      # Formatação R$
│   │       ├── date.dart          # Formatação de datas
│   │       └── validators.dart    # Validação de formulários
│   │
│   ├── features/
│   │   ├── dashboard/
│   │   │   ├── providers/         # Estado e dados do dashboard
│   │   │   ├── screens/           # DashboardScreen
│   │   │   └── widgets/           # Cards, charts do dashboard
│   │   ├── transactions/
│   │   │   ├── providers/
│   │   │   ├── screens/           # Lista, formulário de nova transação
│   │   │   └── widgets/
│   │   ├── accounts/
│   │   ├── budget/
│   │   ├── goals/
│   │   └── settings/
│   │
│   └── shared/
│       ├── widgets/               # Botões, inputs, cards reutilizáveis
│       └── theme/                 # Cores, tipografia, estilos globais
│
├── assets/
│   └── fonts/                     # Fontes locais (se necessário)
│
├── pubspec.yaml
└── README.md
```

**Por que essa estrutura?**
Organizamos por *feature* (funcionalidade), não por tipo de arquivo. Isso significa que tudo relacionado a "transações" fica junto. Facilita muito encontrar código e trabalhar em uma feature sem mexer nas outras.

---

## 5. Banco de Dados — Schema

```sql
-- Contas bancárias e carteiras
accounts (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT,          -- 'checking', 'savings', 'cash', 'credit'
  initial_balance REAL DEFAULT 0,
  color INTEGER,
  icon TEXT,
  is_active INTEGER DEFAULT 1,
  created_at INTEGER
)

-- Categorias de transação
categories (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT,          -- 'income' ou 'expense'
  color INTEGER,
  icon TEXT,
  is_default INTEGER DEFAULT 0
)

-- Transações (core do sistema)
transactions (
  id INTEGER PRIMARY KEY,
  account_id INTEGER REFERENCES accounts(id),
  category_id INTEGER REFERENCES categories(id),
  type TEXT,              -- 'income', 'expense', 'transfer'
  amount REAL NOT NULL,
  date INTEGER NOT NULL,  -- timestamp Unix
  description TEXT,
  notes TEXT,
  payment_method TEXT,
  -- recorrência
  is_recurring INTEGER DEFAULT 0,
  recurrence_type TEXT,   -- 'monthly', 'weekly', 'yearly'
  recurrence_parent_id INTEGER,
  -- parcelamento
  installment_total INTEGER,
  installment_current INTEGER,
  installment_group_id TEXT,
  -- transferência
  transfer_pair_id INTEGER,
  created_at INTEGER,
  updated_at INTEGER
)

-- Orçamentos mensais
budgets (
  id INTEGER PRIMARY KEY,
  category_id INTEGER REFERENCES categories(id),
  year INTEGER NOT NULL,
  month INTEGER NOT NULL,  -- 1-12
  limit_amount REAL NOT NULL
)

-- Metas financeiras
goals (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  target_amount REAL NOT NULL,
  current_amount REAL DEFAULT 0,
  target_date INTEGER,
  account_id INTEGER REFERENCES accounts(id),
  color INTEGER,
  icon TEXT,
  status TEXT DEFAULT 'active',  -- 'active', 'completed', 'paused'
  created_at INTEGER
)

-- Contribuições às metas (histórico)
goal_contributions (
  id INTEGER PRIMARY KEY,
  goal_id INTEGER REFERENCES goals(id),
  amount REAL NOT NULL,
  date INTEGER NOT NULL,
  note TEXT
)
```

---

## 6. Design Visual

### Princípios
O app transmite **controle, clareza e confiança** — o que o usuário precisa sentir ao gerenciar dinheiro. UI limpa, dados em destaque, nenhuma decoração sem função.

### Paleta de Cores

```
Tema Claro
  primary:        #1A6B4A  — Verde-esmeralda escuro (ação principal)
  primaryLight:   #E8F5EF  — Verde muito claro (fundos de destaque)
  accent:         #F0A500  — Âmbar (metas, destaques positivos)
  danger:         #D94F4F  — Vermelho suave (despesas, alertas)
  success:        #2E9E6B  — Verde médio (receitas, progresso positivo)
  background:     #F7F8FA  — Cinza quase branco
  surface:        #FFFFFF  — Cards e painéis
  textPrimary:    #1A1E2C  — Quase preto (títulos)
  textSecondary:  #6B7280  — Cinza médio (legendas, labels)
  border:         #E5E7EB  — Divisores

Tema Escuro (derivado automaticamente)
  background:     #0F1117
  surface:        #1C1F2E
  textPrimary:    #F1F3F9
```

### Tipografia
- **DM Sans** — corpo de texto, labels, valores monetários. Legível, moderna, sem ser genérica.
- **Spline Sans** — títulos de seção e números grandes no dashboard. Personalidade sem perder clareza.

### Componentes-chave

**Card de transação:**
```
┌─────────────────────────────────────────────┐
│ 🛒  Supermercado Extra          - R$ 234,50 │
│     Alimentação · 15 mar          Nubank    │
└─────────────────────────────────────────────┘
```

**Card de meta:**
```
┌─────────────────────────────────────────────┐
│ ✈️  Viagem ao Japão                         │
│     R$ 4.200 / R$ 15.000                   │
│     ████████░░░░░░░░░░░░  28%              │
│     Previsão: out/2026                      │
└─────────────────────────────────────────────┘
```

**Barra de orçamento:**
```
Alimentação          R$ 780 / R$ 1.000
████████████████░░░  78% ⚠️
```

### Layout Windows (Desktop)

```
┌──────────┬────────────────────────────────────┐
│          │                                    │
│ SIDEBAR  │      CONTEÚDO PRINCIPAL            │
│          │                                    │
│ Dashboard│                                    │
│ Transaç. │                                    │
│ Orçament │                                    │
│ Metas    │                                    │
│ Configur │                                    │
│          │                                    │
└──────────┴────────────────────────────────────┘
```
- Sidebar fixa, 220px de largura
- Conteúdo com scroll vertical
- Mínimo suportado: 1024 × 768

### Layout Android (Mobile)

```
┌──────────────┐
│   Dashboard  │
│  (conteúdo)  │
│              │
│           ➕ │  ← FAB: nova transação
├──┬──┬──┬──┬──┤
│🏠│💳│📊│🎯│⚙️│  ← Bottom navigation
└──┴──┴──┴──┴──┘
```
- 5 abas: Dashboard, Transações, Orçamento, Metas, Configurações
- FAB para ação principal (nova transação)

---

## 7. Plano de Desenvolvimento — Fases

### Fase 0 — Setup do Ambiente
Estimativa: meio dia

- [ ] Instalar Flutter SDK
- [ ] Instalar VS Code + extensões Flutter/Dart
- [ ] Instalar Android Studio (apenas para emulador Android)
- [ ] Configurar emulador Android
- [ ] Criar projeto: `flutter create finance_app`
- [ ] Verificar build Windows: `flutter run -d windows`
- [ ] Verificar build Android no emulador
- [ ] Adicionar dependências no `pubspec.yaml`

### Fase 1 — Fundação (Semana 1)
- [ ] Configurar banco de dados Drift (schema completo)
- [ ] Implementar sistema de temas (claro/escuro)
- [ ] Criar layout de navegação (sidebar Windows + bottom nav Android)
- [ ] CRUD de contas
- [ ] CRUD de categorias com seletor de cor e ícone

### Fase 2 — Core de Transações (Semana 2)
- [ ] Tela de lista de transações com filtros
- [ ] Formulário de nova transação (receita/despesa)
- [ ] Transações recorrentes
- [ ] Parcelamentos
- [ ] Transferência entre contas
- [ ] Cálculo de saldo por conta

### Fase 3 — Dashboard (Semana 3)
- [ ] Resumo mensal (receitas, despesas, resultado)
- [ ] Donut chart de gastos por categoria
- [ ] Line chart de evolução do saldo
- [ ] Cards de contas com saldo
- [ ] Lista de próximas recorrências

### Fase 4 — Orçamento (Semana 3-4)
- [ ] Tela de orçamento mensal
- [ ] CRUD de limites por categoria
- [ ] Barras de progresso
- [ ] Alertas visuais (80%/100%)
- [ ] Navegação entre meses

### Fase 5 — Metas (Semana 4)
- [ ] Tela de lista de metas
- [ ] Formulário de nova meta
- [ ] Tela de detalhe da meta com histórico
- [ ] Contribuição manual
- [ ] Projeção de conclusão

### Fase 6 — Polimento e Deploy (Semana 5)
- [ ] Export/Import JSON (backup)
- [ ] Refinamento visual geral
- [ ] Dados de demonstração para onboarding
- [ ] Build Windows (MSIX)
- [ ] Build Android (APK)
- [ ] Testes nas duas plataformas

---

## 8. Deploy

### Windows
```bash
flutter build windows --release
```
- Gera pasta em `build/windows/x64/runner/Release/`
- **Opção A (simples):** zipar a pasta `Release/` — usuário descompacta e executa `finance_app.exe`
- **Opção B (instalador):** pacote `msix` gera instalador nativo do Windows com ícone no menu iniciar
- Recomendado: Opção B para uso pessoal (mais profissional e limpo)

### Android
```bash
flutter build apk --release
```
- Gera `build/app/outputs/flutter-apk/app-release.apk`
- Copiar para o celular via cabo USB ou Google Drive
- No celular: ativar "Instalar de fontes desconhecidas" → instalar APK
- Alternativa futura: Google Play Store (taxa única de U$25)

### Sincronização Windows ↔ Android (MVP)
- Manual via export/import JSON
- Windows → exportar backup → salvar no Google Drive
- Android → importar backup do Google Drive

---

## 9. Decisões em Aberto

| Decisão | Status | Resolução |
|---|---|---|
| Módulo de investimentos | ⏸️ Postergado | Versão 2.0 após MVP estável |
| Notificações de contas | ⏸️ Postergado | Fase futura |
| Importação de extrato OFX | ⏸️ Postergado | Feature de alto valor, mas complexa |
| Sync automático entre devices | ⏸️ Postergado | MVP usa export/import manual |
| Biometria/PIN | ⏸️ Postergado | Adicionar se houver demanda |
| Moeda múltipla | 🔍 A definir | MVP usa apenas R$ |

---

## 10. Riscos e Mitigações

| Risco | Probabilidade | Mitigação |
|---|---|---|
| Curva de aprendizado em Dart | Média | Dart é próximo de Java/TS; desenvolvimento conjunto minimiza |
| Flutter Desktop com quirks no Windows | Baixa | Maduro em 2026; testar cedo a cada feature |
| Drift (ORM) com curva própria | Média | Documentação excelente; geração de código automatiza muito |
| Perda de dados sem backup | Média | Lembrar usuário de exportar; backup automático na v2 |
| Scope creep (adicionar features no meio) | Alta | Seguir rigorosamente o MVP; anotar ideias para v2 |

---

## 11. Glossário Dart/Flutter (referência rápida)

| Termo | O que é |
|---|---|
| `Widget` | Bloco de construção da UI (tudo no Flutter é um widget) |
| `StatelessWidget` | Widget sem estado interno (só exibe dados) |
| `StatefulWidget` | Widget com estado que pode mudar (ex: formulário) |
| `BuildContext` | Referência à posição do widget na árvore |
| `Riverpod` | Sistema de gerenciamento de estado (compartilhar dados entre telas) |
| `Future<T>` | Operação assíncrona (equivalente a Promise em JS) |
| `Stream<T>` | Fluxo de dados que atualiza automaticamente (ex: query no banco) |
| `Scaffold` | Estrutura básica de uma tela (AppBar + body + FAB) |
| `Navigator` | Sistema de navegação entre telas |
| `pubspec.yaml` | Arquivo de configuração do projeto (equivalente ao package.json) |
| `Drift` | ORM para SQLite em Flutter; define tabelas em Dart, gera queries |
| `DAO` | Data Access Object — classe que agrupa as queries de um domínio |

---

## 12. Próximos Passos

1. ✅ **Planejamento v1.1 validado** — escopo, stack, visual e fases definidos
2. ⏭️ **Setup do ambiente** — próximo passo antes de qualquer código
3. ⏭️ **Fase 1** — banco de dados e navegação base
4. ⏭️ **Fase 2** — transações (core)

---

*Este documento é atualizado a cada decisão relevante. Versão atual: 1.1*
