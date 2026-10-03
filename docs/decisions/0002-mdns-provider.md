# 0002 — Provider de descoberta mDNS

- **Estado:** Aceito com spike de validação pendente
- **Data:** 2026-10-02
- **Decide:** implementação de `DiscoveryService`
- **Bloqueia:** Fase 2 (Discovery)

## Contexto

O modelo de descoberta aprovado é assimétrico (`docs/ARCHITECTURE.md` §36):

```text
Dispositivo receptor:  anuncia-se
Dispositivo emissor:   procura
```

Isto é uma exigência real do produto: o receptor tem de expor a sua porta a
quem procura, e o `docs/ARCHITECTURE.md` §36 diz que esta distinção não pode ser
invertida.

O problema: **não existe um pacote mDNS oficial em Dart que consiga anunciar.**

| Pacote | Versão | Anuncia? | Plataformas | Nota |
|---|---|---|---|---|
| `multicast_dns` | 0.3.3+1 | **Não** | Android, iOS, Linux, macOS, Windows | Oficial (`flutter.dev`). Query-only. O código-fonte tem literalmente `// TODO: Support queries coming in for published entries.` |
| `mdns_responder` | — | Sim | **Android, iOS apenas** | Usa `NsdManager`. Sem macOS. |
| `nsd` / `flutter_nsd` | — | Sim | dependente de plataforma | Sem macOS fiável. |
| `mdns_dart` | — | **Sim** | Dart puro, multiplataforma | Port do mDNS do Go (HashiCorp). Publicado 2025-06. |

`multicast_dns` é o candidato óbvio (oficial, 3.16M downloads, suporte macOS
confirmado), mas **é query-only**: sabe procurar, não sabe responder. Como o
modelo exige que o receptor anuncie, o pacote oficial não satisfaz o requisito
sozinho.

macOS é um alvo primário, o que elimina `mdns_responder` e `nsd`.

## Decisão

O provider candidato é **`mdns_dart`**, sujeito a um spike de validação em
hardware real Android **e** macOS antes de a implementação de Discovery arrancar.

```text
DiscoveryService          ← contrato do projecto
        ↓
MdnsDiscoveryService      ← implementação de dados
        ↓
mdns_dart                 ← só depois do spike
```

`mdns_dart` foi escolhido como candidato por ser Dart puro (sem dependências
nativas, sem plugins de plataforma), por anunciar **e** descobrir, e por ser
multiplataforma.

**Isto não é uma aprovação final.** A maturidade do pacote ainda não foi
avaliada. As opções de fallback estão listadas abaixo.

## Alternativas rejeitadas (ou adiadas)

| Alternativa | Estado |
|---|---|
| `multicast_dns` sozinho | **Rejeitado** — query-only, não anuncia |
| `multicast_dns` + announce próprio | Adiado — mistura duas bibliotecas |
| `mdns_responder` | **Rejeitado** — sem macOS |
| `nsd` / `flutter_nsd` | **Rejeitado** — sem macOS fiável |
| Responder próprio sobre `RawDatagramSocket` | **Fallback.** `joinMulticast(224.0.0.251:5353)`, responder a PTR/SRV/TXT, `MulticastLock` no Android. ~400 linhas sob nosso controlo, com risco real de bugs de rede |

## O que o spike tem de validar

```text
[ ] Anuncia um serviço e um host mdns_dart / avahi-browse / dns-sd o descobre
[ ] Descobre um serviço anunciado por mdns_dart
[x] TXT records são lidos e escritos correctamente  ← unit test, sem rede
[ ] Endereços IPv4 são resolvidos e são o endereço correcto da interface
[ ] Funciona em Android (device real, com MulticastLock)
[ ] Funciona em macOS (device real)
[ ] Anunciar e procurar ao mesmo tempo não interfere
[ ] Parar de anunciar limpa o estado (sem serviços fantasma)
[ ] Performance aceitável: sem bloqueio perceptível da UI
[ ] Sem crash em interface sem multicast / airplane mode
```

## Estado do spike

**Iniciado, não concluído.** Ver §3 de `features/discovery/FEATURE.md`.

Escrito e compilado:

- `DiscoveryService` + `DiscoveredDevice` (domínio);
- `MdnsDiscoveryService` (dados), com `mdns_dart` importado exclusivamente aí;
- `DiscoveredDeviceMapper`, com unit tests para as regras de validação do
  registo não-confiável.

Nada disto foi executado contra uma rede real. Os itens acima continuam por
verificar.

Estado dos dois bloqueios identificados quando o spike foi iniciado:

- **`MulticastLock` do Android: implementado, por verificar em hardware.**
  `core/platform/multicast_lock.dart` expõe a abstracção, `MainActivity.kt`
  implementa o lado nativo com contagem de referências, e
  `CHANGE_WIFI_MULTICAST_STATE` está no manifest. O APK compila e a permissão
  foi confirmada no pacote final. Falta executar num dispositivo Android real.
  Como a falha que previne é silenciosa, este item não pode ser dado como
  cumprido só porque compila.
- **Seleção de interface: decisão isolada, política por escolher.** A escolha
  passou a ser `LocalAddressResolver`, injektado e testável, com
  `AllNonLoopbackAddresses` como default. `startAdvertising` aceita
  `interfaceName`. As três opções concretas estão listadas em
  `features/discovery/FEATURE.md` §34; nenhuma foi escolhida.

Nota de risco: `mdns_dart` 2.2.2 tem 11 stars, 4 issues abertos e foi publicado
em 2025-06. É um port da implementação mDNS da HashiCorp em Go, o que é
favorável, mas a maturidade é baixa. Tratar como dependência de risco e
manter o `DiscoveryService` substituível.

## Consequências

- Nenhum código de Discovery deve ser escrito antes do spike.
- Se o spike falhar, activamos o fallback (responder próprio) e **registamos uma
  nova ADR** em vez de editar esta.
- A API do pacote nunca pode vazar para `domain/` ou `application/`.

## Nota de segurança

Independentemente do provider, os metadados descobertos são **input público
não-confiável** e não podem conter o token. Ver
`docs/decisions/0003-token-fora-do-mdns.md` e `docs/SECURITY.md` §11.1.