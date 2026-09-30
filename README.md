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

### Controles e mira (Fase 1, entrega 1.5)

- **Mira:** retículo menor (anel de 18 px, ponto de 4 px, traços finos) sem a etiqueta "BLOCO". Fica verde sobre um bloco válido; o marcador de acerto é amarelo em bloco e rosa em jogador (empurrão).
- **Segurar para atirar:** o botão PUFF (toque), o clique do mouse e o gatilho direito (R2/RT) disparam continuamente enquanto estiverem segurados, respeitando a cadência (`GameConfig.Puffador.FireCooldown`, revalidada no servidor).
- **Celular:** tocar na tela para girar a câmera não dispara mais; o disparo vem só do botão PUFF. O botão fica à esquerda e um pouco acima do botão de pulo nativo do Roblox e se reposiciona conforme o tamanho da tela.
- **Controle:** R2/RT atira e o analógico direito gira a câmera (padrão do Roblox); a dica de controle mostra o comando certo para cada dispositivo.
- **Assistência de mira:** não foi adicionada. O game design só a prevê se o playtest mostrar necessidade.

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

### Corredores secretos e quadros (Fase 2, entrega 2.1)

Escopo em `docs/FASE_2_SEGREDOS_COFRE_BARAO.md`.

- **Corredores:** do lado de fora das paredes norte e sul há um corredor escondido (`CorridorBuilder`). Ele tem um patamar no nível do andar de baixo, uma rampa e um patamar no nível do andar de cima, e serve para subir, descer ou fugir. O cofre fica só na parede oeste, separado dos corredores.
- **Entradas escondidas:** cada corredor tem uma entrada por andar. Elas sempre existem, mas começam atrás de um painel falso igual à parede, que não colide: quem conhece o lugar atravessa antes da revelação.
- **Quadros:** a cada rodada um quadro de cada andar é sorteado em segredo. Acertá-lo com o Puffador revela, para todos, as entradas daquele andar: o painel some, surge uma moldura dourada acesa e aparece a faixa "PASSAGEM SECRETA!" com o nome de quem descobriu. Revelar um andar não revela o outro. Quadros errados respondem com um som e "NÃO ERA ESSE QUADRO".
- **Código:** `SecretPassageService` (regras e painéis), `CorridorBuilder` (arquitetura), `BuildingLayout.getCorridors`, e `SecretPassageController` no cliente. Os quadros da arena são marcados com a tag `RevealPainting`.

### Barão e Tocas Seguras (Fase 2, entrega 2.2)

- **Barão:** vira-lata caramelo de camisa verde e amarela, feito de peças nativas (`BaraoModel`). Há um só por rodada. Começa dormindo no patamar de baixo de um corredor e acorda com latidos depois de `WakeDelay` segundos (20). Depois disso patrulha, persegue quem estiver no mesmo corredor e, se só houver gente no outro corredor por 4 s, reaparece lá pela ponta mais distante.
- **Contato:** não causa dano. Dá um empurrão forte para longe dele, rumo à saída daquele lado. Quem está no vão de uma entrada é jogado para dentro do prédio. Toca um som engraçado aleatório e mostra "AU AU!" para quem foi empurrado.
- **Como escapar:** a perseguição (14) é mais lenta que o jogador (16). Também dá para pular por cima dele, porque o contato só conta com os pés abaixo de `JumpClearance`.
- **Pistas:** a única pista é o áudio 3D (passos em loop e latidos em intervalos irregulares). Não há minimapa nem indicador de distância.
- **Tocas Seguras:** são duas por corredor, nichos na parede externa, uma em cada patamar. Cabe um ocupante por vez; a luz fica verde quando a Toca está livre e laranja quando está ocupada. O ocupante fica protegido do Barão, mas não do Puffador: um empurrão o tira de lá e a Toca fica livre.
- **Contra camping:** cada ocupação dura no máximo 8 s, com aviso 3 s antes do fim. Depois o jogador é empurrado para o corredor e fica 10 s sem poder usar Tocas.
- **Ajustes:** ficam em `GameConfig.Barao` e `GameConfig.Toca`. Os sons atuais são provisórios, embutidos no Roblox; troque `BarkSoundIds`, `FunnySoundIds` e `FootstepSoundId` por áudios da Creator Store (`rbxassetid://...`).
- **Código:** `BaraoService` (comportamento), `BaraoModel`, `TocaService`, `CorridorBuilder` (nichos) e `BuildingLayout.getTocas` / `isInsideToca` / `getCorridorFloorY`. No cliente, `BaraoController` mostra os avisos.

### Puffdex empolgante — Camada A (Fase 4, ajuste pós-4.5)

Cada Puff agora tem um **formato de efeito** e uma **frase de história**, além das cores (`effect` em `PuffStyle` e `lore` em `PuffDefinition`).

- **Formatos:**
  - 💨 Sopro, ✨ Brilhos, 🫧 Bolhas, ☁️ Nuvenzinha, ❄️ Neve, ⚡ Raio, 🌀 Espiral, 🎉 Confete, 🔥 Chamas e 🌈 Arco-íris;
  - são 10 formatos compartilhados pelos 22 Puffs.
- **No disparo** (`PuffEffects`):
  - partículas do formato acompanham o projétil;
  - o impacto solta uma explosão das mesmas partículas;
  - o Arco-íris pinta o rastro com o espectro inteiro;
  - Espiral e Raio desviam só o projétil visual em espiral ou zigue-zague. O acerto continua seguindo a mira, igual para todos.
