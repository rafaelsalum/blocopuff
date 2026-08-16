# BlocoPuff!

BlocoPuff! é um jogo multiplayer infantil, colorido e cartunesco para 2 a 10 jogadores. Os participantes permanecem sobre uma plataforma de blocos enquanto partes dela desaparecem; vence a rodada o último jogador restante.

## Stack

- Roblox Studio
- Luau em modo estrito (`--!strict`)
- Rojo 7 para sincronização entre os arquivos locais e o Roblox Studio
- Git para controle de versão

## Estrutura

```text
src/
├── client/
│   ├── controllers/  # Lê o estado replicado e trata entrada do jogador
│   └── ui/            # Constrói e atualiza a interface (HUD)
├── server/   # Scripts e serviços autoritativos do servidor
└── shared/   # Configurações, tipos e módulos compartilhados
tests/        # Testes futuros
```

O arquivo `default.project.json` mapeia essas pastas para `StarterPlayerScripts/Client`, `ServerScriptService/Server` e `ReplicatedStorage/Shared`, respectivamente.

## Pré-requisitos

- Git
- Roblox Studio para macOS
- Rokit 1.2.0 ou mais recente
- Rojo CLI 7.7.0, fixado pelo projeto
- Plugin do Rojo para Roblox Studio compatível com a versão principal da CLI

## Toolchain local

