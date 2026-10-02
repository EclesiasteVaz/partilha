# 0003 — O token nunca sai em metadados de descoberta

- **Estado:** Aceito
- **Data:** 2026-10-02
- **Decide:** contrato de metadados de descoberta e transmissão de credenciais
- **Affects:** `docs/PROTOCOL.md` §7, `docs/SECURITY.md` §11

## Contexto

O `docs/PROTOCOL.md` e o `README.md` listavam o `token` como parte dos
metadados de descoberta mDNS, na mesma lista que `deviceId`, `deviceName`,
`host` e `port`.

Isto é um problema de segurança real, não uma questão de estilo.

**Registos mDNS são texto claro e são lidos por qualquer dispositivo na LAN.**

Consequências de anunciar o token:

1. O token é transmitido em claro em cada announcement/query.
2. Qualquer host na mesma rede — incluindo machines de outra pessoa, um guest
   Wi-Fi, um portable comprometido — pode recolher o token.
3. Com o token, um atacante passa a poder **impersonar o dispositivo**: a
   validação por token (o mecanismo de pairing do MVP) deixa de significar
   nada.
4. Isto contradiz directamente o modelo aprovado em `docs/SECURITY.md`:
   §2.1 (minimizar exposição), §2.6 (não expor tokens desnecessariamente),
   §2.9 (visibilidade local não é autenticação), §11 (mDNS não autentica) e
   §34 (minimização de dados).

Um QR code é diferente: é um canal **out-of-band** e **deliberado**. A
utilização de câmara implica uma acção física e consciente do utilizador.
Anunciar o token é o oposto disso — édifundir o segredo sem pedir nada ao
utilizador.

## Decisão

O token **nunca** é transmitido em metadados de descoberta.

Metadados de descoberta aprovados:

```text
deviceId
deviceName
host/address
port
capabilities
```

O token viaja **apenas pelo QR code**:

```text
Discovery  →  NÃO transporta token
QR pairing  →  transporta token
```

Consequência de arquitectura: como a descoberta já não transporta a
credencial, o handshake inicial da conexão **não pode** assumir o token como
pré-condição vinda do discovery. Ou o token chega pelo QR, ou chega numa
mensagem de handshake dedicada — o que é uma decisão de protocolo separada e
ainda `OPEN`.

## Alternativas rejeitadas

| Alternativa | Porquê não |
|---|---|
| Manter o token no mDNS | Qualquer vizinho recolhe a credencial e impersona o dispositivo |
| Token cifrado/derivado no mDNS | Criptografia nova, não revista, sem modelo de atacante definido. Seria arquitectura criptográfica nova e precisa de `docs/SECURITY.md` revisto |
| Token com expiração curta | Continua a ser recuperável enquanto válido; e rotação não está no MVP (§35) |
| Handshake que derive o token do `deviceId` | `deviceId` também é público; não cria nenhum segredo |

## Consequências

**Positivas**

- Desaparece o vector defurto de credenciais mais óbvio do MVP.
- `docs/PROTOCOL.md` e `docs/SECURITY.md` passam a estar coerentes entre si.

**Negativas / trabalho novo**

- O handshake tem de carregar o token explicitamente, o que ainda não está
  definido (`docs/PROTOCOL.md` §9 é `OPEN — APPROVAL REQUIRED`).
- A UX de pairing tem de tornar explícito ao utilizador que o QR é o momento em
  que a confiança é estabelecida.

## Implementação obrigatória

```text
[ ] Nenhum TXT record / campo de discovery contém o token
[ ] Nenhum log imprime o token
[ ] deviceId NÃO é tratado como prova de identidade
[ ] Metadados de discovery são validados (tipo, comprimento) antes de uso
[ ] deviceName é tratado como display-only e escapado na renderização
[ ] Metadados nunca influenciam directamente caminhos de ficheiros
[ ] O token é escrito apenas em secure credential storage
```

## Referências

- `docs/PROTOCOL.md` §7.2 (metadados), §7.3 (input não-confiável), §8 (QR)
- `docs/SECURITY.md` §11.1, §3 (âmbito do MVP)
- `docs/ARCHITECTURE.md` §36 (direcção da descoberta)