- **No Salão da Coleção:** cada pedestal solta, com calma, as partículas do seu Puff, e a placa mostra o ícone do formato.
- **No Puffdex:**
  - **prévia animada** (`PuffPreview`): o Puff atravessa a janelinha em loop com o rastro e as partículas do formato. É 2D porque o ViewportFrame do Roblox não desenha partículas;
  - **cartões por raridade** (`PuffCardFx`): Raro com brilho suave na borda, Épico com borda animada e Lendário com borda dourada e reflexo holográfico;
  - **desbloqueio com comemoração:** clarão, pulo do cartão e som, com um Puff novo de cada vez ao abrir o painel;
  - o detalhe mostra a raridade, o formato e a história. Os bloqueados continuam como "?" com a dica.
- **Pronto para a Camada B:**
  - texturas próprias entram trocando os ids em `PuffEffects` (`TEXTURES`);
  - a ilustração de cada cartão entra no campo `image` do catálogo.

### Embarque e aquecimento no mirante (Fase 4, ajuste pós-4.5)

- **Entrar e sair são livres.** Passar pela porta coloca na fila, com o aviso "✅ Você está na fila!" e um som, e voltar pela porta tira da fila ("Você saiu da fila").
- **Embarque encerrado:**
  - nos **últimos 5 s** da contagem as portas fecham com uma barreira de luz dourada, e quem está na fila vê "🔒 EMBARQUE ENCERRADO!";
  - a barreira reabre quando os escalados descem para a arena ou quando a contagem é cancelada;
  - o botão JOGAR é recusado enquanto as portas estão fechadas;
  - quem está na fila ouve bipes no "3, 2, 1".
- **Mirante mais largo:** passou de 20 para **32 studs**, com o centro livre; só restaram dois sofás, nas pontas. O Casarão acompanha, porque tudo sai da mesma geometria.
- **Sinalização:**
  - do lado do Casarão, cada porta tem um portal verde com o letreiro **"🏟 ENTRAR NA FILA — Entre e saia quando quiser"** e uma passadeira com setas vindo do Salão Principal;
  - dentro, um painel em cada ponta mostra quantos estão na fila, o tempo ou quantos faltam, os avatares de quem está na fila e o placar do aquecimento.
- **Aquecimento no mirante** (`WarmupService`), sem prêmio:
  - quem está na fila recebe o Puffador de treino e estoura **balões-Puff** que sobem na frente do vidro;
  - dois **trampolins** nas pontas, com o impulso aplicado no cliente;
  - os balões somem quando o embarque fecha.
- **Código:**
  - `QueueVisuals` (portais, barreiras e painéis) e `WarmupService`;
  - `MatchQueueService.setCountdown` é chamado pelo `RoundService` a cada segundo da contagem;
  - novos campos em `QueueConfig`.

### Partida isolada do lobby e ajustes de tela (Fase 4, ajuste pós-4.5)

- **Quem está no lobby não vê nada da partida:**
  - os avisos da partida (cofre, passagens secretas, Momentos Puff) e o resultado final vão só para quem está nela (`MatchAudience`: escalados, inclusive os eliminados);
  - no cliente, o HUD de combate, os anúncios e o cronômetro da partida ficam só com os participantes;
  - o cronômetro da contagem só aparece para quem está na fila;
  - quem está fora vê apenas a etiqueta "⚔️ PARTIDA EM ANDAMENTO" com a situação da fila da próxima.
- **Reações:** só para quem assiste (eliminados e quem está no mirante), numa coluna na borda direita, no meio da altura, longe dos botões de pulo e de tiro.
- **Botão ADM:** foi para o canto inferior esquerdo, longe do HUD do topo e dos avisos.
- **Vitrine do Salão da Coleção sem neon:** cada Puff é uma nuvem fosca nas cores do rastro, sobre um pedestal de mármore com faixa metálica da cor da raridade.

### Fila da partida no mirante (Fase 4, ajuste pós-4.5)

A partida só puxa quem quer jogar: **o mirante (a galeria envidraçada) é a fila da partida**. Quem está passeando pelo Casarão não é escalado.

- **Entrar e sair:**
  - estar no mirante coloca na fila (`MatchQueueService`);
  - com **2 na fila** começa a contagem de **20 s**, e se sobrar menos de 2 ela para;
  - sair do mirante tira da fila.
- **Quem joga:** só quem está na fila quando a contagem acaba. A rotação justa continua, e quem está fora mantém a posição (`PartySelection` com `eligible`).
- **Party:** basta um membro no mirante para o grupo todo entrar na fila. Os demais vão direto para a arena quando a partida começa.
- **Depois da partida:** quem jogou volta para o mirante, já na fila da próxima, e quem quiser passear sai de lá. Eliminados também renascem no mirante, assistindo à arena. Quem acabou de entrar no jogo nasce no Salão Principal.
- **HUD:**
  - o cartão central "BlocoPuff / Aguardando jogadores" saiu;
  - no canto superior direito fica uma etiqueta da fila ("🏟 FILA 1/2", "🏟 NA FILA 1/2", "✅ VOCÊ ESTÁ NA FILA") com o botão **🏟 JOGAR**, que leva ao mirante;
  - na contagem, o cronômetro fica acima da etiqueta;
  - o aviso "AGUARDE SUA VEZ" só aparece para quem estava na fila.
- **No mapa:** faixa verde e placa "🏟 FILA DA PARTIDA" em cada porta do mirante, e placas "🏟 MIRANTE · JOGAR" no Salão Principal.
- **Sozinho na fila por 60 s:** aviso discreto "CHAME UM AMIGO", uma vez por espera.
- **Telemetria:** `QueueJoinButton` e `QueueLonely`.
- **Código:** `QueueConfig`, `MatchQueueService` (atributo `InMatchQueue`, remote `MatchQueue`) e, no cliente, `MatchQueueController`.

