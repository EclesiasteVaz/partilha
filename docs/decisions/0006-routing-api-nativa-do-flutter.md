# 0006 — Routing com a API nativa do Flutter, sem `go_router`

- **Estado:** Aceito
- **Data:** 2026-10-04
- **Substitui:** a menção a `go_router` em `docs/ARCHITECTURE.md` §61,
  `README.md` e `docs/decisions/0004-sem-dio-no-mvp.md`
- **Decide:** qual solução de routing o projecto usa

## Contexto

`docs/ARCHITECTURE.md` §61 indicava `go_router` como a solução de routing
aprovada, e a ADR 0004 listava-o entre as dependências do MVP. O pacote nunca
chegou ao `pubspec.yaml`, porque não havia ecrã nenhum para rotear.

Quando o primeiro ecrã real — Settings — foi implementado, a escolha foi feita
por quem implementou e não por quem aprova: usou-se a API nativa do Flutter
(`MaterialApp.router` com `RouterDelegate` e `RouteInformationParser`). Isto é
uma troca de solução de routing, que o `AGENTS.md` §2.1 e §88 proíbem fazer sem
aprovação. Aapproval foi obtida depois de o código existir, e este registo
documenta a decisão tal como foi tomada.

## Opções consideradas

| Opção | Custo |
|---|---|
| `go_router` | navegação declarativa e `ShellRoute` pronta; acrescenta uma dependência de routing a um projecto que, no `AGENTS.md` §54, evita dependências sem necessidade concreta |
| API nativa do Flutter | zero dependências; `RouterDelegate` e `RouteInformationParser` são infrastructure do próprio SDK, já pinados pela versão do Flutter |

## Decisão

Usar a API nativa do Flutter. `go_router` **não** é dependência do projecto.

O routing vive em `lib/core/routing/` e é exposto por um barrel:

```text
AppRoute                     rota tipada, não uma string
AppRouteInformationParser    URL ↔ AppRoute
AppRouterDelegate            constrói a página a partir da rota
CurrentRoute                 estado de navegação observado
```

Três restrições explicam a forma:

**As rotas são um enum, não strings.** `AppRoute` é fechado. Uma rota
desconhecida ou um erro de escrita não pode produzir um ecrã arbitrário: o
parser mapeia o que não conhece para a rota inicial, em vez de propagar texto
para o `build`.

**O delegate resolve ecrãs, não constrói-os.** `AppRouterDelegate` pede
`SettingsScreen` ao `InjectionContainer`; a feature continua a não saber que
existe routing. Um `switch` de ecrãs dentro de `main.dart` seria o mesmo
conteúdo num sítio diferente, e é assim que um placeholder se torna permanente.

**O delegate pertence ao widget que o hospeda.** `CurrentRoute` é um
`ValueNotifier` criado em `main()` e passado a `PartilhaApp`, para que o
delegate não sobreviva ao widget. É a razão de `PartilhaApp` exigir
`currentRoute` em vez de o construir internamente.

## Actualização — o fluxo de envio passou a ter três rotas

Quando a ADR foi escrita, o projecto tinha uma rota. `AppRoute.send` estava
declarado sem página, e o delegate construía um único `Page` que substituía o
anterior conforme a rota mudava. Isso não é uma pilha, e o `popRoute` devolvia
sempre `false`.

O fluxo de envio tem três passos — Settings → Discovery → Transfer — e esse
modelo não os suporta: o gesto de voltar do sistema fechava a aplicação a
partir de qualquer ecrã que não fosse o primeiro, e não havia forma de desfazer
uma navegação para a frente.

`CurrentRoute` passou a manter uma pilha, o delegate constrói um `Page` por
entrada, e `popRoute` desfaz uma entrada. `AppRoute.transfer` foi acrescentada
para o passo de selecção de ficheiros, e `pushRoute` é a forma de avançar.

A distinção que importa: **avançar empilha, um deep link substitui.** Uma URL
ou um estado restaurado descreve o destino completo, portanto
`setNewRoutePath` continua a substituir a pilha; mover-se para a frente a partir
da UI empilha, para que Back revele o ecrã de onde o utilizador veio.

Isto não é uma troca de solução de routing. `RouterDelegate`,
`RouteInformationParser` e o enum continuam a ser os mesmos. É a mesma decisão,
com a pilha que a UI precisa.

## Consequências

- `PartilhaApp` não tem construtor sem argumentos. Qualquer teste que o
  instancie tem de fornecer um `CurrentRoute`, o que é explícito sobre o que a
  app precisa para funcionar.
- Não há `ShellRoute`, deep links tipados nem `redirect`. Se a navegação
  crescer para o ponto em que isso passe a custar mais do que poupar, a
  decisão deve ser reaberta com um ADR novo, não corrigida em silêncio.
- `AppRoute.send` e `AppRoute.transfer` têm ambos página. Qualquer rota nova
  precisa de um caso em `_pageFor`, e o enum é fechado para que uma rota sem
  ecrã não compile.
- `Router.of(context).routerDelegate` está tipado como
  `RouterDelegate<Object?>`, portanto o `push` tipado deste projecto não é
  alcançável através dele. O cast está confinado a `pushRoute`, que degrada para
  `setNewRoutePath` se o delegate não for o nosso. É o custo de não usar um
  pacote de routing, e é o motivo de a ADR 0006 continuar válida.

## Alternativas rejeitadas

- **`go_router`**, como estava escrito antes: uma dependência de routing para
  duas rotas, uma delas ainda inexistente. Reavaliar se a complexidade real
  aparecer.
- **`Navigator` com `routes:` nomeadas**: strings como chaves de rota, e um
  ecrã para cada `push`. Não modela uma rota ausente.
- **Manter `RouterDelegate` e deixar `§61` como está**: documentação a mentir
  sobre o código, que o `AGENTS.md` §77 proíbe.