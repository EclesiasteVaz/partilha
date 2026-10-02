# 0001 — Transporte: WebSocket cru sobre `dart:io`

- **Estado:** Aceito
- **Data:** 2026-10-02
- **Decide:** camada de comunicação device-to-device
- **Substitui:** Socket.IO

## Contexto

O stack documentado usava Socket.IO para comunicação device-to-device e Dio
para HTTP.

A investigation de viabilidade encontrou um bloqueio duro: **Socket.IO não é
implementável em Flutter↔Flutter**.

| Lado | Pacote | Versão | Protocolo | Estado |
|---|---|---|---|---|
| Cliente | `socket_io_client` | 3.1.6 | socket.io-client **v4.x** | mantido, ~251k downloads |
| Servidor | `socket_io` | 1.0.1 | Socket.IO **v2.0.1** | publicado há 5 anos, ~1.58k downloads |

O único servidor Socket.IO em Dart fala o protocolo v2. O cliente Dart mantido
fala v4. A tabela de compatibilidade do pub.dev **não tem linha para cliente v4
com servidor v2**. Como os dois lados do Partilha são Flutter, um deles tem de
ser servidor — logo não existe combinação compatível.

Um segundo problema: engine.io envelopa toda a tráfego em frames de texto, o
que custa bytes e estraga o controlo de *backpressure* binário, exactamente o
que uma aplicação de transferência de ficheiros precisa.

## Decisão

A comunicação device-to-device usa um **WebSocket cru sobre `dart:io`**.

```text
Receiver: HttpServer.bind(...) + WebSocketTransformer.upgrade(...)
Sender:   WebSocket.connect(...)
```

Não é usado nenhum pacote de rede de terceiros.

O `dart:io` fica isolado atrás de uma abstracção de projecto:

```text
Domain / Application
        ↓
WebSocketTransport   ← contrato do projecto
        ↓
dart:io WebSocket    ← só na camada de dados
```

## Alternativas rejeitadas

| Alternativa | Porquê não |
|---|---|
| `socket_io` servidor v2 + cliente antigo | Código com 5 anos, sem manutenção, CVEs desconhecidos, e obriga a fixar um cliente também abandonado |
| Servidor Socket.IO não-Dart (Node.js) | Introduz runtime externo num app local; multiplica plataformas e empacotamento |
| HTTP com `StreamedRequest` | Mais simples, mas bidireccional fica frágil: canal de controlo separado, sem ordem garantida |
| Nenhuma alteração, esperar | O modelo é inexequível como está; adiar não resolve |

## Consequências

**Positivas**

- Zero dependências de rede de terceiros.
- Controlo total de frames binários e de `StreamSubscription.pause/resume`.
- Protocolo de framing desenhado por nós (ver `docs/PROTOCOL.md` §33.1).
- Sem risco de adopção de um pacote de 5 anos.

**Negativas / custos**

- Framing, heartbeats, reconexão e validação de mensagens passam a ser
  responsabilidade nossa.
- Precisamos de implementar validação de limites de frame para não expor
  memória (ver `docs/SECURITY.md`).
- O TLS com certificado auto-assinado exige um modelo explícito de pinning;
  `wss://` sozinho **não** resolve a autenticação. Registado como
  `OPEN — APPROVAL REQUIRED` em `docs/SECURITY.md` §26.1.

## Requisitos de implementação

```text
[ ] dart:io não aparece em domain/, application/ ou presentation/
[ ] dart:io WebSocket não vaza para contratos de domínio
[ ] SocketException é convertido em NetworkFailure na fronteira de dados
[ ] Framing não é inventado — ver docs/PROTOCOL.md §33.1
[ ] Limites de frame e de mensagem estão definidos e são validados
[ ] Backpressure é aplicado; nunca bufferizar o ficheiro inteiro
```

## Estado do enquadramento

O esquema exacto de framing (discriminador control/data, opcode, tamanho
máximo de frame) continua `OPEN — APPROVAL REQUIRED`. Nenhum código de
transporte deve ser escrito antes dessa decisão.