### O Casarão e alertas fora do centro (Fase 4, ajuste pós-4.5)

O lobby virou um **Casarão** de 110 × 130 studs (a galeria tinha 20 × 90), anexo a leste do prédio da arena, com pé-direito de 24 studs. Três portas largas na parede leste da galeria levam ao Salão Principal; a galeria continua sendo o mirante da arena, com o Hall da Fama acima das portas.

- **Salão Principal** (60 × 60): todos nascem e esperam aqui, em volta da estátua dourada "CASARÃO PUFF". Tem sofás e plantas, e os arcos levam às outras salas, cada um com uma placa dizendo para onde vai.
- **Salão da Coleção** (norte): vitrine com **todos os 22 Puffs** do catálogo em duas fileiras, o púlpito do **Puffdex** e a **Puff Machine**.
- **Jardim do Barão** (leste): gramado com o **Barão amigável** na caminha, a **loja "em breve"** e o Puff Perdido (conquista secreta) escondido num canto.
- **Ponto de Encontro** (ala sul, oeste): o **quadro de desafios** e o **canto da Party** (sofás e uma placa com prompt que abre a Party).
- **Treino** (ala sul, leste): faixa verde, seis alvos fixos e dois que deslizam.
- **Ninguém nasce em cima de móveis:** estátua, sofás e plantas do Salão reservam as suas áreas no `LobbyService` (`addReservedAreas`).
- **Celular:** seis lustres sem sombra (nenhuma arandela), placas com distância máxima e nada animado além dos alvos de treino.
- **Alertas fora do centro:**
  - os anúncios (`AnnouncementView`) e a faixa de avisos (`BannerView`) viraram cartões compactos na **borda esquerda**, que entram deslizando (anúncio a 42% da altura, aviso a 56%);
  - o convite de Party desceu para 72%;
  - o cartão de espera do lobby ficou menor e mais colado ao topo;
  - o centro (mira) e o topo (cronômetro) ficam livres.
- **Código:**
  - `MansionConfig` e `MansionLayout` (geometria única do Casarão), `MansionService` (construção) e `WallBuilder` (paredes com vãos, também usado pelo `BuildingService`);
  - `BuildingDecor` aceita vãos de largura e altura próprias e lustres sem sombra.

### Lobby expandido (Fase 4, entrega 4.5)

A galeria (20 × 90 studs) ganhou estações físicas. Cada uma tem um ProximityPrompt que abre a tela correspondente, e o centro e os sofás continuam livres.

- **Ponta norte:**
  - **Puff Machine** física: gabinete com cúpula de cápsulas; o prompt "Girar" abre a máquina;
  - **Barão amigável** dormindo numa caminha ("Zzz"). O prompt "Fazer carinho" faz ele pular de alegria (💜), sem nenhuma hostilidade;
  - o Puff Perdido (conquista secreta da 4.3) continua escondido atrás do caixote no canto.
- **Lado do vidro:**
  - **vitrine de Puffs** (exibição de cosméticos): um Puff de cada raridade em pedestais, com nome e raridade; o prompt abre o Puffdex;
  - **quadro de desafios**, que abre os desafios do dia;
  - **loja "em breve"**, só a banca fechada. O prompt avisa que nada é vendido por enquanto (preparação para a Fase 5).
- **Ponta sul, área de treino** (`TrainingService`): quem passa da faixa verde e não está competindo recebe um Puffador de treino e pratica a mira em quatro alvos (três fixos e um que desliza).
  - Acertar dá o mesmo retorno visual de sempre (+1 e combo).
  - Os disparos de treino só acertam alvos: não quebram bloco, não empurram ninguém e não contam estatística nem XP (`training` no `ProjectileService`, `setTraining` no `PuffadorService`).
  - Quem é escalado para a partida troca na hora pelo Puffador da partida. Ao sair da área o de treino some, e no fim da partida quem continua na área recebe o de treino de novo.
- **Ninguém nasce em cima das estações:** o `LobbyService` recebe as áreas reservadas e tira essas posições da lista de lugares da galeria.
- **Celular:** poucas peças, nenhuma luz extra, placas com distância máxima e só um alvo animado pelo servidor.
- Os atalhos do cartão de perfil continuam funcionando: as estações são um caminho a mais, físico.
- **Telemetria:** `BaraoPet`, `TrainingSession` (acertos e duração) e `SessionStart` (dias desde a criação do perfil, com a faixa D0, D1+, D7+ ou D28+, para medir D1/D7/D28).
- **Código:** `LobbyStationsService` e `TrainingService`. No cliente, `LobbyStationsController`.

### Party e espectador social (Fase 4, entrega 4.4)

- **Party** (`PartyService`, `shared/config/SocialConfig`): grupo de até 4 jogadores do mesmo servidor, um terço da sala de 12, então sobra vaga para quem joga sozinho.
  - Chamar alguém do servidor manda um convite, que expira em 30 s. O cartão de convite aparece na lateral esquerda com ENTRAR e AGORA NÃO.
  - Quem está competindo só vê o convite ao voltar ao lobby, se ele ainda não tiver expirado.
  - O líder (👑) pode remover alguém. Se o líder sai, o próximo assume; Party de uma pessoa só acaba.
  - O botão "CHAMAR AMIGOS PARA O JOGO" abre o convite nativo do Roblox (`SocialService`).