O projeto usa [Rokit](https://github.com/rojo-rbx/rokit) para instalar ferramentas Roblox de forma reproduzível. A versão do Rojo fica fixada no arquivo `rokit.toml`; não é necessário instalar Rojo globalmente por outro método.

### Instalação inicial no macOS

Instale o Rokit com o instalador oficial:

```sh
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```

### Configuração do PATH por shell

Para Bash ou Zsh, reinicie o terminal para carregar o PATH. Se necessário na sessão atual, carregue o ambiente POSIX do Rokit:

```sh
source "$HOME/.rokit/env"
```

O arquivo `~/.rokit/env` não deve ser carregado no Fish, pois usa sintaxe POSIX. Para Fish, crie uma configuração nativa e idempotente em `~/.config/fish/conf.d/rokit.fish`:

```fish
fish_add_path --path "$HOME/.rokit/bin"
```

Depois de abrir um novo Fish, acesse a raiz do projeto e execute normalmente:

```fish
rojo serve
```

Na raiz deste repositório, confie no pacote oficial e instale a versão fixada:

```sh
rokit trust rojo-rbx/rojo
rokit install
```

Confirme a instalação:

```sh
rokit --version
rojo --version
```

A versão esperada atualmente é `Rojo 7.7.0`.

### Atualização futura

Verifique primeiro se há uma atualização disponível:

```sh
rokit update --check
```

Para atualizar somente o Rojo e registrar a nova versão em `rokit.toml`:

```sh
rokit update rojo
```

Revise a alteração do manifesto e repita o build de validação antes de compartilhar a atualização.

## Sincronização com o Roblox Studio

Na raiz do projeto, inicie o servidor de sincronização:

```sh
rojo serve
```

Abra uma experiência no Roblox Studio, selecione o plugin Rojo na barra de plugins e clique em **Connect**. Use o endereço exibido pelo comando; por padrão, o servidor local usa `localhost:34872`.

## Plugin do Rojo no Roblox Studio

Instale o [plugin oficial Rojo 7 no Creator Store](https://create.roblox.com/store/asset/13916111004). Na página, clique em **Install** e confirme que o plugin aparece na aba **Plugins** do Roblox Studio. A versão principal do plugin deve ser a mesma da CLI.

Para fazer a primeira sincronização:

1. Abra o Roblox Studio e crie ou abra um place local de desenvolvimento.
2. Na raiz deste repositório, execute `rojo serve` e mantenha o terminal aberto.
3. No Studio, abra o painel do Rojo pela aba **Plugins**.
4. Use o endereço mostrado no terminal, normalmente `localhost:34872`, e clique em **Connect**.
5. Revise e aceite a sincronização apresentada pelo plugin.

Depois da sincronização, o Explorer deve conter:

```text
ReplicatedStorage/Shared
ServerScriptService/Server
StarterPlayer/StarterPlayerScripts/Client
```

Para um teste simples, abra **View > Output** e clique em **Play**. Sem erros, devem aparecer estas mensagens:

```text
[BlocoPuff] Server initialized
[BlocoPuff] Lobby created
[BlocoPuff] Replicated state initialized
[BlocoPuff] Arena created with 225 blocks
[BlocoPuff] Puffador system started
[BlocoPuff] Elimination zone armed
[BlocoPuff] Round cycle started
[BlocoPuff] Client initialized
```

Durante o teste, o servidor também cria `Workspace/BlocoPuffWorld` com o lobby, a arena e `Projectiles`, além de `ReplicatedStorage/BlocoPuffState` (estado da rodada por atributos) e `ReplicatedStorage/BlocoPuffRemotes/RequestPuff` (disparo do Puffador). O cliente lê exclusivamente os atributos replicados para desenhar o HUD; a cada mudança real de estado, o servidor registra `[BlocoPuff] Round state: <Estado>`. Encerre o teste pelo botão **Stop**; os objetos gerados em runtime desaparecem ao finalizar o Play.

## Build local

Para gerar uma cópia local da experiência no formato XML:

```sh
rojo build -o BlocoPuff.rbxlx
```

Arquivos `.rbxl` e `.rbxlx` são artefatos locais e não fazem parte da fonte principal deste repositório.

## Estado atual

O servidor gera em runtime uma primeira versão visual do mundo, com lobby, ponto de nascimento e uma arena suspensa de 225 blocos identificados. Um ciclo de partidas autoritativo (`WaitingForPlayers → Countdown → Active → Ending`) seleciona participantes, teleporta-os para posições distintas na arena e replica o estado para o cliente somente por atributos em `ReplicatedStorage/BlocoPuffState`. O cliente exibe esse estado em um HUD simples (mensagem, cronômetro, participantes e vencedor).

Cada participante recebe, ao entrar em `Active`, o **Puffador**: uma ferramenta cartunesca construída inteiramente com instâncias nativas (sem assets externos). O jogador mira e dispara com mouse, toque ou gamepad — o `Tool.Activated` padrão do Roblox já unifica os três; o cliente só calcula a direção de mira e envia um único `Vector3` normalizado pelo `RemoteEvent RequestPuff`. O servidor é a única autoridade: valida participação, elegibilidade, cadência e origem antes de simular o projétil por raycast determinístico.

Quando um projétil atinge diretamente um bloco válido e ativo da arena (tag `ArenaBlock`), o `ArenaService` o remove **temporariamente**: fica invisível, sem colisão e sem ser atingível por novos raycasts, permitindo que personagens caiam pelo espaço aberto. O bloco não é destruído de fato — todos os 225 são restaurados integralmente (posição, tamanho, cor, atributos e tags) antes de cada nova rodada. O Puffador continua **sem causar dano direto**: a queda usa apenas a física normal, sem impulso, sem eliminação atribuída ao disparo. As contagens `TotalBlockCount`, `RemainingBlockCount` e `DestroyedBlockCount` são replicadas em `BlocoPuffState` e exibidas no HUD como `Blocos: 217/225` durante `Active`/`Ending`.

Abaixo da arena existe uma **zona de eliminação** autoritativa: o servidor monitora, a cada 0,1s, a posição vertical dos participantes ativos e os elimina assim que cruzam um limite calculado a partir da própria posição da arena (não é um valor fixo do mundo, nem depende exclusivamente de `Workspace.FallenPartsDestroyHeight`, que continua existindo apenas como rede de segurança global). A eliminação registra a causa (`FellFromArena`, `CharacterDied` para outras mortes durante `Active`, ou `PlayerLeft` ao sair), revoga o Puffador, limpa os projéteis do jogador e permite o respawn normal no lobby — sem impulso, sem teleporte especial e sem crédito de eliminação atribuído a outro jogador.

Ainda não há dano direto, resistência de blocos, regeneração durante a rodada, persistência ou monetização.

Para testar a zona de eliminação manualmente: entre em `Active` com 2+ jogadores, destrua o bloco sob um participante e confirme que ele cai e é eliminado com a mensagem "Você caiu da arena" no HUD, sem perda de vida instantânea no momento do disparo. Os atributos `IsEliminated`, `EliminationReason` e `EliminatedAtRoundId` no `Player` refletem a causa e a rodada.

Um jogador eliminado durante `Active`/`Ending` tem sua câmera automaticamente redirecionada para acompanhar um participante ainda ativo, em vez de ficar parada no próprio personagem já eliminado no lobby. É um comportamento puramente do cliente (`SpectatorController`, lendo apenas atributos já replicados de `Player`), sem impacto em nenhum estado autoritativo. O alvo observado pode ser alternado manualmente entre os participantes ainda ativos — setas do teclado, D-Pad do gamepad, ou os botões `<`/`>` que aparecem na tela durante o modo espectador.
