# 0007 — `file_picker` para a escolha de ficheiros

- **Estado:** Aceito
- **Data:** 2026-10-05
- **Decide:** qual pacote abre o diálogo nativo de escolha de ficheiros

## Contexto

O MVP envia ficheiros individuais e múltiplos (`AGENTS.md` §25), e
`features/file_transfer/FEATURE.md` §10 fixa o contrato de entrada como
«paths and sizes». `dart:io` não abre diálogos nativos, portanto algum pacote
de plataforma ou código nativo próprio é inevitável (`AGENTS.md` §42).

A escolha não podia ser feita pelo critério habitual — o pacote mais popular —
porque esta aplicação é exactamente o caso em que a implementação do picker no
Android decide se a app funciona ou não.

Foram inspecionados os fontes de `file_selector` 1.1.0 e de `file_picker`
13.1.0 (via `android_file_picker` 2.0.0), não apenas a documentação.

## Comportamento verificado no Android

| | `file_selector` (oficial Flutter) | `file_picker` |
|---|---|---|
| Como devolve o ficheiro | `XFile.fromData(file.bytes)` | copia para `cacheDir/file_picker/` em blocos de 8 KiB e devolve o path |
| Memória | **ficheiro inteiro em RAM** | plana |
| Caminho devolvido | nenhum (o path só existe em `XFile.fromData`) | path real |
| Limpeza | n/a | `clearTemporaryFiles()` |

`file_selector` em Android responde `FileResponse { path, size, bytes }` pelo
canal de método, onde `bytes` é obrigatório, e reconstrói um `XFile` **a partir
dos bytes**. Não há forma de pedir apenas o path. Para um vídeo de 2 GB isso
significa 2 GB em memória antes de a transferência começar.

Isto viola `AGENTS.md` §19, §21 e §79, e atinge o caso principal da aplicação.
Não é um risco teórico: é o utilizador a escolher um ficheiro grande.

## Opções consideradas

| Opção | Custo |
|---|---|
| `file_picker` | cópia para cache no Android (2× disco, sem percentagem); contrato de domínio preservado; `clearTemporaryFiles()` disponível |
| `file_selector` | ficheiro inteiro em RAM no Android; obriga a mudar o contrato de `TransferRequest` para URIs; **rejeitada** |
| SAF nativa via MethodChannel | streaming direto sem cópia nem RAM; exige código Kotlin e muda o contrato de domínio;rejeitada para o MVP |
| Canais nativos só para o diálogo | o mesmo custo da SAF sem o benefício do streaming |

## Decisão

Usar `file_picker`, isolado atrás de um contrato próprio,
`features/file_transfer/domain/file_selection_service.dart`, com a implementação
em `lib/features/file_transfer/data/platform_file_selection_service.dart`.

A razão não é a API, que é mais larga do que o necessário. É que o `file_picker`
devolve um **path real**, e isso mantém `features/file_transfer/FEATURE.md` §10
intacto: `SelectedFile` continua a ser path + tamanho, e o `dart:io` faz
streaming normal sem alterar o contrato de domínio.

O contrato abstracto é o que torna a decisão reversível. A implementação de
Android pode ser trocada por SAF nativa — com streaming directo de
`ContentResolver` — sem tocar em domain, application ou presentation
(`AGENTS.md` §22, §39). `file_selector` não permitiria essa troca sem mudar o
contrato.

## Consequências

- **O Android duplica o ficheiro em disco durante a selecção.** O original e a
  cópia de cache coexistem. Está registado em
  `features/file_transfer/FEATURE.md` §30.
- **Uma cópia que falhe descarta o ficheiro em silêncio.** O plugin devolve
  `null` e o ficheiro desaparece do resultado, sem erro. A API não fornece o
  número esperado de ficheiros, portanto a selecção parcial **não é
  detectável** a partir do Dart.
- **O tamanho pode ser desconhecido.** `PlatformFile.lengthSync()` devolve
  `int?`. Por isso `SelectedFile.sizeInBytes` é nulável e o total é `null`
  quando falta um tamanho: somar só os tamanhos conhecidos produziria um total
  plausível e errado, e o progresso construído sobre ele sobre-declararia o denominador
  (`features/file_transfer/FEATURE.md` §20).
- **`withData` nunca deve ser ligado.** Faria o plugin devolver o conteúdo como
  bytes, que é precisamente o problema que esta decisão evita.
- **Falta `com.apple.security.files.user-selected.read-only`** em
  `macos/Runner/DebugProfile.entitlements` e
  `macos/Runner/Release.entitlements`; sem ela o `NSOpenPanel` não consegue ler
  o que o utilizador escolhe. Adicionada nesta mudança.
- **Falta ainda `com.apple.security.network.client`**, necessária para a
  descoberta e para a transferência, em qualquer um dos ficheiros de
  entitlements. Não foi adicionada aqui porque não é necessária para a escolha
  de ficheiros e `features/file_transfer/FEATURE.md` §24 exige que os
  requisitos de plataforma sejam registados com a mudança que os introduz.

## Alternativas rejeitadas

- **`file_selector`**, apesar de ser o pacote oficial do Flutter e ter uma API
  mais pequena: carrega o ficheiro inteiro em memória no Android, o que
  contradiz o requisito central de uma aplicação de transferência de ficheiros.
- **SAF nativa desde já**: é a solução correcta para ficheiros grandes e deve
  ser o destino final para Android, mas exige código Kotlin e uma alteração ao
  contrato de domínio. Fica como melhoria, não como bloqueio do MVP.