- **Entrar junto:** a seleção de participantes (`PartySelection`) põe a Party inteira ou nenhum membro.
  - Se a Party não cabe nas vagas que sobram, ela espera na frente da fila (entra primeiro na próxima), quem vem atrás ocupa as vagas, e os membros recebem o aviso "A partida lotou para a sua Party".
  - Quem jogou vai para o fim da fila, como antes, então a Party segue junta partida após partida.
- **Na partida** cada um joga por si: a Party não dá nenhuma vantagem.
- **Espectador social:**
  - o eliminado segue primeiro alguém da própria Party (marcado com 👥) e continua trocando a câmera pelas setas, D-Pad ou botões;
  - reações com 5 emojis fixos (👏 😮 😂 🔥 💜), sem texto livre;
  - só quem não está competindo reage, e só quem não está competindo vê: nada aparece na tela de quem joga. A barra fica discreta no canto inferior direito;
  - **torcida:** o eliminado que fica assistindo até o fim da partida ganha +1 🎟 (só quem jogou a rodada de verdade, então não dá para ganhar parado no lobby).
- **Cartão de perfil:** os atalhos agora ficam numa fileira embaixo do cartão (🏆 ✨ 🎰 📋 👥), para caber em celular. O 👥 mostra o tamanho da Party.
- **Telemetria:** `PartyCreated`, `PartyInvite`, `PartyJoined`, `PartyLeft` (motivo), `PartyMatch` (Party jogando junta), `PartyReplay` (de novo na partida seguinte), `PartyDeferred` (sem vaga), `Reaction`, `SpectatorSwitch` e `TicketsEarned` com a fonte `Spectator`.
- **Código:** `PartyService`, `data/PartySelection`, `ReactionService` e `SocialConfig`. No cliente, `PartyController`, `PartyView`, `PartyInviteView`, `ReactionController`, `ReactionView` e `SpectatorController`.

### Desafios, retorno diário e conquistas secretas (Fase 4, entrega 4.3)

- **Desafios diários** (`shared/config/DailyConfig`): 3 por dia, um de cada nível (fácil, médio e difícil), sorteados de forma fixa por jogador e dia (o mesmo em qualquer servidor).
  - Todos são de gameplay: partidas, blocos, derrubadas, Top 3, Barão, passagem secreta, vitória, cofre, reconstrução e Volta por Cima. Nenhum é do tipo "fique online".
  - O progresso sai da soma da rodada calculada pelo servidor, e só conta rodada jogada de verdade (com XP).
  - Concluir dá tickets na hora (2 a 4), sem botão de resgatar.
  - O dia vira à meia-noite de Brasília (`DayOffsetHours = -3`). Se virar com o jogador online, os desafios trocam no fim da próxima rodada.
- **Retorno diário:** recompensa automática no primeiro login do dia, em ciclo de 7 dias (2, 2, 3, 3, 4, 4 e 8 🎟).
  - Sequência amigável: perder um dia não zera nada (`GraceDays = 1`). O recorde fica guardado.
- **Conquistas secretas** (`shared/config/SecretCatalog`): ficam como "???" com uma pista curta até alguém conseguir. Cada uma vale 5 🎟, uma vez só, e todas são detectadas no servidor (`SecretAchievementService`):
  - **Passagem Oculta:** atravessar uma passagem de um andar ainda não revelado;
  - **Pula-Barão:** pular o Barão 3 vezes na mesma partida;
  - **Mestre dos Quadros:** revelar as passagens dos dois andares na mesma partida;
  - **Por um Fio:** vencer com até 15% da arena de pé;
  - **Puff Perdido:** achar o Puff dourado escondido atrás de um caixote num canto da galeria.
- **Interface:** botão 📋 no cartão de perfil (com uma bolinha quando há desafio a fazer) abre o painel **DESAFIOS**.
  - Mostra os desafios de hoje com barra de progresso e o tempo até os próximos.
  - Mostra o ciclo de 7 dias com a sequência e as conquistas secretas.
  - Avisos comemoram o retorno diário, o desafio concluído e a conquista secreta.
- **Uma vez só:** no perfil, a recompensa do dia fica marcada pelo último dia recebido, os desafios guardam `done` e as conquistas ficam pelo id. Reconectar não repete nada. Numa sessão que não salva, nada é comemorado (voltaria como novo).
- **Perfil v5:** passa a guardar `daily`, `challenges`, `challengesCompleted` e `secrets`. A migração v4 → v5 é automática.
- **Arquitetura:** o `PlayerDataService` ganhou `update(player, updater, saveNow)`, uma atualização atômica genérica do perfil (o `updater` não pode pausar).
  - O equipar do Puffdex, o giro da Puff Machine e as conquistas secretas passaram a viver nos seus próprios serviços, usando essa função.
- **Telemetria:** `ChallengeAssigned`, `ChallengeCompleted`, `ChallengesOpened`, `DailyReturn` (sequência e recorde), `SecretAchievement` e `TicketsEarned` com as fontes `Daily`, `Challenge` e `Secret`.
- **Código:** `DailyConfig`, `SecretCatalog`, `data/DailyRules`, `SecretAchievementService` e `PlayerDataService`. No cliente, `ChallengesController` e `ChallengesView`.

### Tickets e Puff Machine (Fase 4, entrega 4.2)

- **Tickets** (moeda não competitiva, só para a Puff Machine): saem só jogando, calculados pelo servidor no fim da rodada (`RewardRules.ticketsForRound`).
  - 1 por partida jogada de verdade (quem ganhou XP), +1 no Top 3 e +1 na vitória.
  - +2 por nível ganho.
  - Teto de 12 por rodada. O pós-partida mostra "+XP +N 🎟".
