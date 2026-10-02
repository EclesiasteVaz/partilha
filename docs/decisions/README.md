# Architectural Decision Records

Cada registo documenta uma decisão com impacto no desenvolvimento futuro, como
exigido por `AGENTS.md` §59.

Formato de cada registo:

```text
Contexto              → o problema e a evidência
Decisão               → o que foi escolhido
Alternativas         → o que foi rejeitado e porquê
Consequências         → custos, riscos, e trabalho que passa a existir
```

## Registo

| # | Título | Estado |
|---|---|---|
| [0001](0001-transporte-websocket-dart-io.md) | Transporte: WebSocket cru sobre `dart:io` | Aceito |
| [0002](0002-mdns-provider.md) | Provider de descoberta mDNS | Aceito, spike pendente |
| [0003](0003-token-fora-do-mdns.md) | O token nunca sai em metadados de descoberta | Aceito |
| [0004](0004-sem-dio-no-mvp.md) | Sem HTTP client (Dio) no MVP | Aceito |

## Regra

Um registo **não é editado** quando a decisão muda. Fica marcado como
`Substituído` e escreve-se um registo novo que o referencie. Isto mantém o
histórico honesto e impede que a documentação deixe de explicar porque é que o
código é como é.