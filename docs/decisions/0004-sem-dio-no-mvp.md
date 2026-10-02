# 0004 — Sem HTTP client (Dio) no MVP

- **Estado:** Aceito
- **Data:** 2026-10-02
- **Decide:** conjunto de dependências de rede

## Contexto

O `README.md` e o `docs/ARCHITECTURE.md` listavam **Dio** como dependência de
HTTP, com um `DioNetworkClient` na matriz de isolamento de pacotes.

Ao rever o `docs/PROTOCOL.md` para a mudança de transporte (ver
`docs/decisions/0001-transporte-websocket-dart-io.md`), verificou-se que **nenhum
fluxo do MVP faz pedidos HTTP**.

O `HttpServer` é usado apenas para *aceitar* a conexão e fazer o upgrade para
WebSocket. Isso é `dart:io` servidor, não um cliente HTTP. Nenhum dos quatro
features precisa de cliente HTTP:

| Feature | Precisa de HTTP cliente? |
|---|---|
| Settings | Não — SQLite local |
| Discovery | Não — mDNS |
| Pairing | Não — QR local |
| File Transfer | Não — WebSocket |

O `AGENTS.md` §55 é explícito: não introduzir uma dependência para
funcionalidade que o SDK já resolve. O `dart:io` já resolve — e sem dependência.

## Decisão

**Nenhum cliente HTTP no MVP.**

Dio e qualquer outro pacote HTTP ficam **fora** do stack documentado.

```text
AGENTS.md §55  →  não adicionar dependência sem necessidade concreta
docs/PROTOCOL.md → nenhum fluxo HTTP definido
                    ↓
                  Nenhum cliente HTTP no MVP
```

O conjunto de dependências do MVP fica:

```text
Flutter · Dart SDK
GetIt
freezed + json_serializable + build_runner
go_router
sqflite
hugeicons
mdns_dart        (pendente do spike da ADR 0002)
mobile_scanner   (QR)
```

`dart:io`'s `HttpServer` continua a ser usado no lado receptor, mas isso é
infra-estrutura de socket, não um cliente HTTP.

## Alternativas rejeitadas

| Alternativa | Porquê não |
|---|---|
| Manter Dio "para o futuro" | Dependência não usada é dívida e superfície de ataque sem benefício |
| `http` do Dart SDK | Mesma conclusão: não há fluxo |
| Manter Dio porque já estava documentado | A documentação estava errada; `AGENTS.md` §77 manda corrigir documentação obsoleta, não preservá-la |

## Consequências

- `DioNetworkClient` sai da matriz de isolamento de pacotes.
- `NetworkClient` não entra na matriz de abstrações.
- Se surgir um fluxo HTTP genuíno, isso é uma **nova ADR** a aprovar, não uma
  aplicação silenciosa desta.

## Como reverter

Se um fluxo HTTP for necessário e aprovado:

1. Escrever uma nova ADR (número sequencial seguinte).
2. Adicionar o pacote a `pubspec.yaml`.
3. Introduzir `NetworkClient` na matriz de abstrações de
   `docs/ARCHITECTURE.md` §70, com o `Impl` nomeado pela tecnologia.
4. Manter o cliente HTTP isolado atrás do contrato, nunca exposto ao domínio.