- **Puff Machine:** botão 🎰 no cartão de perfil (lobby), com o saldo de tickets num selo.
  - Cada giro custa 5 🎟 e dá um dos 8 Puffs exclusivos da máquina: Chiclete, Limão e Nuvem (Comuns), Oceano e Arco-Íris (Raros), Neon e Aurora (Épicos) e Cometa (Lendário).
  - Os Puffs de façanha continuam só por façanha.
- **Transparente e sem estrutura predatória:**
  - chances fixas mostradas na própria máquina (Comum 60%, Raro 28%, Épico 10%, Lendário 2%), com quantos de cada raridade o jogador já tem;
  - Épico ou melhor garantido a cada 10 giros sem um, com o contador visível;
  - Puff repetido devolve 2 🎟 (e soma na quantidade do item);
  - não existe compra de tickets nem de giros.
- **Integridade:** o sorteio usa o `Random` do servidor.
  - Conferir o saldo, gastar e guardar o Puff acontecem numa única atualização do perfil (`PlayerDataService.machinePull`), sem pausa entre elas, então não há gasto duplo. O perfil é salvo logo depois.
  - Só gira com o perfil sendo salvo, só no lobby e com intervalo mínimo entre giros (`RewardConfig`).
- **Revelação:** a cápsula gira pelas cores dos Puffs até a resposta chegar (mínimo de 1,8 s) e revela o Puff com a raridade e "NOVO!" ou "repetido, +2 🎟". O botão VER NO PUFFDEX leva direto ao Puff.
- **Perfil v4:** passa a guardar `tickets`, `ticketsEarned`, `ticketsSpent`, `machinePulls` e `machinePity`. A migração v3 → v4 é automática.
- **Telemetria:** `TicketsEarned` (por fonte, inclusive a devolução de repetidos), `TicketsSpent`, `PuffMachineOpened`, `PuffMachinePull` (Puff, raridade, novo ou repetido) e `PuffUnlocked` com origem `Machine`.
- **Código:** `RewardConfig`, `data/RewardRules`, `PuffMachineService` e `PlayerDataService.machinePull`. No cliente, `PuffMachineController` e `PuffMachineView`.

### Puffdex e primeira coleção (Fase 4, entrega 4.1)

Escopo em `docs/FASE_4_PUFFDEX_RECOMPENSAS_SOCIAL.md`.

- **Coleção inicial** (`shared/config/PuffCatalog`): 14 Puffs em quatro raridades, todos conquistados jogando (mais os 8 da Puff Machine, na 4.2).
  - **Comuns:** Branco (inicial), Algodão Doce (nível 3), Menta (5 partidas), Pêssego (150 blocos).
  - **Raros:** Gelo (nível 10), Elétrico (15 derrubadas), Tijolinho (10 blocos reconstruídos), Sussurro (3 passagens secretas).
  - **Épicos:** Brasil (20 Top 3), Galáxia (nível 25), Cofre (3 cofres conquistados).
  - **Lendários:** Barão (25 fugas do Barão), Dourado (25 vitórias), Fênix (10 Voltas por Cima).
  - Ids ficam salvos nos perfis: nunca renomeie nem reaproveite um id.
- **Só visual:** o Puff equipado muda o rastro, o brilho e as faíscas do impacto do disparo.
  - Tamanho, velocidade, alcance, cadência, empurrão e acerto são iguais para todos.
  - O miolo do projétil continua branco, para não atrapalhar a visibilidade.
- **Desbloqueio no servidor:** o `PlayerDataService` concede os Puffs merecidos ao carregar o perfil e depois de cada rodada.
  - Perfis antigos recebem na hora o que já tinham conquistado.
  - O inventário é indexado pelo id do Puff, então nada duplica ao reconectar e cada recompensa é dada uma vez só.
- **Perfil v3:** o perfil passa a guardar `puffs` (data, quantidade, origem e um `uid` por item) e `equippedPuff`. A migração v2 → v3 é automática.
- **Equipar:** o painel pede ao servidor pelo remote `Puffdex` (`PuffdexService`), que confere se o jogador tem o Puff.
  - O Puff equipado fica no atributo `EquippedPuff` do jogador, que todos os clientes enxergam.
  - É dali que o `PuffadorService` tira as cores de cada disparo.
- **Interface:** o botão ✨ ao lado do 🏆 no cartão de perfil (lobby) abre o **PUFFDEX**.
  - Grade com a coleção: os Puffs bloqueados aparecem como "?" com a raridade.
  - O detalhe mostra a prévia das cores, a origem, a data, a dica curta de como conseguir e o progresso (por exemplo, "7 / 15").
  - Puffs novos ganham o aviso "NOVO PUFF!" e a etiqueta NOVO.
- **Trading:** preparado, mas desligado (`PuffCatalog.TradingEnabled = false`, campo `tradable` e `uid` por item). Não existe nenhum caminho de troca.
- **Telemetria:** `PuffUnlocked` (id, raridade e origem), `PuffCollection` (progresso), `PuffEquipped` e `PuffdexOpened`.
- **Código:** `PuffCatalog`, `PuffTypes`, `data/PuffInventory`, `ProfileSchema`, `PlayerDataService` e `PuffdexService`. No cliente, `PuffdexController` e `PuffdexView`.

### Ranking global e Hall da Fama (Fase 3, entrega 3.4)

- **Categorias** (poucas de propósito): vitórias, derrubadas, blocos destruídos e cofres conquistados. Cada uma tem um OrderedDataStore (`BlocoPuffLB_v1_<categoria>`, chave = UserId).
- **Integridade:**
  - os valores vêm só do perfil calculado e salvo pelo servidor (`PlayerDataService`), e só de perfis que estão sendo salvos de verdade;
  - o cliente nunca envia números para o ranking;
  - valores acima de 10 milhões são ignorados, e empates dividem a mesma posição.
