# 0005 — Manter o scaffolding das plataformas não-alvo e vigiar o estado

- **Estado:** Aceito
- **Data:** 2026-10-02
- **Decide:** que pastas de plataforma ficam no repositório e como se declara suporte

## Contexto

O `flutter create` gera pastas para todas as plataformas suportadas pelo SDK:
`android/`, `ios/`, `macos/`, `linux/`, `windows/` e `web/`.

O `AGENTS.md` §41 fixa **Android e macOS** como prioridades de implementação e
é explícito quanto a não declarar suporte:

> Do not claim support for platforms that have not actually been implemented
> and tested.

Isto cria uma tensão real:

| Opção | Custo |
|---|---|
| Apagar `ios/`, `linux/`, `windows/`, `web/` | signalling limpo, mas uma contribuição para outra plataforma tem de regenerar o projeto e volta a correr o risco de divergir do scaffolding dos alvos principais |
| Manter todas as pastas | contribuição imediata, mas uma pasta existente **parece** um sinal de suporte — sobretudo porque é o que um leitor assume ao ver `ios/` num repositório Flutter |

O risco real não é o conteúdo das pastas. É a **inferência**: uma pasta
plataforma é lida como "isto funciona aqui". Manter o scaffolding sem tornar o
estado explícito transforma uma ambiguidade de leitura numa falsa afirmação.

Não havia, em lado nenhum, um registo de qual plataforma está em que estado.

## Decisão

**Manter todas as pastas de plataforma e declarar o estado de implementação
explicitamente.**

Duas decisões distintas, deliberadamente separadas:

1. **As pastas ficam.** São saída intacta do `flutter create`. Nenhuma
   permissão, serviço de plataforma ou feature foi escrita para elas.
2. **O estado fica escrito, e é vigiado.** O estado de implementação está
   registado em exatamente dois sítios, que têm de ser actualizados em conjunto:

   | Local | Papel |
   |---|---|
   | `README.md` → *Platform Support Status* | comunica a quem lê o repositório |
   | `docs/ARCHITECTURE.md` §48.1 | fonte técnica, referenciada pelo código e pela revisão |

Vocabulário de estado, idêntico nos dois sítios:

```text
Primary target  →  âmbito aprovado (§41); planeado, pode ser declarado meta
Scaffold only   →  a pasta existe, é saída intacta do `flutter create`,
                   nada foi implementado para a plataforma
Not supported   →  não compilado, não testado, sem garantia de comportamento
```

Nenhum outro documento pode afirmar ou sugerir suporte a uma plataforma.

## Promoção de uma plataforma

Subir de `Scaffold only` a `Primary target` **não** é consequência de
existirem permissões declaradas ou de o código compilar. Exige:

- a funcionalidade compila e corre na plataforma;
- as permissões necessárias estão declaradas e pedidas através de
  `PermissionService` (§40);
- o comportamento específico da plataforma está isolado num serviço
  próprio (§41, §49) — não espalhado por `Platform.isX`;
- a plataforma é compilada e exercitada em CI, ou a verificação manual está
  documentada (§64);
- as limitações ficam registadas em `features/<feature>/FEATURE.md` (§58).

Se uma promoção ficar por registar, a pasta volta a ser enganosa e este
registo deixa de explicar o código.

## Alternativas rejeitadas

| Alternativa | Porquê não |
|---|---|
| Apagar as pastas não-alvo | Impede contribuições de plataforma, obriga a regenerar o projeto e não remove a inferência: apenas esconde a intenção |
| Manter as pastas e não documentar nada | Pior opção: mantém o custo e a ambiguidade ao mesmo tempo |
| Declarar todas as plataformas como suportadas | Proibido por §41, e factualmente falso: nada foi compilado nem testado |
| Criar `docs/PLATFORMS.md` | A hierarquia documental é fixa em §58; uma tabela de estado cabe nos dois sítios existentes, e um ficheiro novo seria um terceiro sítio a divergir |

## Consequências

- Contribuições de plataforma não-alvo podem começar sem regenerar o
  projeto.
- `README.md` e `docs/ARCHITECTURE.md` §48.1 passam a ser **duplo obrigatório**
  em qualquer mudança de estado de plataforma.
- Uma plataforma não-alvo continua a ser *trabalho por fazer*, não uma
  capacidade. O README diz isso onde alguém vai procurar essa informação.
- Uma incoerência anterior foi corrigida em conjunto: as pastas mantêm-se, mas
  o texto legal passou a bater certo com a `LICENSE`.

## Como reverter

Se deixar de fazer sentido manter plataformas no repositório:

1. Escrever uma nova ADR (número sequencial seguinte) que substitua esta.
2. Não editar esta em silêncio: marcar como `Substituído`, como dita a regra
   do índice em `docs/decisions/README.md`.
3. Remover as pastas e as referências nos dois sítios de estado, na mesma
   mudança.