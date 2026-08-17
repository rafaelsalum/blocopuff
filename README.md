# BlocoPuff!

BlocoPuff! é um jogo multiplayer infantil, colorido e cartunesco para 2 a 10 jogadores. Os participantes permanecem sobre uma plataforma de blocos enquanto partes dela desaparecem; vence a rodada o último jogador restante.

## Stack

- Roblox Studio
- Luau em modo estrito (`--!strict`)
- Rojo 7 para sincronização entre os arquivos locais e o Roblox Studio
- Git para controle de versão
- [graphify](https://github.com/Graphify-Labs/graphify) para o grafo de conhecimento do código (agentes de IA)

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

## Grafo de conhecimento (graphify)

O projeto usa [graphify](https://github.com/Graphify-Labs/graphify) para manter um grafo de código em `graphify-out/` (nós, arestas de chamada/import, comunidades). Agentes de IA (Codex, Claude Code) consultam esse grafo — `graphify query`, `graphify path`, `graphify explain` — em vez de ler ou buscar em todos os arquivos, o que reduz bastante o consumo de tokens em tarefas de exploração. As instruções de uso ficam em [AGENTS.md](AGENTS.md) e [CLAUDE.md](CLAUDE.md).

A extração é 100% local (parsing AST via tree-sitter, com suporte a Luau), sem chamadas a LLM e sem custo:

```sh
graphify extract . --code-only   # gera/atualiza graphify-out/graph.json
graphify cluster-only . --no-label   # agrupa em comunidades e gera GRAPH_REPORT.md
```

Depois de alterar o código, atualize o grafo antes de commitar:

```sh
graphify update .
```

`graphify-out/graph.json`, `GRAPH_REPORT.md` e `manifest.json` são versionados — quem entra no projeto (humano ou agente) já começa com o grafo extraído, sem precisar rodar `graphify extract` antes de consultar. `graphify-out/cache/`, `graph.html` e os arquivos de análise/labels de comunidade (`.graphify_analysis.json`, `.graphify_labels.json*`) ficam fora do Git: são derivados de `graph.json`, mudam a cada rebuild automático do hook e regeneram em segundos, offline e sem custo com `graphify cluster-only .` (esse comando também recria `graph.html`, caso você queira abrir a visualização interativa).

A reconstrução automática a cada commit já está ativa via hooks locais do Git (`.git/hooks/post-commit` e `post-checkout`, instalados com `graphify hook install`; não versionados, cada clone precisa rodar o comando de novo). O merge do `graph.json` entre branches usa um driver de união configurado em [.gitattributes](.gitattributes) (`git config merge.graphify.*`, também local por clone).

Quem usa Claude Code também pode instalar o hook `PreToolUse` que sugere `graphify query` antes de leituras/buscas de arquivo:

```sh
graphify claude install
```

Esse comando grava `.claude/settings.json` com o caminho absoluto do executável `graphify` da própria máquina — por isso o arquivo é local (ver `.gitignore`) e precisa ser gerado por cada desenvolvedor, não compartilhado pelo Git.

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

Durante o teste, o servidor também cria `Workspace/BlocoPuffWorld` com o lobby, a arena e `Projectiles`, além de `ReplicatedStorage/BlocoPuffState` (estado da rodada por atributos) e `ReplicatedStorage/BlocoPuffRemotes`, com `RequestPuff` para solicitar disparos e `PuffFeedback` para confirmar acertos válidos ao atirador. O cliente lê exclusivamente os atributos replicados para desenhar o HUD; a cada mudança real de estado, o servidor registra `[BlocoPuff] Round state: <Estado>`. Encerre o teste pelo botão **Stop**; os objetos gerados em runtime desaparecem ao finalizar o Play.

## Build local

Para gerar uma cópia local da experiência no formato XML:

```sh
rojo build -o BlocoPuff.rbxlx
```

Arquivos `.rbxl` e `.rbxlx` são artefatos locais e não fazem parte da fonte principal deste repositório.

## Estado atual

O servidor gera em runtime uma primeira versão visual do mundo, com lobby, ponto de nascimento e uma arena suspensa de 225 blocos identificados. Um ciclo de partidas autoritativo (`WaitingForPlayers → Countdown → Active → Ending`) seleciona participantes, teleporta-os para posições distintas na arena e replica o estado para o cliente somente por atributos em `ReplicatedStorage/BlocoPuffState`. O cliente traduz esse estado em camadas independentes de preparação, combate, anúncios e espectador.

Quando há mais jogadores conectados do que o limite de participantes por rodada, a seleção usa uma **fila de rotação justa**: em vez de sempre escalar os primeiros jogadores conectados, quem acabou de jogar vai para o fim da fila, dando prioridade a quem ainda está esperando a vez. Jogadores que precisam esperar mais de uma rodada veem essa posição no HUD ("Você joga em N rodadas").

Após o primeiro teste em conjunto, alguns ajustes de jogabilidade: o painel do HUD ficou mais compacto e discreto durante `Active` (sem repetir a mesma mensagem de status já óbvia enquanto se joga), a contagem regressiva não mostra mais o número duas vezes na tela, e o Puffador ganhou uma mira (retículo) simples enquanto está equipado, já que sem ela não havia nenhuma referência visual de para onde o tiro ia.

Na primeira fase de polimento do combate, o Puffador passou a usar uma câmera sobre o ombro com comportamento de shift-lock e mira central em computador, toque e gamepad. O botão de disparo dedicado (`FireButtonView`) aparece em dispositivos de toque, mostra texto e progresso de recarga, enquanto o retículo possui alto contraste, animação de disparo e confirmação de acerto enviada pelo servidor. O Puffador continua **equipado automaticamente** assim que é concedido a cada participante (via `Humanoid:EquipTool`), sem exigir interação com o inventário.

Na segunda fase, a interface foi reconstruída sobre um tema visual central (`UiTheme`) e componentes responsivos. Espera e contagem regressiva usam uma apresentação própria; o aviso `PREPARE-SE` fica em um cartão compacto no canto superior direito para preservar a visão da arena. Durante `Active`, cronômetro, quantidade de jogadores e integridade da arena ocupam regiões compactas separadas. Início, eliminação e resultado aparecem em banners animados que não reiniciam a cada atualização do cronômetro. Todos os `ScreenGui` importantes respeitam `CoreUISafeInsets`, painéis usam `UIScale` por viewport e o modo compacto reorganiza o cronômetro em celulares estreitos para impedir sobreposição. O botão de toque exibe `ATIRAR` com texto responsivo e, enquanto o Puffador está equipado, a barra padrão da mochila é ocultada para não competir com os controles do combate; seu estado anterior é restaurado ao desequipar ou renascer. O espectador segue o mesmo tema, possui botões de 54 pixels e navegação por teclado, toque e gamepad.

Na terceira fase, o mundo recebeu direção de arte pastel inteiramente nativa: atmosfera, bloom, correção de cor e nuvens sem colisão são gerenciados pelo `WorldVisualService`, sem assets ou dependências externas. A arena ganhou uma moldura energética também sem colisão, que aumenta de intensidade somente durante `Active`. Ao destruir um bloco, o buraco autoritativo continua abrindo imediatamente, enquanto uma cópia estritamente visual encolhe e cai por uma fração de segundo; no reset, os blocos reaparecem com uma transição curta. A mira identifica um bloco válido com mudança de geometria, contraste e o rótulo `BLOCO`, sem depender apenas de cor. Essa prévia usa somente a tag e o atributo replicados em `ArenaConstants`: não concede ao cliente autoridade sobre impacto ou destruição e não adiciona novos eventos remotos.

Após a validação visual da terceira fase, a paleta do mundo foi amortecida, o bloom foi reduzido e a correção de cor passou a diminuir brilho e saturação. As nuvens formam uma camada baixa ao redor das plataformas, ajudando a compor o horizonte sem encobrir a arena. O lobby recebeu fundação em camadas, pilares e paredes físicas invisíveis de 18 studs acima da plataforma: a cerca baixa continua sendo o limite visual, mas um salto normal não permite mais sair da área de espera.

Cada participante recebe, ao entrar em `Active`, o **Puffador**: uma ferramenta cartunesca construída inteiramente com instâncias nativas (sem assets externos), já equipada na mão. O jogador mira e dispara com mouse, toque, gamepad ou o botão dedicado — todos convergem para a mesma função no cliente, que calcula o ponto visado no mundo e o envia pelo `RemoteEvent RequestPuff`. O servidor recalcula a direção entre o cano validado e esse ponto, eliminando a paralaxe da câmera sem confiar no cliente para origem, alcance, cadência ou impacto. O projétil usa material neon, trilha, brilho e efeito de impacto; recuo, clarão, som e recarga são feedbacks locais imediatos.

Quando um projétil atinge diretamente um bloco válido e ativo da arena (tag `ArenaBlock`), o `ArenaService` o remove **temporariamente**: fica invisível, sem colisão e sem ser atingível por novos raycasts, permitindo que personagens caiam pelo espaço aberto. O bloco não é destruído de fato — todos os 225 são restaurados integralmente (posição, tamanho, cor, atributos e tags) antes de cada nova rodada. O Puffador continua **sem causar dano direto**: a queda usa apenas a física normal, sem impulso, sem eliminação atribuída ao disparo. As contagens `TotalBlockCount`, `RemainingBlockCount` e `DestroyedBlockCount` são replicadas em `BlocoPuffState`; durante `Active`, o HUD as apresenta como percentual de integridade, barra visual e contagem exata secundária.

Abaixo da arena existe uma **zona de eliminação** autoritativa: o servidor monitora, a cada 0,1s, a posição vertical dos participantes ativos e os elimina assim que cruzam um limite calculado a partir da própria posição da arena (não é um valor fixo do mundo, nem depende exclusivamente de `Workspace.FallenPartsDestroyHeight`, que continua existindo apenas como rede de segurança global). A eliminação registra a causa (`FellFromArena`, `CharacterDied` para outras mortes durante `Active`, ou `PlayerLeft` ao sair), revoga o Puffador, limpa os projéteis do jogador e permite o respawn normal no lobby — sem impulso, sem teleporte especial e sem crédito de eliminação atribuído a outro jogador.

Ainda não há dano direto, resistência de blocos, regeneração durante a rodada, persistência ou monetização.

Para testar a zona de eliminação manualmente: entre em `Active` com 2+ jogadores, destrua o bloco sob um participante e confirme que ele cai e é eliminado com a mensagem "Você caiu da arena" no HUD, sem perda de vida instantânea no momento do disparo. Os atributos `IsEliminated`, `EliminationReason` e `EliminatedAtRoundId` no `Player` refletem a causa e a rodada.

Um jogador eliminado durante `Active`/`Ending` tem sua câmera automaticamente redirecionada para acompanhar um participante ainda ativo, em vez de ficar parada no próprio personagem já eliminado no lobby. É um comportamento puramente do cliente (`SpectatorController`, lendo apenas atributos já replicados de `Player`), sem impacto em nenhum estado autoritativo. O alvo observado pode ser alternado manualmente entre os participantes ainda ativos — setas do teclado, D-Pad do gamepad, ou os botões `<`/`>` que aparecem na tela durante o modo espectador, que também mostra quantos participantes ainda seguem ativos.