- **Atualização:**
  - **Gravação:** a cada 60 s, só das categorias que mudaram, e também quando o jogador sai ou o servidor fecha.
  - **Leitura:** o top 10 é lido a cada 2 min em segundo plano, então o lobby nunca espera o DataStore.
  - **Falhas:** se uma categoria falhar, fica a leitura anterior.
- **Hall da Fama** (`HallOfFameService`): cinco painéis no alto da parede leste da galeria, entre o topo das janelas e a sanca. Da esquerda para a direita:
  - Vitórias;
  - Derrubadas;
  - **Lenda do BlocoPuff** (1º em vitórias, com foto) e a linha "Ranking da temporada: em breve";
  - Blocos destruídos;
  - Cofres conquistados.

  Cada painel mostra o top 5. O texto é desenhado pelo servidor.
- **Painel RANKING:** botão 🏆 ao lado do cartão de perfil, com o top 10 por categoria em abas, foto, posição e valor; a sua linha fica em dourado. A aba 📅 de temporada está reservada e desativada. O painel fecha quando você entra na partida.
- **Telemetria:** `LeaderboardOpened` (com a aba) e `HallOfFameViewed` (ficou 3 s na galeria virado para os painéis; uma vez por sessão).
- **Corrigir o ranking:**
  1. Corrija primeiro o perfil (procedimento da entrega 3.1).
  2. No Data Stores Manager, ajuste ou apague a chave `<UserId>` em cada `BlocoPuffLB_v1_<categoria>`.
  3. O valor volta a ser gravado a partir do perfil na próxima vez que ele mudar.
- **Studio:** sem acesso às APIs, os painéis mostram "Ranking indisponível".
- **Código:** `LeaderboardService`, `HallOfFameService` e `LeaderboardTypes`. No cliente, `LeaderboardController` e `LeaderboardView`.

### Resultado avançado (Fase 3, entrega 3.3)

- **Pódio:** os três primeiros, com foto (headshot), nome e degraus de ouro, prata e bronze. Em empate, o texto mostra a mesma posição.
- **Sua linha:** posição, blocos e derrubadas.
- **Destaques** (até 5; o seu fica em dourado):

  | Destaque | Critério |
  |----------|----------|
  | Demolidor | Mais blocos, mínimo 5 |
  | Mais derrubadas | Mais derrubadas |
  | Dono do cofre | Pegou o Puffador do Cofre ou abriu o cofre |
  | Escapou do Barão | Mais fugas |
  | Descobridor | Mais passagens reveladas |
  | Volta por Cima | Voltou da Segunda Chance e derrubou alguém ou venceu |

  Nenhum destaque premia comportamento antijogo: não há prêmio por se esconder na Toca, ficar parado ou fugir da luta. Todos vêm de jogar de verdade.
- **XP da rodada:** o total, a barra de nível (ou "NÍVEL 4 → 5!") e cada fonte do XP. Ele chega pelo perfil logo depois do resultado, marcado com o número da rodada, e só entra no painel dessa mesma rodada.
- **Código:** `RoundResultBuilder` (destaques e contadores por jogador), `ResultTypes`, `ResultsView` e `ResultsController`.

### XP, Nível e Prestígio (Fase 3, entrega 3.2)

- **XP por rodada** (`XpCalculator`, calculado no servidor ao fim de cada rodada):

  | Fonte | XP |
  |-------|----|
  | Concluir a partida (quem disparou pelo menos um Puff) | 20 |
  | Colocação (do último ao primeiro) | 0 a 30 |
  | Vitória | 40 |
  | Derrubadas | 8 cada, até 5 |
  | Blocos destruídos | 1 a cada 2, até 20 |
  | Passagem descoberta | 10 cada |
  | Cofre aberto / conquistado | 10 / 15 |
  | Fuga do Barão | 8 cada, até 2 |
  | Volta por Cima | 15 |
  | Construções | 2 cada |

- **Contra farming:**
  - multiplicador pelo tamanho da partida: 0,6 com 2 participantes, 0,8 com 3 e 1,0 com 4 ou mais;
  - quem não disparou nada não ganha XP de participação, colocação nem vitória;
  - o XP é calculado com os mesmos números já limitados que vão para o perfil;
  - cada fonte tem limite, e há um teto de 400 XP por rodada;
  - o XP entra junto com a rodada, pela mesma chave única, então também não duplica ao reconectar.
- **Nível:** para ir do nível N ao N+1 são necessários 100 + 25 × (N − 1) XP, até o nível 50 (34.300 XP no total). O nível é sempre recalculado a partir do XP (`LevelCurve`, compartilhado entre servidor e cliente), então é determinístico. Nível não muda nada na força do jogador.
- **Prestígio:** preparado, mas desligado (`ProgressionConfig.PrestigeEnabled = false`). Quando liberado, no nível 50 o jogador soma uma estrela de prestígio (até 10) e recomeça do nível 1; é só status, sem força. Chamada: `PlayerDataService.prestige(player)`.
- **Perfil v2:** o formato ganhou `levelReachedAt`. A migração v1 → v2 é automática ao carregar.
- **Na tela:**
  - **Cartão no lobby:** fica no canto superior esquerdo, com nível, estrelas de prestígio e barra de XP; o botão PERFIL abre as estatísticas da carreira. Se o progresso não estiver sendo salvo, o cartão avisa.
  - **Fim de cada rodada:** o XP ganho aparece no painel de pós-partida (entrega 3.3).
  - **Subida de nível:** faixa "NÍVEL N!" com som.
