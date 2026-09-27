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
[BlocoPuff] Replicated state initialized
[BlocoPuff] World visuals created
[BlocoPuff] Building created
[BlocoPuff] Lobby created
[BlocoPuff] Arena created with 450 blocks
[BlocoPuff] Puffador system started
[BlocoPuff] Elimination zone armed
[BlocoPuff] Round cycle started
[BlocoPuff] Client initialized
```

Durante o teste, o servidor também cria `Workspace/BlocoPuffWorld` com o prédio (`Building`), o lobby, a arena e `Projectiles`, além de `ReplicatedStorage/BlocoPuffState` (estado da rodada por atributos) e `ReplicatedStorage/BlocoPuffRemotes`, com `RequestPuff` para solicitar disparos e `PuffFeedback` para confirmar acertos válidos ao atirador. O cliente lê exclusivamente os atributos replicados para desenhar o HUD; a cada mudança real de estado, o servidor registra `[BlocoPuff] Round state: <Estado>`. Encerre o teste pelo botão **Stop**; os objetos gerados em runtime desaparecem ao finalizar o Play.

## Build local

Para gerar uma cópia local da experiência no formato XML:

```sh
rojo build -o BlocoPuff.rbxlx
```

Arquivos `.rbxl` e `.rbxlx` são artefatos locais e não fazem parte da fonte principal deste repositório.

## Estado atual

### Painel administrativo seguro

O projeto possui um painel administrativo próprio, inspirado no fluxo do AdminPanel+, mas implementado integralmente nos arquivos do Rojo. O pacote original da Toolbox não é executado nem incluído no jogo. O acesso inicial pertence somente ao User ID `4328593410`, configurado em `src/server/config/AdminConfig.luau`; qualquer administrador adicional deve ser incluído explicitamente nesse arquivo.

O botão `PAINEL ADMIN` aparece apenas depois que o servidor confirma a autorização. Pelo painel é possível enviar avisos filtrados, expulsar jogadores do servidor atual e aplicar ou remover banimentos persistentes por User ID. Todas as solicitações passam por autenticação e validação no servidor, possuem limite de frequência e impedem ações contra contas administrativas protegidas. Avisos e banimentos são sincronizados entre servidores com `MessagingService`; os bans usam o DataStore `BlocoPuffAdminBansV1`.

Para testar persistência e sincronização no Studio, a experiência precisa estar publicada e com **Enable Studio Access to API Services** habilitado. Sem esse acesso, o restante do jogo continua funcionando e o painel informa quando uma operação persistente ou global não está disponível. O atalho `F2` abre ou fecha o painel no computador; em toque e gamepad, use o botão visível e os controles selecionáveis da interface.

O servidor gera em runtime uma primeira versão visual do mundo, com um prédio fechado e uma arena de dois pisos (450 blocos identificados). Um ciclo de partidas autoritativo (`WaitingForPlayers → Countdown → Active → Ending`) seleciona participantes, teleporta-os para posições distintas na arena e replica o estado para o cliente somente por atributos em `ReplicatedStorage/BlocoPuffState`. O cliente traduz esse estado em camadas independentes de preparação, combate, anúncios e espectador.

Quando há mais jogadores conectados do que o limite de participantes por rodada, a seleção usa uma **fila de rotação justa**: em vez de sempre escalar os primeiros jogadores conectados, quem acabou de jogar vai para o fim da fila, dando prioridade a quem ainda está esperando a vez. Jogadores que precisam esperar mais de uma rodada veem essa posição no HUD ("Você joga em N rodadas").

Após o primeiro teste em conjunto, alguns ajustes de jogabilidade: o painel do HUD ficou mais compacto e discreto durante `Active` (sem repetir a mesma mensagem de status já óbvia enquanto se joga), a contagem regressiva não mostra mais o número duas vezes na tela, e o Puffador ganhou uma mira (retículo) simples enquanto está equipado, já que sem ela não havia nenhuma referência visual de para onde o tiro ia.

Na primeira fase de polimento do combate, o Puffador passou a usar uma câmera sobre o ombro com comportamento de shift-lock e mira central em computador, toque e gamepad. O botão de disparo dedicado (`FireButtonView`) aparece em dispositivos de toque, mostra texto e progresso de recarga, enquanto o retículo possui alto contraste, animação de disparo e confirmação de acerto enviada pelo servidor. O Puffador continua **equipado automaticamente** assim que é concedido a cada participante (via `Humanoid:EquipTool`), sem exigir interação com o inventário.

Na segunda fase, a interface foi reconstruída sobre um tema visual central (`UiTheme`) e componentes responsivos. Espera e contagem regressiva usam uma apresentação própria; o aviso `PREPARE-SE` fica em um cartão compacto no canto superior direito para preservar a visão da arena. Durante `Active`, cronômetro, quantidade de jogadores e integridade da arena ocupam regiões compactas separadas. Início, eliminação e resultado aparecem em banners animados que não reiniciam a cada atualização do cronômetro. Todos os `ScreenGui` importantes respeitam `CoreUISafeInsets`, painéis usam `UIScale` por viewport e o modo compacto reorganiza o cronômetro em celulares estreitos para impedir sobreposição. O botão de toque exibe `ATIRAR` com texto responsivo e, enquanto o Puffador está equipado, a barra padrão da mochila é ocultada para não competir com os controles do combate; seu estado anterior é restaurado ao desequipar ou renascer. O espectador segue o mesmo tema, possui botões de 54 pixels e navegação por teclado, toque e gamepad.

Na terceira fase, o mundo recebeu direção de arte pastel inteiramente nativa: atmosfera, bloom, correção de cor e nuvens sem colisão são gerenciados pelo `WorldVisualService`, sem assets ou dependências externas. A arena ganhou uma moldura energética também sem colisão, que aumenta de intensidade somente durante `Active`. Ao destruir um bloco, o buraco autoritativo continua abrindo imediatamente, enquanto o cliente (`BlockCollapseController`, reagindo ao atributo `IsDestroyed`) quebra uma cópia visual em pedaços que caem girando com uma nuvem de poeira — rodar no cliente deixa a animação fluida; no reset, os blocos reaparecem com uma transição curta. A mira identifica um bloco válido com mudança de geometria, contraste e o rótulo `BLOCO`, sem depender apenas de cor. Essa prévia usa somente a tag e o atributo replicados em `ArenaConstants`: não concede ao cliente autoridade sobre impacto ou destruição e não adiciona novos eventos remotos.

Após a validação visual da terceira fase, a paleta do mundo foi amortecida, o bloom foi reduzido e a correção de cor passou a diminuir brilho e saturação. As nuvens formam uma camada baixa ao redor das plataformas, ajudando a compor o horizonte sem encobrir a arena. O lobby recebeu fundação em camadas, pilares e paredes físicas invisíveis de 18 studs acima da plataforma: a cerca baixa continua sendo o limite visual, mas um salto normal não permite mais sair da área de espera.

Na quarta fase, cada participante passou a ter uma pontuação pessoal de blocos destruídos na rodada. O atributo `RoundBlocksDestroyed` é zerado na seleção e incrementado apenas pelo servidor depois que `ArenaService.tryDestroyBlock` confirma um impacto válido; o cliente somente o apresenta em um painel compacto e nos resumos de eliminação e encerramento. A primeira vez que o Puffador é equipado em uma sessão, uma dica temporária informa o controle adequado para mouse, toque ou gamepad e desaparece no primeiro disparo ou após sete segundos. O texto não bloqueia ações, respeita a área segura da tela e não depende apenas de ícones.

Cada participante recebe, ao entrar em `Active`, o **Puffador**: uma ferramenta cartunesca construída inteiramente com instâncias nativas (sem assets externos), já equipada na mão. O jogador mira e dispara com mouse, toque, gamepad ou o botão dedicado — todos convergem para a mesma função no cliente, que calcula o ponto visado no mundo e o envia pelo `RemoteEvent RequestPuff`. Como em jogos de tiro em terceira pessoa, o acerto segue o raio da câmera: o cliente envia também a origem desse raio, que o servidor só aceita perto da cabeça e com linha livre até ela (caso contrário usa o cano). O projétil visível sai do cano e converge para o raio da mira em poucos studs, então o tiro acerta exatamente o que está sob o retículo, sem confiar no cliente para alcance, cadência ou impacto. Durante o combate o zoom da câmera fica fixo e o deslocamento de ombro encolhe perto de paredes, impedindo que a câmera atravesse o prédio. O projétil usa material neon, trilha, brilho e efeito de impacto; recuo, clarão, som e recarga são feedbacks locais imediatos.

Quando um projétil atinge diretamente um bloco válido e ativo da arena (tag `ArenaBlock`), o `ArenaService` o remove **temporariamente**: fica invisível, sem colisão e sem ser atingível por novos raycasts, permitindo que personagens caiam pelo espaço aberto. O bloco não é destruído de fato — todos os 450 são restaurados integralmente (posição, tamanho, cor, atributos e tags) antes de cada nova rodada. O Puffador continua **sem causar dano direto**: a queda usa apenas a física normal, sem impulso, sem eliminação atribuída ao disparo. As contagens `TotalBlockCount`, `RemainingBlockCount` e `DestroyedBlockCount` são replicadas em `BlocoPuffState`; durante `Active`, o HUD as apresenta como percentual de integridade, barra visual e contagem exata secundária.

Abaixo da arena existe uma **zona de eliminação** autoritativa: o servidor monitora, a cada 0,1s, a posição vertical dos participantes ativos e os elimina assim que cruzam um limite calculado a partir da própria posição da arena (não é um valor fixo do mundo, nem depende exclusivamente de `Workspace.FallenPartsDestroyHeight`, que continua existindo apenas como rede de segurança global). A eliminação registra a causa (`FellFromArena`, `CharacterDied` para outras mortes durante `Active`, ou `PlayerLeft` ao sair), revoga o Puffador, limpa os projéteis do jogador e permite o respawn normal no lobby — sem impulso, sem teleporte especial e sem crédito de eliminação atribuído a outro jogador.

### Prédio fechado com dois pisos

A ilha flutuante e o skybox foram removidos: a partida acontece dentro de um prédio fechado (`BuildingService`), com paredes, teto e poço em cores sólidas, frisos e faixas de luz por andar e iluminação de interior (`WorldVisualService`). A geometria é centralizada em `src/shared/modules/BuildingLayout.luau` e configurada em `GameConfig.Arena` (`FloorCount`, `FloorSpacing`) e `GameConfig.Building`.

O lobby é a galeria envidraçada dentro do próprio prédio, com carpete, sofás e lustres: todos nascem e aguardam ali, vendo a arena. Como o lobby tem um único `SpawnLocation`, o servidor move cada personagem, logo ao nascer (e ao voltar da partida), para a posição livre da galeria mais distante dos demais, evitando jogadores empilhados. Ao iniciar a partida, os participantes descem para o piso de cima em posições sorteadas e o mais afastadas possível umas das outras (amostragem do ponto mais distante em `BuildingLayout.getSpreadSpawnCFrames`). A arena tem dois pisos de blocos: quem está em cima atira no próprio chão ou, pelos buracos, no piso de baixo; quem está embaixo atira para cima e derruba o piso de quem está acima. Cair do piso de cima apenas leva ao andar inferior; somente cair abaixo do piso mais baixo elimina, até restar um competidor. Eliminados renascem no lobby e, ao final, os participantes restantes voltam para ele antes de os pisos serem restaurados.

O interior segue o estilo de mansão de jogos como Murder Mystery, usando somente materiais nativos: porão de tijolos no poço, papel de parede, lambri, rodapés, sancas, portas, quadros e janelas noturnas por andar (`BuildingDecor`), teto com vigas, lustres e arandelas com luz quente. O piso de cima é de taco de madeira e o de baixo de pedra fosca, sem reflexo, o que facilita enxergar os buracos. A iluminação usa `Lighting.Technology = Future` (em `default.project.json`) com base uniforme de luz ambiente; lustres e arandelas são acentos fracos e o andar de baixo recebe uma única luz de teto difusa.

### Regras do core (Fase 1, entrega 1.1)

Direção de produto em `docs/GAME_DESIGN.md`; escopo da fase em `docs/FASE_1_CORE_GAMEPLAY_UX.md`.

- Até 12 jogadores por rodada; rodada de 3:30 (60 s no Studio).
- **Empurrão:** acertar outro jogador com o Puffador o empurra (`KnockbackService`, `GameConfig.Knockback`). O servidor valida e calcula; o cliente dono do personagem aplica a velocidade (`KnockbackController`). Não há dano: elimina-se caindo.
- **Derrubadas:** quem empurrou alguém nos últimos 6 s recebe o crédito se ele cair (atributo `RoundKnockouts`).
- **Segunda Chance:** a primeira queda para fora da arena devolve o jogador a um bloco inteiro do andar de baixo, com 2,5 s de imunidade a empurrões; a segunda queda elimina. A HUD mostra "2 VIDAS" / "ÚLTIMA VIDA".
- **Caos Final:** nos últimos 30 s a Segunda Chance é desligada e, a cada 2 s, blocos aleatórios piscam em vermelho por 1,2 s e caem (3 no início, até 9 no fim). O cronômetro fica vermelho (`FinalChaosService`, `GameConfig.FinalChaos`).

### Telemetria (Fase 1, entrega 1.4)

`TelemetryService` envia eventos customizados pelo `AnalyticsService` do Roblox; eles aparecem no Creator Dashboard, em Analytics › Custom Events. No Studio cada evento também é impresso no Output (`GameConfig.Telemetry`). Os contadores de combate são somados no servidor e enviados uma vez no fim da rodada. Todos os eventos são por jogador, e os campos customizados seguem a mesma ordem: **Field01 = dispositivo** (Mobile, Desktop, Gamepad, informado pelo `TelemetryController`), **Field02 = contexto**, **Field03 = detalhe**.

| Evento | Valor | Field02 / Field03 |
| --- | --- | --- |
| `RoundStarted` | jogadores na rodada | — |
| `Rematch` | 1 (jogou a rodada anterior e seguiu) | — |
| `FloorDrop` | segundos de rodada | zona / `F2>F1` |
| `Fell` | segundos de rodada | zona / `SecondChance` ou `Eliminated` |
| `SecondChanceUsed` | segundos de rodada | — |
| `Eliminated` | posição final | motivo / segundos |
| `FinalChaosStarted` | jogadores vivos | — |
| `LeftMidRound` | segundos de rodada | — |
| `RoundFinished` | duração em segundos | `Win`, `Draw` ou `Loss` |
| `RoundWon` | duração em segundos | — |
| `RoundShots`, `RoundPlayerHits`, `RoundBlockHits`, `RoundBlocksDestroyed` | total na rodada | — |

As zonas dividem a arena em `Center`, `NorthWest`, `NorthEast`, `SouthWest` e `SouthEast`.

### Pós-partida (Fase 1, entrega 1.3)

Ao fim de cada rodada o servidor monta o resultado (`RoundResultBuilder`) e o envia a todos pelo RemoteEvent `RoundResult`. O cliente mostra o painel `ResultsView` (`ResultsController`):

- **Título:** "VITÓRIA!" para quem venceu, "FIM DA RODADA" com o nome do vencedor, ou "EMPATE!" quando o tempo acaba com mais de um jogador vivo.
- **Sua posição:** #1 é o vencedor; quem é eliminado fica com (jogadores ainda vivos + 1). Em empate, todos os sobreviventes ficam em #1. Quedas no mesmo instante dividem a posição; se todos caem antes do fim, vence quem caiu por último (ou é empate, se caíram juntos).
- **Seus números:** blocos destruídos e derrubadas.
- **Destaques:** "MAIS BLOCOS" e "MAIS DERRUBADAS", quando alguém pontuou.
- **Classificação:** as 5 primeiras posições, com sua linha destacada. O desempate usa derrubadas e depois blocos.
- **Próxima rodada:** o rodapé mostra "Voltando ao lobby em N s", depois "Próxima rodada em N s", e se você joga a próxima ou em quantas rodadas entra. O painel fecha no botão OK, faltando 3 s para a próxima rodada ou quando ela começa.
- O encerramento passou para 12 s, para dar tempo de ler. Nada disso é salvo entre sessões nesta fase.

### Notificações (Fase 1, entrega 1.2)

Todo alerta de tela passa pelo `NotificationManager` (`src/client/notifications/`). Existem dois canais, em regiões diferentes da tela, e cada um mostra um alerta por vez, então nada se sobrepõe:

| Canal | Onde | O que mostra |
| --- | --- | --- |
| `Center` | anúncio grande no meio | rodada, eliminação, Segunda Chance, Caos Final, resultado |
| `Banner` | faixa no topo (mais baixa em telas estreitas) | cofre, avisos de administrador |

Regras de cada canal:

- **Prioridade:** `Critical` > `High` > `Normal` > `Low`. Um alerta mais importante interrompe o atual; o interrompido volta para a fila se for `High`/`Critical` e ainda tiver mais de 1 s, senão é descartado.
- **Fila:** até 4 alertas, por prioridade e ordem de chegada. Com a fila cheia, sai o menos importante.
- **Validade:** quem espera demais é descartado (Low 2 s, Normal 3 s, High 6 s, Critical 8 s), para não mostrar notícia velha.
- **Substituição:** a mesma `key` atualiza o alerta na tela ou substitui o que está na fila.
- **Categoria:** `clear(canal, categoria)` limpa só um tipo de alerta.

| Alerta | Canal | Prioridade |
| --- | --- | --- |
| Eliminado, Caos Final, vencedor | Center | Critical |
| Segunda Chance, fim sem vencedor | Center | High |
| "VALENDO!" | Center | Normal |
| Aguarde sua vez | Center | Low |
| Cofre invadido | Banner | Critical |
| Aviso de administrador, cofre destrancou, Super pego | Banner | High |

Os pop-ups de combate perto da mira ("+1", combo e marcos) seguem na `FeedbackView`, no canto direito, porque são reforços curtos que não competem com os alertas.

### O Cofre do Barão Puff

> **Desligado na Fase 1** (`GameConfig.SecretRoom.Enabled = false`): as portas ficam fechadas e sem interação. O cofre será refeito na Fase 2, conforme `docs/FASE_2_SEGREDOS_COFRE_BARAO.md`.

A mansão pertence ao Barão Puff, inventor do Puffador. O protótipo dourado dele, o **Super Puffador**, fica guardado num cofre secreto atrás de uma das três portas do andar de baixo (paredes oeste, norte e sul).

- A cada rodada uma porta é sorteada em segredo e destranca entre 25% e 50% do tempo da rodada. Todos recebem o aviso "O COFRE DESTRANCOU!", e um brilho dourado escapa por baixo da porta certa. As portas erradas respondem "TRANCADA".
- Abrir exige segurar o prompt por 1,5 s. O primeiro a abrir dispara um alarme sonoro para a partida inteira, com o nome dele na tela, e a luz vermelha sobre a porta pisca até o fim da rodada.
- Dentro do cofre o piso não cai, mas um único tiro elimina (motivo `ShotInSecretRoom`, "PEGO NO COFRE!").
- No pedestal está o Super Puffador, um por rodada: 15 tiros que derrubam 2 blocos cada. Quem o carrega fica com contorno dourado, visível para todos.
- Para ninguém acampar, cada jogador pode passar no máximo 15 s no cofre por rodada. Aos 10 s recebe um aviso; aos 15 s o Barão o expulsa para o andar de baixo.
- Ajustes ficam em `GameConfig.SecretRoom`. `AlertSoundId` pode receber um som da Creator Store.
- Código: `VaultService` (regras), `VaultProps` (porta, brilho, alarme e prêmio), `SecretRoomBuilder` (arquitetura), `PuffadorModel` (as duas versões do Puffador) e, no cliente, `VaultController` (faixas via `NotificationManager`) e `SuperChargeView`.

### Identidade visual

A interface segue uma identidade própria definida em `src/client/ui/UiTheme.luau`: "noite na mansão" (fundos roxo-escuros) com as duas cores do Puffador como marca, lilás Puff e dourado Puff; títulos em FredokaOne com contorno escuro; painéis com gradiente, borda em gradiente lilás→dourado e sombra sólida. O logotipo "BLOCO PUFF" aparece no lobby e no painel admin. `UiKit` oferece o botão 3D da marca (afunda ao clicar, cresce no hover, toca um clique e é selecionável por gamepad) e animações de destaque. O botão de tiro mobile é redondo, com recarga enchendo o círculo. `FeedbackView` mostra "+1" perto da mira a cada bloco derrubado, contador de combo, chamadas de sequência ("TRIPLO!", "EM CHAMAS!", "IMPARÁVEL!", "LENDÁRIO!") e notificações curtas para marcos de blocos. O painel admin usa cartões por seção, lista de jogadores com avatar e seleção destacada, contadores de caracteres e uma pílula de status para o retorno do servidor.

Uma trilha de fundo (`MusicController`) toca localmente em cada cliente, em loop: baixa no lobby e bem mais baixa enquanto o jogador está competindo, com transição suave (eliminados voltam ao volume do lobby). O ID do áudio, os volumes e o tempo de transição ficam em `GameConfig.Music`.

### Artes da loja

**Modo foto (só no Studio).** `PhotoModeService` monta cenas prontas para prints: bonecos R15 em pose com o Puffador, buracos no piso, projéteis e pedaços congelados no ar, com a câmera já enquadrada. Aperte **Run** (F8, sem entrar como jogador) e, na barra de comandos, rode:

```lua
workspace:SetAttribute("PhotoScene", "acao")   -- tiroteio no piso de cima (thumbnail principal)
workspace:SetAttribute("PhotoScene", "queda")  -- visto do andar de baixo, alguém caindo pelo buraco
workspace:SetAttribute("PhotoScene", "icone")  -- close de um personagem mirando (base do ícone)
workspace:SetAttribute("PhotoScene", "lobby")  -- galeria envidraçada com jogadores assistindo
workspace:SetAttribute("PhotoScene", "")       -- limpa a cena e restaura os blocos
```

Depois é só tirar o print da janela do Studio (dá para ajustar a câmera à mão antes).

**Editor de capas.** Abra `tools/store-art/editor-de-capas.html` no navegador, solte o print e escolha **Thumbnail** (1920×1080) ou **Ícone** (512×512). O editor aplica o logotipo BLOCO PUFF, uma chamada e um selo opcional no estilo da identidade visual, com zoom, enquadramento por arraste, vinheta, saturação e guias de área segura, e exporta o PNG pronto para o Creator Hub.

Ainda não há dano direto, resistência de blocos, regeneração durante a rodada, persistência ou monetização.

Para testar a zona de eliminação manualmente: entre em `Active` com 2+ jogadores, destrua o bloco sob um participante e confirme que ele cai e é eliminado com a mensagem "Você caiu da arena" no HUD, sem perda de vida instantânea no momento do disparo. Os atributos `IsEliminated`, `EliminationReason` e `EliminatedAtRoundId` no `Player` refletem a causa e a rodada.

Um jogador eliminado durante `Active`/`Ending` tem sua câmera automaticamente redirecionada para acompanhar um participante ainda ativo, em vez de ficar parada no próprio personagem já eliminado no lobby. É um comportamento puramente do cliente (`SpectatorController`, lendo apenas atributos já replicados de `Player`), sem impacto em nenhum estado autoritativo. O alvo observado pode ser alternado manualmente entre os participantes ainda ativos — setas do teclado, D-Pad do gamepad, ou os botões `<`/`>` que aparecem na tela durante o modo espectador, que também mostra quantos participantes ainda seguem ativos.