- **Telemetria:**
  - `XpGained` (por fonte) e `XpRound` (total, com a faixa de nível e se venceu, para cruzar nível com vitória);
  - `LevelUp` (tempo no nível anterior) e `RoundAfterLevelUp` (replay depois de subir de nível);
  - `Prestige`.
- **Ajustes:** `shared/config/ProgressionConfig`.
- **Código:** `LevelCurve`, `XpCalculator` e `PlayerDataService`. No cliente, `ProgressionController` e `ProfileCardView`.

### Perfil persistente (Fase 3, entrega 3.1)

Escopo em `docs/FASE_3_PROGRESSAO_COMPETICAO.md`.

- **O que é salvo** (DataStore `BlocoPuffProfiles_v1`, chave `u_<UserId>`):
  - partidas, vitórias, Top 3 (só em partidas com 4 ou mais participantes);
  - derrubadas, blocos destruídos e blocos construídos;
  - cofres abertos e conquistados, fugas do Barão, passagens descobertas e Voltas por Cima;
  - XP, nível e prestígio, preparados para a 3.2.
- **Quem calcula:** tudo é calculado pelo servidor no fim da rodada, a partir do resultado (`RoundService.commitProfiles`). O cliente nunca envia estatística nem XP. Quem sai no meio da rodada não recebe a rodada. Se o perfil ainda estiver carregando no fim da rodada, a rodada fica guardada e é somada quando ele carregar.
- **Sem duplicação:** cada rodada tem uma chave única (servidor + rodada + início). O perfil guarda as últimas 10 chaves aplicadas, então a mesma rodada nunca é somada duas vezes, nem ao reconectar.
- **Trava de sessão:** só um servidor por vez salva o perfil de um jogador. Ao entrar, o servidor grava no perfil uma trava única: JobId mais um identificador do carregamento, para que sair e voltar rápido no mesmo servidor não confunda as sessões. O salvamento automático grava quem mudou e renova as travas, um jogador por vez; ao sair, o servidor salva e libera a trava.
  - **Troca de servidor:** se outro servidor ainda segura o perfil, o novo tenta de novo por até 30 s. Se não conseguir, o jogador joga com um perfil que não é salvo nesta sessão (`saved = false` na cópia do cliente).
  - **Trava abandonada:** uma trava sem renovação há 10 min, de um servidor que caiu, é assumida pelo próximo.
  - **Fechamento do servidor:** `BindToClose` espera os carregamentos em andamento e salva todos os perfis.
- **Valores impossíveis:** cada soma de rodada é limitada ao máximo possível (por exemplo, derrubadas ≤ jogadores − 1, blocos ≤ total da arena). Um corte gera aviso no log do servidor e o evento de telemetria `ProfileAnomaly`.
- **Versões do formato:** `ProfileSchema.CurrentVersion` com passos de migração em `MIGRATIONS`. Dados de uma versão mais nova que o servidor conhece (atualização em andamento) são carregados só para leitura, para não apagar campos novos. Valores corrompidos (negativos, NaN, tipos errados) viram 0 ao carregar.
- **Procedimento para dados inválidos** (correção administrativa):
  1. Confirme o problema pelo log (`Profile anomaly for ...`) ou pela telemetria `ProfileAnomaly`.
  2. Peça ao jogador para sair de todos os servidores; sem isso, a trava de sessão sobrescreve a correção.
  3. No Creator Hub (Data Stores Manager) ou via Open Cloud, abra `BlocoPuffProfiles_v1` / `u_<UserId>` e corrija só os campos de `stats` (inteiros ≥ 0). Não mexa em `session` nem em `appliedRounds`.
  4. Se `session` estiver preso a um servidor que não existe mais, apague só `session` ou espere 10 min.
  5. Registre a correção (quem, quando, o quê e por quê) fora do jogo.
- **Studio:** para salvar de verdade, ative "Enable Studio Access to API Services". Sem isso, o perfil funciona só na memória e o log avisa.
- **Código:** `PlayerDataService`, `ProfileSchema`, `RoundStatsService`, `config/ProfileConfig` e `ProfileTypes`. No cliente, `ProfileController`, que recebe a cópia, pede de novo ao iniciar e avisa as telas.

### Alertas, Momentos Puff e telemetria dos segredos (Fase 2, entrega 2.4)

- **Prioridade dos alertas** (`NotificationManager`, faixa do topo): alertas críticos passam na frente dos menores e nada se sobrepõe.

  | Prioridade | Alertas |
  |------------|---------|
  | Crítica | Barão acordou / cofre destrancou; cofre aberto (com o Barão bravo) |
  | Alta | Passagem secreta descoberta; Cofre Conquistado (Puffador do Cofre obtido); avisos do admin |
  | Normal | Momentos Puff; "AU AU!" (contato do Barão); aviso de saída da Toca |
  | Baixa | Toca Segura; modo Construir; quadro errado |

- **Momentos Puff** (`PuffMomentService` / `PuffMomentController`): cada jogador conta no máximo uma vez por tipo por rodada.
  - **Escapou do Barão:** pulou por cima dele, ou fugiu de uma perseguição de pelo menos 3 s sem ser pego.
  - **Volta por Cima:** depois de usar a Segunda Chance, derrubou alguém ou venceu a rodada.
  - **Cofre Conquistado:** pegou o Puffador do Cofre.
  - **Descoberta secreta:** revelou uma passagem.

  Cofre e descoberta usam a faixa que já existia; os demais ganham faixa própria.
- **Tensão:** quem está sendo perseguido ouve uma batida grave sem direção (`BaraoTensionController`), que acelera e sobe de volume enquanto a perseguição dura. Ela não indica de onde o Barão vem; a pista de posição continua sendo o som 3D. O som fica em `GameConfig.Barao.TensionSoundId`.
- **Telemetria** (`CorridorTelemetryService` e ganchos nos serviços):
  - **Corredores:** `CorridorEntered` (andar de entrada) e `CorridorExited` (duração, andar de saída e de entrada).
  - **Descobertas:** `PassageRevealed`, com `FirstOfRound` no primeiro da rodada; o valor é o tempo até a descoberta.
  - **Tocas:** `TocaEntered` e `TocaLeft` (segundos, `Leave` ou `Eject`).
  - **Barão:** `BaraoEncounter`, `BaraoContact`, `BaraoEscape` (`Jump` ou `Run`) e `LeftAfterBarao` (saiu do jogo até 30 s depois de encontrá-lo).
  - **Cofre:** `VaultExpelled`, `VaultOpened`, `VaultPrizeTaken`, `BlockBuilt` e `RoundVaultShots` (tiros com o Puffador do Cofre).
  - **Momentos:** `PuffMoment`.

### O Cofre e o Puffador do Cofre (Fase 2, entrega 2.3)

A mansão pertence ao Barão Puff, inventor do Puffador. O protótipo dele, o **Puffador do Cofre**, fica guardado num cofre atrás da porta da parede oeste do andar de baixo, separado dos corredores secretos.

- **Relação com o Barão:** o cofre destranca no instante em que o Barão acorda, sorteado entre 20% e 35% da rodada (`GameConfig.Barao.WakeMin/MaxFraction`). Todos recebem "O BARÃO ACORDOU!" e um brilho dourado escapa por baixo da porta. Antes disso, a porta responde "O cofre abre quando o Barão acordar…".
- **Abrir:** exige segurar o prompt por 1,5 s. O primeiro a abrir dispara o alarme para a partida inteira (aviso crítico, com o nome dele) e deixa o Barão **bravo** por 25 s: ele acorda na hora se ainda dormia, late mais e corre 10% mais rápido, ainda mais devagar que o jogador.
- **Disputa:** o prêmio é um por rodada e exige segurar o prompt do pedestal por 0,8 s; a briga é no empurrão. Não existe mais eliminação por tiro dentro do cofre. Cada jogador pode ficar no máximo 15 s no cofre por rodada, com aviso aos 10 s; depois o Barão o põe para fora.
- **Puffador do Cofre:** tem 15 Puffs que derrubam 2 blocos cada e empurram 35% mais forte, e 3 construções. Quem o carrega fica com contorno dourado, visível para todos. Quando os Puffs acabam, volta ao Puffador comum e as construções que sobraram se perdem.
- **Modo Construir:**
  - **Como usar:** Q (teclado), Y (controle) ou o botão 🧱 acima do PUFF (toque) alternam entre Puff e Construir. No modo Construir, cada aperto do disparo reconstrói um bloco, e um bloco fantasma dourado mostra onde ele vai voltar.
  - **O que dá para construir:** só blocos derrubados da própria grade da arena, no lugar original, a até 40 studs: o primeiro buraco que a mira atravessa antes de bater em algo. Isso serve para refazer passagem, criar apoio, fazer ponte curta ou recuperar rota. Não dá para criar paredes nem blocos soltos, então não dá para prender ninguém.
  - **Quando é recusado:** se houver alguém no espaço do bloco ou logo acima (quem está caindo no buraco), para ninguém ficar enterrado.
  - **Limites:** 3 construções por posse e 0,5 s entre elas. O servidor valida tudo.
- **Estatísticas:** telemetria `VaultOpened`, `VaultPrizeTaken` e `BlockBuilt`.
- **Ajustes:** `GameConfig.SecretRoom` (cargas, alcance, tempos e `AlertSoundId`) e `GameConfig.Barao` (despertar e fúria).
- **Código:** `VaultService` (regras), `VaultProps` (porta, brilho, alarme e prêmio), `SecretRoomBuilder` (arquitetura), `BuildModeService` (validação da construção), `BuildTargeting` (alvo compartilhado entre servidor e cliente), `ArenaService.rebuildBlock` e `PuffadorModel`. No cliente, `VaultController`, `BuildModeController`, `BuildToggleView` e `SuperChargeView`.

### Identidade visual

A interface segue uma identidade própria definida em `src/client/ui/UiTheme.luau`: "noite na mansão" (fundos roxo-escuros) com as duas cores do Puffador como marca, lilás Puff e dourado Puff; títulos em FredokaOne com contorno escuro; painéis com gradiente, borda em gradiente lilás→dourado e sombra sólida. O logotipo "BLOCO PUFF" aparece no lobby e no painel admin. `UiKit` oferece o botão 3D da marca (afunda ao clicar, cresce no hover, toca um clique e é selecionável por gamepad) e animações de destaque. O botão de tiro mobile é redondo, com recarga enchendo o círculo. `FeedbackView` mostra um "+1" pequeno que escorrega para a direita da mira a cada bloco derrubado e, no lado direito da tela (abaixo do HUD superior), o contador de combo, as chamadas de sequência ("TRIPLO!", "EM CHAMAS!", "IMPARÁVEL!", "LENDÁRIO!") e as notificações curtas de marcos de blocos. Os anúncios centrais (`AnnouncementView`) aparecem no topo, abaixo da faixa de avisos: o centro da tela fica livre para mirar. O painel admin usa cartões por seção, lista de jogadores com avatar e seleção destacada, contadores de caracteres e uma pílula de status para o retorno do servidor.

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
